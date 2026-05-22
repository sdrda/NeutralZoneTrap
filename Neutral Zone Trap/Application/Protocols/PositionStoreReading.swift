//
//  PositionStoreReading.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce čtení aktuálních pozic senzorů z position store.
///
/// Konformní typ (`SensorPositionStore`) je actor; metoda je proto `async`,
/// aby volající nemusel znát konkrétní typ a přechod přes actor boundary proběhl
/// bezpečně. Protokol je záměrně oddělen od `PositionStoreWriting` —
/// presentační vrstva (render loop v `RinkView`) potřebuje pouze číst.
protocol PositionStoreReading: Sendable {
    /// Vrátí kopii aktuálního slovníku pozic všech senzorů indexovaného jejich hardwarovým ID.
    ///
    /// - Returns: Slovník mapující hardwarové ID senzoru na jeho nejnovější zaznamenanou pozici.
    func snapshot() async -> [SensorHardwareID: SensorPosition]
}
