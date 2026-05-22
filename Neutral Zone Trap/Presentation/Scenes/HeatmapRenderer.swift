//
//  HeatmapRenderer.swift
//  Neutral Zone Trap
//
//  Implementace dvourozměrného Kernel Density Estimation (KDE) pro
//  vizualizaci pohybu hráče na ledové ploše. Vstupní pozice jsou
//  konvolvány s Gaussovým jádrem, výsledné hodnoty hustoty jsou
//  normalizovány maximem a převedeny na tepelnou škálu.
//

import CoreGraphics
import Foundation

/// Generuje obraz ledové plochy s překrytým odhadem hustoty pohybu hráče.
///
/// Hustota je odhadována metodou Kernel Density Estimation (KDE) podle
/// Silvermana se standardním Gaussovým jádrem:
/// `K(u) = exp(-||u||² / 2)` (normalizační konstanta `1/(2π h²)` se
/// při normalizaci maximem vyruší a v implementaci ji proto vynecháváme).
/// Pásmová šířka `bandwidthMeters` určuje hladkost odhadu. Větší hodnota
/// produkuje plynulejší mapy s větší mírou rozmazání, menší zachycuje
/// drobné lokální extrémy.
nonisolated struct HeatmapRenderer {
    let config: any RinkConfiguration

    // Pásmová šířka Gaussova jádra v metrech.
    let bandwidthMeters: CGFloat

    // Velikost bunky
    private let cellSizeMeters: CGFloat = 0.25

    // Výstupní velikost obrazu odvozená od rozměrů kluziště.
    private var imageSize: CGSize { config.textureSize }

    init(config: any RinkConfiguration, bandwidthMeters: CGFloat = 1.0) {
        self.config = config
        self.bandwidthMeters = bandwidthMeters
    }

    // MARK: - Veřejné rozhraní

    /// Asynchronně generuje CGImage kluziště s KDE heatmapou.
    ///
    /// - Parameter points: Pozice hráče v souřadném systému kluziště
    ///   (počátek uprostřed plochy, rozměry odpovídají `config.width/height`).
    /// - Returns: Složený obraz ledu a heatmapy, nebo nil při chybě renderingu.
    @concurrent
    func render(points: [CGPoint]) async -> CGImage? {
        // Vykreslení podkladové ledové plochy.
        guard let rinkImage = RinkRenderer(config: config).render(size: imageSize) else {
            return nil
        }

        let width = rinkImage.width
        let height = rinkImage.height

        // Příprava výstupního kontextu.
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.draw(rinkImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Výpočet KDE a vykreslení vrstvy.
        if let heatLayer = Self.renderKDELayer(
            points: points,
            width: width,
            height: height,
            rinkWidth: config.width,
            rinkHeight: config.height,
            cellSizeMeters: cellSizeMeters,
            bandwidthMeters: bandwidthMeters
        ) {
            ctx.setAlpha(0.6)
            ctx.draw(heatLayer, in: CGRect(x: 0, y: 0, width: width, height: height))
        }

        return ctx.makeImage()
    }

    // MARK: - Výpočet KDE

    /// Vypočítá 2D Gaussovský KDE odhad hustoty a převede jej na barevný obraz.
    ///
    /// Pro každý vstupní bod se akumuluje příspěvek Gaussova jádra
    /// do všech buněk mřížky v okénku ±3h kolem bodu. Na hranici
    /// tohoto okénka klesá hodnota Gaussova jádra na e^(-9/2) ≈ 1,1 %
    /// maxima a příspěvek z vnějšku lze bez znatelné chyby zanedbat.
    /// Tím dosahujeme komplexity `O(N · R²)` namísto
    /// `O(N · cols · rows)`, kde `R = 3h/cellSize`.
    private nonisolated static func renderKDELayer(
        points: [CGPoint],
        width: Int,
        height: Int,
        rinkWidth: CGFloat,
        rinkHeight: CGFloat,
        cellSizeMeters: CGFloat,
        bandwidthMeters: CGFloat
    ) -> CGImage? {
        guard !points.isEmpty else { return nil }

        // Rozměry mřížky v buňkách.
        let cols = max(1, Int((rinkWidth / cellSizeMeters).rounded()))
        let rows = max(1, Int((rinkHeight / cellSizeMeters).rounded()))

        // Akumulační pole hustot (Float pro numerickou přesnost a paměť).
        var density = [Float](repeating: 0, count: cols * rows)

        // Pásmová šířka v jednotkách buněk.
        let h = Float(bandwidthMeters / cellSizeMeters)
        guard h > 0 else { return nil }

        // Poloměr ořezu jádra. Na hranici ±3h klesá 2D Gaussovo jádro
        // na e^(-9/2) ≈ 1,1 % maxima, takže příspěvek z vnějšku zanedbáváme.
        let radius = max(1, Int(ceil(3.0 * Double(h))))
        let twoHSquared = 2 * h * h

        // Aplikace jádra pro každý vstupní bod.
        for point in points {
            // Bod v souřadnicích buněk (osa Y orientovaná stejně jako data,
            // překlopení do pixelového prostoru řešíme až při kreslení).
            let cx = Float((point.x + rinkWidth / 2) / cellSizeMeters)
            let cy = Float((point.y + rinkHeight / 2) / cellSizeMeters)

            let centerCol = Int(cx)
            let centerRow = Int(cy)

            let colMin = max(0, centerCol - radius)
            let colMax = min(cols - 1, centerCol + radius)
            let rowMin = max(0, centerRow - radius)
            let rowMax = min(rows - 1, centerRow + radius)

            guard colMin <= colMax, rowMin <= rowMax else { continue }

            for row in rowMin...rowMax {
                let dy = Float(row) + 0.5 - cy
                let dy2 = dy * dy
                for col in colMin...colMax {
                    let dx = Float(col) + 0.5 - cx
                    let distSquared = dx * dx + dy2
                    // Standardní Gaussovo jádro K(u) = exp(-||u||² / 2h²).
                    let kernel = expf(-distSquared / twoHSquared)
                    density[row * cols + col] += kernel
                }
            }
        }

        // Normalizace maximem (pro vizualizaci kontrastu nezávisle na počtu vzorků N).
        let maxDensity = density.max() ?? 0
        guard maxDensity > 0 else { return nil }

        // Rozměry jedné buňky v pixelech výstupního obrazu.
        let cellPxW = CGFloat(width) / CGFloat(cols)
        let cellPxH = CGFloat(height) / CGFloat(rows)

        // Příprava výstupního kontextu pro vrstvu KDE.
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Vykreslení jednotlivých buněk.
        for row in 0..<rows {
            for col in 0..<cols {
                let value = density[row * cols + col]
                guard value > 0 else { continue }

                let t = value / maxDensity
                let (r, g, b) = heatColor(t)
                let alpha = CGFloat(min(t * 2, 1.0))

                ctx.setFillColor(CGColor(
                    red: CGFloat(r) / 255.0,
                    green: CGFloat(g) / 255.0,
                    blue: CGFloat(b) / 255.0,
                    alpha: alpha
                ))
                // CGContext má počátek vlevo dole, řádek 0 kreslíme nahoru,
                // aby orientace odpovídala souřadnicím kluziště.
                let flippedRow = rows - 1 - row
                ctx.fill(CGRect(
                    x: CGFloat(col) * cellPxW,
                    y: CGFloat(flippedRow) * cellPxH,
                    width: cellPxW,
                    height: cellPxH
                ))
            }
        }

        return ctx.makeImage()
    }

    // MARK: - Barevná škála

    /// Mapuje normalizovanou intenzitu t ∈ [0, 1] na RGB podle škály
    /// modrá → zelená → žlutá → červená.
    private nonisolated static func heatColor(_ t: Float) -> (UInt8, UInt8, UInt8) {
        let r: Float
        let g: Float
        let b: Float

        switch t {
        case ..<(1.0 / 3.0):
            let f = t / (1.0 / 3.0)
            r = 0
            g = f
            b = 1.0 - f
        case ..<(2.0 / 3.0):
            let f = (t - 1.0 / 3.0) / (1.0 / 3.0)
            r = f
            g = 1.0
            b = 0
        default:
            let f = min((t - 2.0 / 3.0) / (1.0 / 3.0), 1.0)
            r = 1.0
            g = 1.0 - f
            b = 0
        }

        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}
