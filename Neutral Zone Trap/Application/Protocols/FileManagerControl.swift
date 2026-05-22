//
//  FileManagerControl.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce správy souborů session — exportu, importu a sledování stavu uložení.
///
/// Protokol izoluje prezentační vrstvu od konkrétní implementace (`SessionFileManager`)
/// a zajišťuje, že veškerá mutace stavu probíhá na hlavním vlákně (`@MainActor`).
@MainActor
protocol FileManagerControl: Sendable {
    /// Připraví dokument ze snímku aktuální session a spustí systémový file-exporter sheet.
    func exportSession() async
    /// Načte session ze souboru vybraného uživatelem a nahradí jím stav recorderu.
    ///
    /// - Parameter result: Výsledek file-importeru — buď URL k `.nzt` souboru, nebo chyba výběru.
    /// - Throws: `SessionError` při selhání dekódování nebo stahování z iCloudu,
    ///   případně chyba předaná přímo z file-importeru.
    /// - Note: Metoda je asynchronní; při souboru v iCloudu může stahování trvat
    ///   až `downloadTimeout` sekund.
    func importSession(from result: Result<URL, any Error>) async throws
}
