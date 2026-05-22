//
//  SessionSnapshotting.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce pořízení neměnného snímku aktuální session pro čtecí operace.
///
/// Konformní typ (`Recorder`) je actor; metoda je proto `async`. Protokol využívají
/// `SessionFileManager` (export do souboru), `Playback` (sestavení přehrávací časové osy)
nonisolated protocol SessionSnapshotting: Sendable {
    /// Vrátí kopii aktuálně nahrávané nebo načtené session v daném okamžiku.
    ///
    /// - Returns: Neměnný snímek `Session` se všemi dosud zaznamnanými stopami senzorů.
    func snapshot() async -> Session
}
