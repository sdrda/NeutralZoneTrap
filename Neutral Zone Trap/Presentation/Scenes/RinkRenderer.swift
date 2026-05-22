//
//  RinkRenderer.swift
//  Neutral Zone Trap
//

import CoreGraphics
import CoreFoundation

#if canImport(UIKit)
import UIKit
#endif

/// Generuje CGImage ledové plochy podle zadané RinkConfiguration.
/// Obraz lze použít přímo jako texturu v RealityKit.
nonisolated struct RinkRenderer {
    let config: any RinkConfiguration

    /// Async wrapper, který spouští ``render(size:)`` na concurrent executoru.
    /// Z `@MainActor`
    @concurrent
    func renderConcurrent(size: CGSize) async -> CGImage? {
        render(size: size)
    }

    func render(size: CGSize) -> CGImage? {
        let scale = displayScale
        let pixelW = Int(size.width  * scale)
        let pixelH = Int(size.height * scale)

        guard let ctx = CGContext(
            data: nil,
            width: pixelW,
            height: pixelH,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                      | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.scaleBy(x: scale, y: scale)

        // CoreGraphics má osu Y směřující nahoru; překlopit, aby (0,0) bylo vlevo nahoře
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)

        if size.height > size.width {
            // Portrétní plátno -> otočit obsah na landscape
            ctx.translateBy(x: 0, y: size.height)
            ctx.rotate(by: -.pi / 2)
            let landscapeSize = CGSize(width: size.height, height: size.width)
            draw(in: landscapeSize, ctx: ctx)
        } else {
            draw(in: size, ctx: ctx)
        }

        return ctx.makeImage()
    }

    // MARK: - Hlavní rendering sekvence

    private func draw(in size: CGSize, ctx: CGContext) {
        let s = Scale(size: size, config: config)

        drawIce(s, ctx: ctx)

        // Oříznout na zaoblený obdélník hřiště
        ctx.saveGState()
        ctx.addPath(rinkPath(s))
        ctx.clip()

        drawCreaseFills(s, ctx: ctx)
        drawCenterLine(s, ctx: ctx)
        drawBlueLines(s, ctx: ctx)
        drawGoalLines(s, ctx: ctx)
        drawRefereeCrease(s, ctx: ctx)
        drawCenterCircle(s, ctx: ctx)
        drawCenterDot(s, ctx: ctx)
        drawFaceoffCircles(s, ctx: ctx)
        drawNeutralFaceoffDots(s, ctx: ctx)
        drawBoards(s, ctx: ctx)

        ctx.restoreGState()
    }

    // MARK: - Led (pozadí)

    private func drawIce(_ s: Scale, ctx: CGContext) {
        ctx.setFillColor(config.iceColor)
        ctx.addPath(rinkPath(s))
        ctx.fillPath()
    }

    // MARK: - Brankoviště

    private func drawCreaseFills(_ s: Scale, ctx: CGContext) {
        let paths = creasePaths(s)

        ctx.setFillColor(config.creaseFillColor)
        paths.forEach { ctx.addPath($0); ctx.fillPath() }

        ctx.setStrokeColor(config.creaseLineColor)
        ctx.setLineWidth(s.lw(config.creaseLineWidth))
        paths.forEach { ctx.addPath($0); ctx.strokePath() }
    }

    private func creasePaths(_ s: Scale) -> [CGPath] {
        let radius = s.r(config.creaseRadius)
        let cy = s.y(config.height / 2)

        // Levé brankoviště – oblouk se otevírá doprava (ke středu)
        let leftCx = s.x(config.goalLineDistanceFromEnd)
        let leftPath = CGMutablePath()
        leftPath.addArc(center: CGPoint(x: leftCx, y: cy),
                        radius: radius,
                        startAngle: -.pi / 2,
                        endAngle: .pi / 2,
                        clockwise: false)
        leftPath.closeSubpath()

        // Pravé brankoviště – oblouk se otevírá doleva (ke středu)
        let rightCx = s.x(config.width - config.goalLineDistanceFromEnd)
        let rightPath = CGMutablePath()
        rightPath.addArc(center: CGPoint(x: rightCx, y: cy),
                         radius: radius,
                         startAngle: -.pi / 2,
                         endAngle: .pi / 2,
                         clockwise: true)
        rightPath.closeSubpath()

        return [leftPath, rightPath]
    }

    // MARK: - Středová červená čára

    private func drawCenterLine(_ s: Scale, ctx: CGContext) {
        let lineW = s.lw(config.centerLineWidth)
        let cx = s.x(config.width / 2)
        let rect = CGRect(x: cx - lineW / 2, y: 0, width: lineW, height: s.size.height)
        ctx.setFillColor(config.centerLineColor)
        ctx.fill(rect)
    }

    // MARK: - Modré čáry

    private func drawBlueLines(_ s: Scale, ctx: CGContext) {
        let lineW = s.lw(config.blueLineWidth)
        let positions: [CGFloat] = [
            s.x(config.blueLineDistanceFromEnd),
            s.x(config.width - config.blueLineDistanceFromEnd)
        ]
        ctx.setFillColor(config.blueLineColor)
        positions.forEach { cx in
            ctx.fill(CGRect(x: cx - lineW / 2, y: 0, width: lineW, height: s.size.height))
        }
    }

    // MARK: - Brankové čáry

    private func drawGoalLines(_ s: Scale, ctx: CGContext) {
        let xPositions: [CGFloat] = [
            s.x(config.goalLineDistanceFromEnd),
            s.x(config.width - config.goalLineDistanceFromEnd)
        ]
        ctx.setStrokeColor(config.goalLineColor)
        ctx.setLineWidth(s.lw(config.goalLineWidth))
        xPositions.forEach { cx in
            ctx.move(to: CGPoint(x: cx, y: 0))
            ctx.addLine(to: CGPoint(x: cx, y: s.size.height))
            ctx.strokePath()
        }
    }

    // MARK: - Rozhodčí půlkruh

    private func drawRefereeCrease(_ s: Scale, ctx: CGContext) {
        let cx = s.x(config.width / 2)
        let radius = s.r(config.refereeCreaseRadius)

        // Horní mantinel – polokruh směrem dovnitř hřiště
        let topPath = CGMutablePath()
        topPath.addArc(center: CGPoint(x: cx, y: 0),
                       radius: radius,
                       startAngle: 0,
                       endAngle: .pi,
                       clockwise: false)
        topPath.closeSubpath()

        // Spodní mantinel – polokruh směrem dovnitř hřiště
        let botPath = CGMutablePath()
        botPath.addArc(center: CGPoint(x: cx, y: s.size.height),
                       radius: radius,
                       startAngle: .pi,
                       endAngle: 0,
                       clockwise: false)
        botPath.closeSubpath()

        ctx.setStrokeColor(config.refereeCreaseColor)
        ctx.setLineWidth(s.lw(config.refereeCreaseLineWidth))
        [topPath, botPath].forEach { ctx.addPath($0); ctx.strokePath() }
    }

    // MARK: - Středový kruh

    private func drawCenterCircle(_ s: Scale, ctx: CGContext) {
        let center = s.pt(config.width / 2, config.height / 2)
        let path = CGMutablePath()
        path.addArc(center: center,
                    radius: s.r(config.centerCircleRadius),
                    startAngle: 0, endAngle: 2 * .pi,
                    clockwise: false)
        ctx.setStrokeColor(config.circleColor)
        ctx.setLineWidth(s.lw(config.centerCircleLineWidth))
        ctx.addPath(path)
        ctx.strokePath()
    }

    // MARK: - Středový bod pro vhazování

    private func drawCenterDot(_ s: Scale, ctx: CGContext) {
        let center = s.pt(config.width / 2, config.height / 2)
        let path = CGMutablePath()
        path.addArc(center: center,
                    radius: s.r(config.centerDotRadius),
                    startAngle: 0, endAngle: 2 * .pi,
                    clockwise: false)
        ctx.setFillColor(config.dotColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    // MARK: - Kruhy pro vhazování v zónách

    private func drawFaceoffCircles(_ s: Scale, ctx: CGContext) {
        let leftX  = config.goalLineDistanceFromEnd + config.zoneFaceoffDistanceFromGoalLine
        let rightX = config.width - config.goalLineDistanceFromEnd - config.zoneFaceoffDistanceFromGoalLine
        let upperY = config.height / 2 - config.faceoffLateralOffset
        let lowerY = config.height / 2 + config.faceoffLateralOffset

        let positions: [CGPoint] = [
            CGPoint(x: leftX,  y: upperY),
            CGPoint(x: leftX,  y: lowerY),
            CGPoint(x: rightX, y: upperY),
            CGPoint(x: rightX, y: lowerY)
        ]

        positions.forEach { pos in
            let center = s.pt(pos.x, pos.y)

            // Kruh
            let circle = CGMutablePath()
            circle.addArc(center: center,
                          radius: s.r(config.faceoffCircleRadius),
                          startAngle: 0, endAngle: 2 * .pi,
                          clockwise: false)
            ctx.setStrokeColor(config.circleColor)
            ctx.setLineWidth(s.lw(config.circleLineWidth))
            ctx.addPath(circle)
            ctx.strokePath()

            // Postranní značky (hash marks)
            drawHashMarks(center: center, s: s, ctx: ctx)

            // Bod pro vhazování
            let dot = CGMutablePath()
            dot.addArc(center: center,
                       radius: s.r(config.faceoffDotRadius),
                       startAngle: 0, endAngle: 2 * .pi,
                       clockwise: false)
            ctx.setFillColor(config.dotColor)
            ctx.addPath(dot)
            ctx.fillPath()
        }
    }

    private func drawHashMarks(center: CGPoint, s: Scale, ctx: CGContext) {
        let circleR = s.r(config.faceoffCircleRadius)
        let halfLen = s.y(config.hashMarkLength / 2)
        let halfGap = s.x(config.hashMarkGap / 2)
        let lineW   = s.lw(config.hashMarkWidth)

        ctx.setStrokeColor(config.circleColor)
        ctx.setLineWidth(lineW)

        for dy in [-circleR, circleR] {
            for dx in [-halfGap, halfGap] {
                let midX = center.x + dx
                let midY = center.y + dy
                ctx.move(to: CGPoint(x: midX, y: midY - halfLen))
                ctx.addLine(to: CGPoint(x: midX, y: midY + halfLen))
                ctx.strokePath()
            }
        }
    }

    // MARK: - Body pro vhazování ve střední zóně

    private func drawNeutralFaceoffDots(_ s: Scale, ctx: CGContext) {
        let inset  = config.blueLineDistanceFromEnd
                   + config.blueLineWidth / 2
                   + config.neutralFaceoffDistanceFromBlueLine
        let leftX  = inset
        let rightX = config.width - inset
        let upperY = config.height / 2 - config.faceoffLateralOffset
        let lowerY = config.height / 2 + config.faceoffLateralOffset

        let positions: [CGPoint] = [
            CGPoint(x: leftX,  y: upperY),
            CGPoint(x: leftX,  y: lowerY),
            CGPoint(x: rightX, y: upperY),
            CGPoint(x: rightX, y: lowerY)
        ]

        ctx.setFillColor(config.dotColor)
        positions.forEach { pos in
            let path = CGMutablePath()
            path.addArc(center: s.pt(pos.x, pos.y),
                        radius: s.r(config.faceoffDotRadius),
                        startAngle: 0, endAngle: 2 * .pi,
                        clockwise: false)
            ctx.addPath(path)
            ctx.fillPath()
        }
    }

    // MARK: - Mantinely (obrys)

    private func drawBoards(_ s: Scale, ctx: CGContext) {
        ctx.addPath(rinkPath(s))
        ctx.setStrokeColor(config.boardColor)
        // Dvojnásobná tloušťka: polovina tahu leží mimo clipping path a je oříznuta
        ctx.setLineWidth(s.lw(config.boardLineWidth) * 2)
        ctx.strokePath()
    }

    // MARK: - Pomocné funkce

    private func rinkPath(_ s: Scale) -> CGPath {
        CGPath(roundedRect: CGRect(origin: .zero, size: s.size),
               cornerWidth: s.r(config.cornerRadius),
               cornerHeight: s.r(config.cornerRadius),
               transform: nil)
    }

    /// Aktuální scale factor displeje (body -> pixely).
    private var displayScale: CGFloat {
#if canImport(UIKit)
        return UIScreen.main.scale
#else
        return 2.0   // Rozumný fallback pro macOS / visionOS
#endif
    }
}

// MARK: - Scale helper

private nonisolated struct Scale {
    let size: CGSize
    let config: any RinkConfiguration

    var sx: CGFloat { size.width  / config.width  }
    var sy: CGFloat { size.height / config.height }

    func x(_ m: CGFloat) -> CGFloat { m * sx }
    func y(_ m: CGFloat) -> CGFloat { m * sy }
    func pt(_ xm: CGFloat, _ ym: CGFloat) -> CGPoint { CGPoint(x: x(xm), y: y(ym)) }
    func r(_ m: CGFloat) -> CGFloat { m * (sx + sy) / 2 }
    func lw(_ m: CGFloat) -> CGFloat { max(0.5, m * min(sx, sy)) }
}
