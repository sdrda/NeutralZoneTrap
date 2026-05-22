//
//  RinkSceneManager.swift
//  Neutral Zone Trap
//

import Foundation
import CoreGraphics
import RealityKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Spravuje veškerou RealityKit scene logiku pro hřiště: vytváření entit
/// a synchronizaci hráčů.
final class RinkSceneManager {
    let config: any RinkConfiguration
    private let textureManager: RinkTextureManager

    private(set) var cachedRinkImage: CGImage?
    private(set) var rinkEntity: Entity?

    /// Faktor přepočtu metry na RealityKit jednotky (30 m hřiště → 0.3 unit plane).
    private let scale: Float = 0.01

    /// Poslední styling pushnutý přes `setStyling(colors:labels:)`. `applyPositions`
    /// snapshot v render framu z toho čte, aby `@Query`-driven změny
    /// (group toggle, úprava dresu) propadly do scény na dalším ticku.
    private var currentColors: [SensorHardwareID: String] = [:]
    private var currentLabels: [SensorHardwareID: String] = [:]

    private struct PlayerStyle: Equatable {
        let colorHex: String?
        let label: String?
    }

    /// Cache marker entit podle sensor ID. Render loop pak nemusí pro každou
    /// pozici procházet strom scény přes stringové jméno entity.
    private var playerEntities: [SensorHardwareID: ModelEntity] = [:]

    /// Naposledy aplikovaný styling per-hráč. Slouží k detekci změny barvy
    /// a dresu, abychom materiál/text child rebuildovali jen při skutečné změně.
    private var appliedStyles: [SensorHardwareID: PlayerStyle] = [:]

    /// Lerp factor použitý každý render frame pro konvergenci marker entity
    /// k cílové pozici. Zhruba odpovídá původnímu ECS výpočtu
    /// `min(1, 10.0 * 1/60) ≈ 0.167`.
    private static let interpolationFactor: Float = 0.18

    init(config: any RinkConfiguration) {
        self.config = config
        self.textureManager = RinkTextureManager(config: config)
    }

    // MARK: - Rink Entity

    func createRinkEntity() async -> ModelEntity {
        let cgImage: CGImage
        if let cached = cachedRinkImage {
            cgImage = cached
        } else {
            // `RinkRenderer.renderConcurrent` je `@concurrent`, takže práce
            // běží na concurrent poolu.
            let rendered = await RinkRenderer(config: config).renderConcurrent(size: config.textureSize)
            guard let image = rendered ?? emptyCGImage() else {
                // Při úplném selhání renderu vrátíme prostou entitu
                let mesh = MeshResource.generatePlane(width: Float(config.width) * scale, depth: Float(config.height) * scale)
                return ModelEntity(mesh: mesh, materials: [UnlitMaterial()])
            }
            cgImage = image
            cachedRinkImage = cgImage
        }

        // Vygenerování ice plane z konfiguračních rozměrů zmenšených o scale
        let planeWidth = Float(config.width) * scale
        let planeDepth = Float(config.height) * scale
        let planeCornerRadius = Float(config.cornerRadius) * scale
        let mesh = MeshResource.generatePlane(width: planeWidth, depth: planeDepth, cornerRadius: planeCornerRadius)

        // UnlitMaterial místo SimpleMaterial: scéna je top-down 2D vizualizace
        // bez fyzikálně realistického osvětlení, takže PBR pipeline je jen
        // overhead a v některých simulator/iOS kombinacích Metal API
        // Validation hlásí chybějící tonemap LUT u PBR fragment shaderu.
        var material = UnlitMaterial()

        // Nastavení textury a předání texture manageru
        if let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) {
            material.color = .init(texture: .init(texture))
            textureManager.textureResource = texture
        }

        // Vytvoření entity
        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Nastavení jména pro pozdější hledání
        entity.name = "RinkPlane"

        playerEntities.removeAll()
        appliedStyles.removeAll()
        rinkEntity = entity
        return entity
    }

    // MARK: - Synchronizace hráčů

    /// Cachuje styling odvozený z `@Query` výsledků, aby per-frame pull
    /// `applyPositions` mohl vykreslovat úpravy dresů a group toggle
    /// bez nutnosti re-subscribovat scene event hook.
    func setStyling(colors: [SensorHardwareID: String], labels: [SensorHardwareID: String]) {
        currentColors = colors
        currentLabels = labels
    }

    /// Snapshot-based sync entit volaný jednou za render frame. Vytvoří nové
    /// entity pro ID, která se právě objevila, aktualizuje existující
    /// a odebere entity pro ID chybějící ve snapshotu. Styling se čte
    /// z cache naplněné `setStyling(colors:labels:)`.
    func applyPositions(_ snapshot: [SensorHardwareID: SensorPosition]) {
        guard rinkEntity != nil else { return }

        for (id, position) in snapshot {
            applyPosition(position, colorHex: currentColors[id], label: currentLabels[id])
        }

        var idsToRemove: [SensorHardwareID] = []
        idsToRemove.reserveCapacity(playerEntities.count)
        for id in playerEntities.keys {
            guard snapshot[id] == nil else { continue }
            idsToRemove.append(id)
        }

        for id in idsToRemove {
            playerEntities[id]?.removeFromParent()
            playerEntities.removeValue(forKey: id)
            appliedStyles.removeValue(forKey: id)
        }
    }

    /// Hot-path update entity pro jednu pozici senzoru. Při prvním výskytu
    /// vytvoří novou entitu hráče, dále už jen aktualizuje existující;
    /// styling (barva, label) se osvěžuje v jednom kroku, takže group toggle,
    /// který padne mezi dvěma pozicemi, se okamžitě projeví.
    ///
    /// Volá se každý render frame z `RealityRinkView` přes
    /// `SceneEvents.Update`, takže lerp entity polohy uvnitř konverguje k
    /// cíli plynule i když nová pozice z store nepřišla — snapshot stejně
    /// stále obsahuje nejnovější known target.
    func applyPosition(_ position: SensorPosition, colorHex: String?, label: String?) {
        guard let rink = rinkEntity else { return }
        let playerID = position.id
        let playerName = "player_\(playerID.rawValue)"

        let target = SIMD3<Float>(
            Float(position.x) * scale,
            Self.playerHeight / 2,
            Float(position.y) * scale
        )

        if let existing = playerEntities[playerID] {
            existing.position = simd_mix(
                existing.position,
                target,
                SIMD3<Float>(repeating: Self.interpolationFactor)
            )
            applyStyleIfNeeded(on: existing, id: playerID, colorHex: colorHex, label: label)
        } else {
            let newEntity = createPlayerEntity(
                startPos: target,
                label: label,
                color: platformColor(from: colorHex)
            )
            newEntity.name = playerName
            rink.addChild(newEntity)
            playerEntities[playerID] = newEntity
            appliedStyles[playerID] = PlayerStyle(colorHex: colorHex, label: label)
        }
    }

    /// Znovu aplikuje styling (barvu, číslo dresu) na každého existujícího hráče
    /// bez sahání na pozici, aby se observable změny (group toggle,
    /// úprava dresu) projevily i když žádná nová pozice zrovna nepadá.
    func refreshStyling(colors: [SensorHardwareID: String], labels: [SensorHardwareID: String]) {
        for (id, entity) in playerEntities {
            applyStyleIfNeeded(on: entity, id: id, colorHex: colors[id], label: labels[id])
        }
    }

    /// Odebere všechny entity hráčů z hřiště, ponechá pouze ice plane.
    func removeAllPlayers() {
        for entity in playerEntities.values {
            entity.removeFromParent()
        }
        playerEntities.removeAll()
        appliedStyles.removeAll()
    }

    // MARK: - Analytika

    func applyHeatmap(from points: [CGPoint]) async {
        await textureManager.setHeatmapTexture(from: points)
    }

    func applyMovement(from points: [CGPoint]) async {
        await textureManager.setMovementTexture(from: points)
    }

    /// Smaže vykreslenou heatmapu nebo movement trail a obnoví podkladový
    /// obraz hřiště v textuře. No-op, když ještě nedošlo k prvnímu
    /// vyrenderování (cachedRinkImage je nil).
    func clearOverlays() {
        guard let baseImage = cachedRinkImage else { return }
        textureManager.restoreBase(baseImage)
    }

    // MARK: Pomocné funkce

    private func createPlayerEntity(startPos: SIMD3<Float>, label: String?, color: PlatformColor = .black) -> ModelEntity {
        let height = Self.playerHeight

        // Válec se z top-down 2D kamery jeví jako kruh.
        let cylinder = ModelEntity(
            mesh: MeshResource.generateCylinder(height: height, radius: 0.008),
            materials: [UnlitMaterial(color: color)]
        )

        cylinder.position = startPos

        if let label {
            cylinder.addChild(makeLabelEntity(text: label, cylinderHeight: height))
        }

        return cylinder
    }

    /// Sestaví text child entitu, která sedí na vrcholu válce hráče
    /// a nese číslo dresu. Fixní jméno `playerLabel` umožňuje
    /// `replaceLabelChild` ji najít, když se label změní.
    private func makeLabelEntity(text: String, cylinderHeight: Float) -> ModelEntity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.001,
            font: .systemFont(ofSize: 0.008, weight: .bold),
            alignment: .center
        )
        let textEntity = ModelEntity(
            mesh: textMesh,
            materials: [UnlitMaterial(color: .white)]
        )
        let center = textEntity.visualBounds(relativeTo: nil).center

        textEntity.position = SIMD3<Float>(-center.x, cylinderHeight / 2 + 0.001, center.y)
        textEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        textEntity.name = "playerLabel"
        return textEntity
    }

    /// Odstraní stávající label child (pokud existuje) a přidá nový, aby se
    /// úpravy čísla dresu okamžitě projevily na markeru hráče.
    private func replaceLabelChild(on player: Entity, with label: String?) {
        player.findEntity(named: "playerLabel")?.removeFromParent()
        guard let label else { return }
        player.addChild(makeLabelEntity(text: label, cylinderHeight: Self.playerHeight))
    }

    private func applyStyleIfNeeded(on player: ModelEntity, id: SensorHardwareID, colorHex: String?, label: String?) {
        let style = PlayerStyle(colorHex: colorHex, label: label)
        let previous = appliedStyles[id]

        if previous?.label != label {
            replaceLabelChild(on: player, with: label)
        }
        if previous?.colorHex != colorHex {
            player.model?.materials = [UnlitMaterial(color: platformColor(from: colorHex))]
        }

        appliedStyles[id] = style
    }

    /// Výška válce markeru hráče. Slouží zároveň jako y-offset potřebný
    /// k položení základny markeru přesně na ice plane (cylinder mesh
    /// je centrovaný na origin).
    private static let playerHeight: Float = 0.02

    /// Fallback 1×1 pixel obrázek použitý, když render textury hřiště selže.
    private func emptyCGImage() -> CGImage? {
        guard let ctx = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }
        return ctx.makeImage()
    }

    /// Parsuje hex string `#RRGGBB` na `PlatformColor`. Vrací černou
    /// pro nil, prázdný nebo špatně zformátovaný vstup.
    private func platformColor(from hex: String?) -> PlatformColor {
        guard let hex, !hex.isEmpty else { return .black }
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let rgb = UInt32(cleaned, radix: 16) else { return .black }
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >> 8) & 0xFF) / 255
        let b = CGFloat(rgb & 0xFF) / 255
        return PlatformColor(red: r, green: g, blue: b, alpha: 1)
    }
}
