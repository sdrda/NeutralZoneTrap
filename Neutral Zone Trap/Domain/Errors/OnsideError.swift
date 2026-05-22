//
//  OnsideError.swift
//  Neutral Zone Trap
//

import Foundation

// MARK: - Repository Errors

/// Chyba perzistentní vrstvy (repozitáře) zabalující selhání operací nad úložištěm.
enum RepositoryError: LocalizedError {
    /// Načtení dat z úložiště selhalo; nese původní příčinu.
    case fetchFailed(underlying: Error)
    /// Uložení dat do úložiště selhalo; nese původní příčinu.
    case saveFailed(underlying: Error)
    /// Smazání dat z úložiště selhalo; nese původní příčinu.
    case deleteFailed(underlying: Error)

    /// Lokalizovaný popis chyby pro zobrazení uživateli.
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return String(localized: "Data fetch failed: \(error.localizedDescription)")
        case .saveFailed(let error):
            return String(localized: "Save failed: \(error.localizedDescription)")
        case .deleteFailed(let error):
            return String(localized: "Delete failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Group Selection Errors

/// Chyba při výběru a aktivaci skupin hráčů.
enum GroupSelectionError: LocalizedError {
    /// Nelze aktivovat skupiny sdílející hráče; nese jména hráčů v průniku.
    case conflictingPlayers([String])

    /// Lokalizovaný popis chyby se seřazeným seznamem konfliktních hráčů.
    var errorDescription: String? {
        switch self {
        case .conflictingPlayers(let names):
            let joined = names.sorted().joined(separator: ", ")
            return String(
                localized: "Cannot activate groups that share players. Conflicting players: \(joined)"
            )
        }
    }
}

// MARK: - Network Errors

/// Chyba síťové vrstvy při příjmu dat ze senzorů.
enum NetworkError: LocalizedError {
    /// UDP listener se nepodařilo nabindovat, protože daný port už někdo poslouchá.
    case portUnavailable(port: UInt16)

    /// Lokalizovaný popis chyby pro zobrazení uživateli.
    var errorDescription: String? {
        switch self {
        case .portUnavailable(let port):
            return String(
                localized: "Port \(port) is already in use. Another app — or a second instance of this one — is listening on it. Free the port and restart the app to receive sensor data."
            )
        }
    }
}

// MARK: - Session Errors

/// Chyba při importu, stahování nebo exportu nahrané session.
enum SessionError: LocalizedError {
    /// Import session ze souboru selhal; nese původní příčinu.
    case importFailed(underlying: Error)
    /// Stažení souboru z iCloudu nebylo dokončeno v časovém limitu.
    case downloadTimedOut
    /// Operace nemá co zpracovat, protože nebyly nahrány žádné pozice.
    case noRecordedData

    /// Lokalizovaný popis chyby pro zobrazení uživateli.
    var errorDescription: String? {
        switch self {
        case .importFailed(let error):
            return String(localized: "Import failed: \(error.localizedDescription)")
        case .downloadTimedOut:
            return String(
                localized: "Couldn't download the file from iCloud in time. Check your connection and try again once it has finished downloading."
            )
        case .noRecordedData:
            return String(localized: "No positions were recorded.")
        }
    }
}
