//
//  PositionStoreWriting.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce zápisových operací do position store uchovávajícího aktuální polohy senzorů.
///
/// Konformní typ (`SensorPositionStore`) je actor; všechny metody jsou proto `async`.
/// Protokol je konzumován jak živou cestou (`SensorStreamProcessor`),
/// tak při přehrávání (`Playback`).
protocol PositionStoreWriting: Sendable {
    /// Aktualizuje pozici senzoru; starší nebo duplicitní záznamy (podle timestampu) jsou zahozeny.
    ///
    /// - Parameter position: Nová pozice senzoru k zapsání.
    func update(_ position: SensorPosition) async
    /// Hromadně aktualizuje pozice z dávky; každá položka projde stejnou timestampovou kontrolou jako `update(_:)`.
    ///
    /// - Parameter batch: Pole pozic senzorů ke zpracování.
    func updateMany(_ batch: [SensorPosition]) async
    /// Atomicky nahradí celý obsah store dodaným snímkem — používá se při seeku v přehrávání.
    ///
    /// - Parameter snapshot: Slovník mapující hardwarové ID senzoru na jeho cílovou pozici.
    func replaceAll(_ snapshot: [SensorHardwareID: SensorPosition]) async
    /// Vymaže všechny záznamy v position store.
    func reset() async
}
