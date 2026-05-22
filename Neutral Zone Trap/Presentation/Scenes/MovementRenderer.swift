//
//  MovementRenderer.swift
//  Neutral Zone Trap
//

import CoreGraphics
import Foundation

/// Generuje obraz ledové plochy s trajektorií pohybu hráče.
nonisolated struct MovementRenderer {
    let config: any RinkConfiguration

    /// Velikost výstupního obrazu odvozená od rozměrů hřiště.
    private var imageSize: CGSize { config.textureSize }

    /// Tloušťka čáry trajektorie v pixelech.
    private let lineWidth: CGFloat = 3

    /// Async wrapper kolem ``render(points:)``, který běží na concurrent
    /// executoru. Z `@MainActor` volajících použít místo explicitního
    /// `Task.detached` offloadu.
    @concurrent
    func renderConcurrent(points: [CGPoint]) async -> CGImage? {
        render(points: points.map { (x: $0.x, y: $0.y) })
    }

    /// Generuje CGImage hřiště s trajektorií hráče.
    func render(points: [(x: CGFloat, y: CGFloat)]) -> CGImage? {
        guard let rinkImage = RinkRenderer(config: config).render(size: imageSize) else { return nil }

        let w = rinkImage.width
        let h = rinkImage.height

        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Vykreslit led
        ctx.draw(rinkImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        // Vykreslit trajektorii
        guard points.count >= 2 else { return ctx.makeImage() }

        let fw = CGFloat(w)
        let fh = CGFloat(h)
        let sx = fw / config.width
        let sy = fh / config.height

        ctx.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let first = points[0]
        let startX = (first.x + config.width / 2) * sx
        let startY = fh - (first.y + config.height / 2) * sy
        ctx.move(to: CGPoint(x: startX, y: startY))

        for i in 1..<points.count {
            let pt = points[i]
            let px = (pt.x + config.width / 2) * sx
            let py = fh - (pt.y + config.height / 2) * sy
            ctx.addLine(to: CGPoint(x: px, y: py))
        }

        ctx.strokePath()

        return ctx.makeImage()
    }
}
