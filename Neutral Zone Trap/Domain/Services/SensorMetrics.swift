//
//  SensorMetrics.swift
//  Neutral Zone Trap
//

import Foundation

/// Utilita pro výpočet prostorových metrik z pozic senzorů.
nonisolated enum SensorMetrics {

    /// Euklidovská vzdálenost mezi dvěma pozicemi v metrech.
    static func distance(from a: SensorPosition, to b: SensorPosition) -> Double {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return sqrt(Double(dx * dx + dy * dy))
    }

    /// Okamžitá rychlost v m/s spočítaná ze dvou po sobě jdoucích pozic.
    /// Vrátí `nil`, když je časový interval nulový nebo záporný.
    static func speed(from a: SensorPosition, to b: SensorPosition) -> Double? {
        let dt = b.timestamp.timeIntervalSince(a.timestamp)
        guard dt > 0 else { return nil }
        return distance(from: a, to: b) / dt
    }
}
