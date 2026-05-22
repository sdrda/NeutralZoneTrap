//
//  IIHFRinkConfiguration.swift
//  Neutral Zone Trap
//

import CoreGraphics

/// Výchozí konfigurace hřiště podle IIHF standardu (Rule Book 1.x).
/// Nespecifikované parametry jsou doplněny vlastním pozorováním.
struct IIHFRinkConfiguration: RinkConfiguration {

    var width: CGFloat = 60.0
    var height: CGFloat = 30.0          // IIHF: 26–30 m, standard 30 m
    var cornerRadius: CGFloat = 8.5     // IIHF: 7,0–8,5 m, standard 8,5 m

    var boardLineWidth: CGFloat = 0.12
    var goalLineWidth: CGFloat = 0.05   // 5 cm ✓ Pravidlo 1.5
    var blueLineWidth: CGFloat = 0.30   // 30 cm ✓ Pravidlo 1.5
    var centerLineWidth: CGFloat = 0.30 // 30 cm ✓ Pravidlo 1.5
    var circleLineWidth: CGFloat = 0.05 // 5 cm ✓ Pravidlo 1.9

    var goalLineDistanceFromEnd: CGFloat = 4.0    // ✓ Pravidlo 1.5
    var blueLineDistanceFromEnd: CGFloat = 22.5  // standardní IIHF

    var centerCircleRadius: CGFloat = 4.5         // ✓ Pravidlo 1.9 (4,50 m)
    var centerCircleLineWidth: CGFloat = 0.05     // 5 cm ✓
    var centerDotRadius: CGFloat = 0.15           // průměr 30 cm ✓

    var faceoffCircleRadius: CGFloat = 4.5        // ✓ Pravidlo 1.9 (4,50 m)
    var zoneFaceoffDistanceFromGoalLine: CGFloat = 6.0   // standardní IIHF
    var faceoffLateralOffset: CGFloat = 7.0       // ✓ (14,0 m mezi sebou)

    var neutralFaceoffDistanceFromBlueLine: CGFloat = 1.5  // ✓ Pravidlo 1.9

    var faceoffDotRadius: CGFloat = 0.30          // průměr 60 cm (IIHF Pravidlo 1.9)

    var hashMarkLength: CGFloat = 0.60            // 60 cm
    var hashMarkWidth: CGFloat = 0.05             // 5 cm
    var hashMarkGap: CGFloat = 1.70               // 1,70 m mezi nimi

    var creaseRadius: CGFloat = 1.80              // IIHF standard 1,80 m (NHL 1,83 m)
    var creaseLineWidth: CGFloat = 0.05           // 5 cm

    var refereeCreaseRadius: CGFloat = 3.0        // IIHF Pravidlo 1.7
    var refereeCreaseLineWidth: CGFloat = 0.05    // 5 cm

    // Barvy nejsou pravidly IIHF specifikovány; hodnoty aproximují broadcast paletu.
    var iceColor: CGColor         = CGColor(red: 0.93, green: 0.96, blue: 1.00, alpha: 1.0)
    var boardColor: CGColor       = CGColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.0)
    var goalLineColor: CGColor    = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var blueLineColor: CGColor    = CGColor(red: 0.05, green: 0.20, blue: 0.75, alpha: 1.0)
    var centerLineColor: CGColor  = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var circleColor: CGColor      = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var dotColor: CGColor         = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var creaseFillColor: CGColor  = CGColor(red: 0.55, green: 0.78, blue: 0.98, alpha: 0.55)
    var creaseLineColor: CGColor  = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var goalColor: CGColor        = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)
    var refereeCreaseColor: CGColor = CGColor(red: 0.85, green: 0.10, blue: 0.10, alpha: 1.0)

    static let standard = IIHFRinkConfiguration()
}
