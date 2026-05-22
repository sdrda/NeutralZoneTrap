//
//  PlaybackControl.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce přehrávání nahrané session — načtení, spuštění, pozastavení, přesun v čase a reset.
///
/// Konformní typ (`Playback`) emituje uložené pozice senzorů v reálném čase do `PositionStoreWriting`
/// a průběžně aktualizuje statistiky. Protokol je izolován na `@MainActor`, protože metody
/// přímo mutují stavové vlastnosti sledované SwiftUI.
@MainActor
protocol PlaybackControl: Sendable {
    /// Spustí nebo obnoví přehrávání od aktuálního kurzoru.
    func play()
    /// Pozastaví přehrávání; kurzor zůstává na místě a další `play()` pokračuje ze stejného času.
    func pause()
    /// Přesune kurzor na zadaný čas a okamžitě aktualizuje position store snímkem pozic v daném čase.
    ///
    /// - Parameter time: Cílový wall-clock timestamp v rámci časového rozsahu session.
    func seek(to time: Date)
}
