//
//  RealityRinkView.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData
import RealityKit

#if os(iOS)
typealias PlatformColor = UIColor
#elseif os(macOS)
typealias PlatformColor = NSColor
#endif

/// 3D/2D RealityKit scéna hřiště a markerů hráčů na něm.
///
/// Každý render frame táhne ze ``SensorPositionStore`` přes
/// `SceneEvents.Update` subscription nainstalovaný v `make:` closure
/// `RealityView`. View nikdy nevidí live UDP stream — write-side
/// pipeliny (``SensorStreamProcessor`` pro live, ``Playback`` pro replay)
/// pushují pozice do store a renderer z něj čte.
///
/// Cross-cutting concerns zůstávají v dedikovaných modifierech:
/// * ``RinkCameraHandling`` — 2D ↔ 3D swap kamery a pinch-to-zoom.
/// * ``RinkOverlayHandling`` — inspector-driven heatmap a movement
///   overlay.
struct RealityRinkView: View {
    @State private var cameraEntity: Entity = Entity()
    @State private var sceneManager: RinkSceneManager
    @State private var baseScale: Float = 0.5

    @Environment(RinkCameraState.self) private var camera
    @Environment(GroupSelection.self) private var groupSelection
    @Environment(Statistics.self) private var statistics
    @Environment(RinkOverlayState.self) private var overlay
    @Environment(\.sensorPositionStore) private var store
    @Environment(\.benchmarkLogger) private var benchmarkLogger

    // Dotazy pro vizualizaci hráčů
    @Query(sort: \Sensor.hardwareId) private var sensors: [Sensor]
    @Query(sort: \PlayerGroup.name) private var groups: [PlayerGroup]

    let config: any RinkConfiguration = IIHFRinkConfiguration()

    init() {
        self.sceneManager = RinkSceneManager(config: IIHFRinkConfiguration())
    }

    var body: some View {
        RealityView { content in
            content.camera = .virtual

            let rink = await sceneManager.createRinkEntity()
            content.add(rink)

            cameraEntity.components.set(PerspectiveCameraComponent())
            cameraEntity.look(at: .zero, from: SIMD3<Float>(0, 0.5, 0), relativeTo: nil)
            content.add(cameraEntity)

            // Per-frame pull ze store
            _ = content.subscribe(to: SceneEvents.Update.self) { [sceneManager, store, benchmarkLogger] _ in
                Task { @MainActor in
                    guard let store else { return }
                    let snap = await store.snapshot()
                    sceneManager.applyPositions(snap)
                    if let benchmarkLogger {
                        await benchmarkLogger.recordRendered(ids: Array(snap.keys), at: .now)
                    }
                }
            }

        } update: { _ in
            sceneManager.setStyling(colors: playerColors, labels: playerLabels)
            sceneManager.refreshStyling(colors: playerColors, labels: playerLabels)
        }
        
        // Nativni ovladani kamery
        .realityViewCameraControls(camera.is3D ? .orbit : .none)

        // 2D pinch-to-zoom; vypnute ve 3D, kde to resi orbit nad.
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    let newScale = baseScale / Float(value.magnification)
                    camera.orthoScale = min(max(newScale, 0.05), 2.0)
                }
                .onEnded { _ in
                    baseScale = camera.orthoScale
                },
            isEnabled: !camera.is3D
        )

        // Swap typu kamery při 2D ↔ 3D toggle.
        .onChange(of: camera.is3D) { _, newValue in
            if newValue {
                cameraEntity.components.remove(OrthographicCameraComponent.self)
                cameraEntity.components.set(PerspectiveCameraComponent())
            } else {
                cameraEntity.components.remove(PerspectiveCameraComponent.self)
                var ortho = OrthographicCameraComponent()
                ortho.scale = camera.orthoScale
                cameraEntity.components.set(ortho)

                // Plný reset transformu — pozice i orientace —
                // na kanonický top-down 2D pohled.
                cameraEntity.transform = .identity
                cameraEntity.look(at: .zero, from: SIMD3<Float>(0, 0.5, 0), relativeTo: nil)
                baseScale = camera.orthoScale
            }
        }

        // Live zoom: propagovat změny orthoScale na aktivní
        // orthographic komponentu, dokud jsme ve 2D módu.
        .onChange(of: camera.orthoScale) { _, newScale in
            guard !camera.is3D,
                  var ortho = cameraEntity.components[OrthographicCameraComponent.self] else { return }
            ortho.scale = newScale
            cameraEntity.components.set(ortho)
        }

        // Accessibility i pro RealityView
        .accessibilityIdentifier("rink.realityview")
        .accessibilityLabel(camera.is3D ? "3D ice rink with player positions" : "2D ice rink with player positions")
        .accessibilityValue(Text("\(statistics.activeIDs.count) active players on the ice"))
        .accessibilityHint(Text(camera.is3D ? "Drag to rotate the view" : "Pinch to zoom"))

        // Inspector-published heatmap a movement overlay → texture na ice
        // plane. Po aplikaci se request slot vycisti, aby dalsi publikace
        // re-triggerovala stejný flow.
        .onChange(of: overlay.heatmap) { _, newOverlay in
            guard let newOverlay else { return }
            Task {
                await sceneManager.applyHeatmap(from: newOverlay.points)
            }
            overlay.clearHeatmap()
        }
        .onChange(of: overlay.movement) { _, newOverlay in
            guard let newOverlay else { return }
            Task {
                await sceneManager.applyMovement(from: newOverlay.points)
            }
            overlay.clearMovement()
        }
        .onChange(of: overlay.clearRequest) { _, newRequest in
            guard newRequest != nil else { return }
            sceneManager.clearOverlays()
            overlay.consumeClearRequest()
        }
    }

    // MARK: - Odvozené mappingy

    /// Senzor → label čísla dresu, odvozený z live `@Query` senzorů.
    private var playerLabels: [SensorHardwareID: String] {
        var result: [SensorHardwareID: String] = [:]
        for sensor in sensors {
            guard let player = sensor.player else { continue }
            result[sensor.hardwareID] = String(player.jerseyNumber)
        }
        return result
    }

    /// Senzor → hex barva pro každý senzor, jehož hráč patří do aktuálně
    /// aktivní skupiny. Iteruje přes skupiny, aby se nově
    /// přidaní hráči okamžitě zobrazili.
    private var playerColors: [SensorHardwareID: String] {
        guard !groupSelection.activeGroups.isEmpty else { return [:] }
        var result: [SensorHardwareID: String] = [:]
        for group in groups where groupSelection.isActive(group) {
            guard let hex = group.colorHex, let players = group.players else { continue }
            for player in players {
                for sensor in player.sensors ?? [] {
                    if result[sensor.hardwareID] == nil {
                        result[sensor.hardwareID] = hex
                    }
                }
            }
        }
        return result
    }
}
