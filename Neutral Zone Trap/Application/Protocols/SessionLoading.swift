//
//  SessionLoading.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce načtení session zvenčí do recorderu — slouží k importu session ze souboru.
///
/// Konformní typ (`Recorder`) je actor; metoda je proto `async`. Protokol je kombinován
/// se `SessionSnapshotting` v `SessionFileManager`, který potřebuje obě operace
/// (čtení snímku před exportem, zápis snímku po importu).
nonisolated protocol SessionLoading: Sendable {
    /// Nahradí interní stav recorderu dodaným snímkem session a deaktivuje příznak nahrávání.
    ///
    /// - Parameter snapshot: Session načtená z externího souboru, která nahradí stávající data.
    func load(_ snapshot: Session) async
}
