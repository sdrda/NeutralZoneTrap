//
//  Session+Analytics.swift
//  Neutral Zone Trap
//

import Foundation
import CoreGraphics


extension Session {

    /// Vrátí celkovou ujetou vzdálenost daného senzoru v metrech, nebo 0, není-li jeho stopa přítomna.
    /// - Parameter sensorID: Identifikátor senzoru, jehož vzdálenost se má zjistit.
    /// - Returns: Souhrnnou vzdálenost stopy v metrech.
    /// - Complexity: O(n) přes počet stop.
    func totalDistance(forSensor sensorID: SensorHardwareID) -> Double {
        sensorTracks.first { $0.sensorHardwareID == sensorID }?.totalDistance ?? 0
    }

    /// Vrátí body trasy daného senzoru pro vykreslení heatmapy a čáry pohybu.
    /// - Parameter sensorID: Identifikátor senzoru, jehož body se mají získat.
    /// - Returns: Pozice senzoru jako `CGPoint`, nebo prázdné pole, není-li jeho stopa přítomna.
    /// - Complexity: O(n) přes počet stop a pozic senzoru.
    func points(forSensor sensorID: SensorHardwareID) -> [CGPoint] {
        sensorTracks
            .first { $0.sensorHardwareID == sensorID }?
            .positions
            .map { CGPoint(x: $0.x, y: $0.y) }
            ?? []
    }

    /// Vrátí body tras více senzorů sloučené dohromady pro heatmapu skupiny hráčů.
    /// - Parameter sensorIDs: Posloupnost identifikátorů senzorů ve skupině.
    /// - Returns: Spojené pozice všech zadaných senzorů jako `CGPoint`.
    func points(forSensors sensorIDs: some Sequence<SensorHardwareID>) -> [CGPoint] {
        sensorIDs.flatMap { points(forSensor: $0) }
    }
    
    /// Vrátí `true`, pokud session neobsahuje žádnou stopu (žádná nahraná data).
    func isEmpty() -> Bool {
        sensorTracks.isEmpty
    }
}
