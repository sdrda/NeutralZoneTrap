//
//  RinkConfiguration.swift
//  Neutral Zone Trap
//

import CoreGraphics

nonisolated protocol RinkConfiguration: Sendable {

    // MARK: - Rozměry hřiště (v metrech)

    var width: CGFloat { get }
    var height: CGFloat { get }
    var cornerRadius: CGFloat { get }

    // MARK: - Šířky čar (v metrech)

    var boardLineWidth: CGFloat { get }
    var goalLineWidth: CGFloat { get }
    var blueLineWidth: CGFloat { get }
    var centerLineWidth: CGFloat { get }
    var circleLineWidth: CGFloat { get }

    // MARK: - Pozice čar

    var goalLineDistanceFromEnd: CGFloat { get }
    var blueLineDistanceFromEnd: CGFloat { get }

    // MARK: - Středový kruh

    var centerCircleRadius: CGFloat { get }
    var centerCircleLineWidth: CGFloat { get }
    var centerDotRadius: CGFloat { get }

    // MARK: - Vhazovací kruhy v zónách

    var faceoffCircleRadius: CGFloat { get }
    var zoneFaceoffDistanceFromGoalLine: CGFloat { get }
    var faceoffLateralOffset: CGFloat { get }

    // MARK: - Vhazovací body v neutrální zóně

    var neutralFaceoffDistanceFromBlueLine: CGFloat { get }

    // MARK: - Vhazovací body

    var faceoffDotRadius: CGFloat { get }

    // MARK: - Hash marks vhazovacího kruhu

    var hashMarkLength: CGFloat { get }
    var hashMarkWidth: CGFloat { get }
    var hashMarkGap: CGFloat { get }

    // MARK: - Brankoviště

    var creaseRadius: CGFloat { get }
    var creaseLineWidth: CGFloat { get }

    // MARK: - Rozhodčí kruh

    var refereeCreaseRadius: CGFloat { get }
    var refereeCreaseLineWidth: CGFloat { get }

    // MARK: - Barvy

    var iceColor: CGColor { get }
    var boardColor: CGColor { get }
    var goalLineColor: CGColor { get }
    var blueLineColor: CGColor { get }
    var centerLineColor: CGColor { get }
    var circleColor: CGColor { get }
    var dotColor: CGColor { get }
    var creaseFillColor: CGColor { get }
    var creaseLineColor: CGColor { get }
    var goalColor: CGColor { get }
    var refereeCreaseColor: CGColor { get }
}

nonisolated extension RinkConfiguration {
    // Pixely na metr pouzivane pri renderovani textury.
    var texturePixelsPerMeter: CGFloat { 34 }

    // Velikost textury odvozená z rozmeru hriste (např. 60×30 → 2040×1020).
    var textureSize: CGSize {
        CGSize(width: width * texturePixelsPerMeter,
               height: height * texturePixelsPerMeter)
    }
}
