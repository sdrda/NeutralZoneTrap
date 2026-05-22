//
//  NZTDocument.swift
//  Neutral Zone Trap
//

import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    /// Vlastní UTI pro soubory s příponou `.nzt`, exportovaná jako `com.sdrda.nzt-session`.
    nonisolated static let nztSession = UTType(exportedAs: "com.sdrda.nzt-session")
}

/// Adaptér `FileDocument` pro export a import session ve formátu `.nzt` (JSON zabalený do `NZTWireFormat`).
/// Typ je `nonisolated` a `Sendable`, takže jej SwiftUI může předávat mezi vlákny bez omezení.
nonisolated struct NZTDocument: FileDocument, Sendable {
    /// Typy souborů, které dokument umí přečíst; obsahuje pouze `.nztSession`.
    static var readableContentTypes: [UTType] { [.nztSession] }

    /// Session se stopami senzorů, která je součástí dokumentu.
    let session: Session
    /// Datum a čas exportu dokumentu.
    let exportDate: Date

    /// Vytvoří nový dokument pro export dané session; `exportDate` se nastaví na aktuální čas.
    /// - Parameter session: Session, která se má zapsat do souboru.
    init(session: Session) {
        self.session = session
        self.exportDate = Date()
    }

    /// Naplní dokument daty z konfigurace čtení předané SwiftUI systémem.
    /// - Parameter configuration: Konfigurace čtení obsahující surová data souboru.
    /// - Throws: `CocoaError(.fileReadCorruptFile)` pokud soubor neobsahuje data,
    ///   nebo chyba `JSONDecoder` při neplatném formátu `NZTWireFormat`.
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let wire = try JSONDecoder().decode(NZTWireFormat.self, from: data)
        self.session = Session(sensorTracks: wire.sensorTracks)
        self.exportDate = wire.exportDate
    }

    /// Serializuje session do `FileWrapper` zakódováním do `NZTWireFormat` (JSON).
    /// - Parameter configuration: Konfigurace zápisu předaná SwiftUI systémem (nevyužívá se).
    /// - Returns: `FileWrapper` s JSON daty reprezentujícími `NZTWireFormat`.
    /// - Throws: Chyba `JSONEncoder` při selhání serializace.
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let wire = NZTWireFormat(
            sensorTracks: session.sensorTracks,
            exportDate: exportDate
        )
        let data = try JSONEncoder().encode(wire)
        return FileWrapper(regularFileWithContents: data)
    }
}

/// Serializovatelná struktura popisující obsah `.nzt` souboru; kóduje se jako JSON.
nonisolated struct NZTWireFormat: Codable, Sendable {
    /// Pole stop jednotlivých senzorů, každá obsahuje seznam pozic zaznamenaných během session.
    let sensorTracks: [SensorTrack]
    /// Datum a čas, kdy byl soubor vyexportován.
    let exportDate: Date
}
