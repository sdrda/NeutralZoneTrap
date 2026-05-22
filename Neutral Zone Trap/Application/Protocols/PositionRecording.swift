//
//  PositionRecording.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce záznamu jednotlivých pozic senzorů do aktivní session.
///
/// Konformní typ (`Recorder`) přijímá pozice ze `SensorStreamProcessor` a ukládá je
/// do vnitřního modelu `Session`. Protokol je oddělen od `RecordingControl`,
/// aby producent dat nemusel mít přístup ke spuštění ani zastavení nahrávání.
protocol PositionRecording: Sendable {
    /// Připojí pozici senzoru k aktuálně nahrávané session.
    ///
    /// - Parameter position: Pozice senzoru s hardwarovým ID a wall-clock timestampem.
    /// - Returns: `true` pokud bylo nahrávání aktivní a pozice byla zapsána;
    ///   `false` pokud nahrávání neběží a pozice byla zahozena.
    @discardableResult
    func append(_ position: SensorPosition) async -> Bool
}
