//
//  SensorPositionStore.swift
//  Neutral Zone Trap
//

import Foundation

/// Aktor uchovávající poslední známou pozici každého senzoru; serializuje zápisy z příjmu paketů, přehrávání a render-smyčky.
actor SensorPositionStore: PositionStoreWriting, PositionStoreReading {
    
    /// Poslední známá pozice každého senzoru, klíčovaná hardwarovým ID.
    private var positions: [SensorHardwareID: SensorPosition] = [:]
    
    /// Zapíše pozici, pokud je novější než dosud uložená; starší nebo stejně staré pakety ignoruje, aby pořadí příchodu nezpůsobilo zpětný posun.
    func update(_ position: SensorPosition) {
        if let existing = positions[position.id],
           existing.timestamp >= position.timestamp {
            return
        }
        positions[position.id] = position
    }

    /// Zapíše dávku pozic jediným aktorovým přechodem; každou aplikuje přes ``update(_:)``.
    /// - Parameter batch: Pozice ke zpracování v pořadí, v jakém přišly.
    func updateMany(_ batch: [SensorPosition]) {
        // Zpracovani batche
        for position in batch {
            update(position)
        }
    }

    /// Atomicky nahradí celý obsah úložiště daným snapshotem; používá se při seeku v přehrávání.
    /// - Parameter snapshot: Kompletní sada pozic, která zcela nahradí stávající stav.
    func replaceAll(_ snapshot: [SensorHardwareID: SensorPosition]) {
        positions = snapshot
    }

    /// Vrátí kopii aktuálních pozic pro render-smyčku v RealityView.
    /// - Returns: Slovník pozic klíčovaný hardwarovým ID senzoru.
    func snapshot() -> [SensorHardwareID: SensorPosition] {
        positions
    }

    /// Vyprázdní úložiště a smaže všechny uložené pozice.
    func reset() {
        positions = [:]
    }
}
