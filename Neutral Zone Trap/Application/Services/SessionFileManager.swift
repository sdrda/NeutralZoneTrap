//
//  SessionFileManager.swift
//  Neutral Zone Trap
//

import Foundation

/// Observable služba pro souborové operace nad `Session`: export do `.nzt` dokumentu a import z file URL včetně stahování z iCloudu. Stav řídí prezentaci SwiftUI sheetů, proto je izolovaná na `MainActor`.
@Observable
final class SessionFileManager: FileManagerControl {

    /// Zda je export sheet (`.fileExporter`) právě prezentovaný.
    var isExporting = false

    /// Zda je import sheet (`.fileImporter`) právě prezentovaný.
    var isImporting = false

    /// Probíhá načítání importované session, včetně případného stažení
    /// souboru uživatel dostal okamžitou zpětnou vazbu místo opožděné chyby.
    private(set) var isLoadingImport = false

    /// Řídí prezentaci potvrzení o zahození neuložené nahrávky před opuštěním přehrávání.
    var showDiscardConfirmation = false

    /// Zda byla aktuální session alespoň jednou exportovaná (uložená).
    private(set) var isSessionSaved = false

    /// Název souboru importované session; `nil`, když byla session nahraná lokálně.
    private(set) var importedFileName: String?

    /// Dokument připravený k exportu. Nastaví se těsně před tím, než se
    /// `isExporting` přepne na `true`, aby měl SwiftUI exporter co zapsat.
    var exportDocument: NZTDocument?

    /// Recorder, ze kterého se získává snapshot k exportu a do kterého se nahrává importovaná session.
    private let recorder: any SessionSnapshotting & SessionLoading

    /// Vytvoří službu s injektovaným recorderem.
    /// - Parameter recorder: Zdroj snapshotu k exportu a cíl pro načtení importu.
    init(recorder: any SessionSnapshotting & SessionLoading) {
        self.recorder = recorder
    }

    /// Vyžádá si snapshot z recorderu, sestaví exportní dokument a otevře `.fileExporter`.
    func exportSession() async {
        let snapshot = await recorder.snapshot()
        exportDocument = NZTDocument(session: snapshot)
        isExporting = true
    }

    /// Označí aktuální session za uloženou (volá se po úspěšném exportu).
    func markSessionSaved() {
        isSessionSaved = true
    }

    /// Ověří, zda lze opustit přehrávání: při uložené session povolí odchod, jinak vyvolá potvrzení o zahození.
    /// - Returns: `true`, když je session uložená a lze odejít; `false`, když se zobrazí potvrzení.
    func requestExitPlayback() -> Bool {
        if isSessionSaved {
            return true
        } else {
            showDiscardConfirmation = true
            return false
        }
    }

    /// Naimportuje session z výsledku `.fileImporter`: zajistí stažení z iCloudu, koordinovaně přečte a dekóduje `.nzt` data, načte je do recorderu a po dobu načítání drží indikátor průběhu (``isLoadingImport``).
    /// - Parameter result: Výsledek výběru souboru z `.fileImporter` (URL nebo chyba).
    /// - Throws: ``SessionError`` při neúspěšném stažení či dekódování (propagovaná nebo zabalená do ``SessionError/importFailed(underlying:)``), nebo původní chybu výběru souboru.
    func importSession(from result: Result<URL, any Error>) async throws {
        switch result {
        case .success(let url):
            // Zapneme indikator nacitani, idealni by to bylo mit v nejaky vrstve jak ErrorRouter
            setLoadingImport(true)
            
            // Uklizeni po odchodu
            defer { Task { @MainActor in self.isLoadingImport = false } }

            do {
                // Security-scoped access
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }

                let data = try await readSessionData(at: url)
                let wire = try JSONDecoder().decode(NZTWireFormat.self, from: data)
                let snapshot = Session(sensorTracks: wire.sensorTracks)
                await recorder.load(snapshot)

                // Mutace stavu na MainActoru
                let name = url.deletingPathExtension().lastPathComponent
                await MainActor.run {
                    importedFileName = name
                    isSessionSaved = true
                }
            } catch let error as SessionError {
                // Pro probublani chyb
                throw error
            } catch {
                throw SessionError.importFailed(underlying: error)
            }

        case .failure(let error):
            throw error
        }
    }

    @MainActor
    private func setLoadingImport(_ value: Bool) {
        isLoadingImport = value
    }

    /// Maximální doba čekání na stažení iCloud souboru v sekundách.
    private static let downloadTimeout: TimeInterval = 30

    /// Zajistí stažení a koordinovaně přečte obsah `.nzt` souboru.
    /// - Parameter url: Umístění souboru ke čtení.
    /// - Returns: Surová data souboru.
    /// - Throws: ``SessionError/downloadTimedOut`` při překročení limitu stahování, nebo chybu čtení.
    private func readSessionData(at url: URL) async throws -> Data {
        try await ensureDownloaded(url)
        return try coordinatedRead(url)
    }

    /// Je-li URL položkou iCloudu, spustí její stažení a aktivně čeká (s pollingem) na dokončení; lokální soubory projdou okamžitě.
    /// - Parameter url: Umístění souboru.
    /// - Throws: ``SessionError/downloadTimedOut`` po vypršení ``downloadTimeout``, nebo `CancellationError` při zrušení.
    private func ensureDownloaded(_ url: URL) async throws {
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let values = try? url.resourceValues(forKeys: keys),
              values.isUbiquitousItem == true,
              values.ubiquitousItemDownloadingStatus != .current
        else { return }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)

        let deadline = Date().addingTimeInterval(Self.downloadTimeout)
        while Date() < deadline {
            try Task.checkCancellation()
            let status = try url
                .resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey])
                .ubiquitousItemDownloadingStatus
            if status == .current { return }
            try await Task.sleep(for: .milliseconds(200))
        }
        throw SessionError.downloadTimedOut
    }

    /// Koordinovaně přečte soubor přes `NSFileCoordinator`, čímž získá konzistentní snapshot vůči případnému iCloud zápisu; správná cesta ke čtení dokumentů žijících mimo sandbox.
    /// - Parameter url: Umístění souboru ke čtení.
    /// - Returns: Surová data souboru.
    /// - Throws: Chybu koordinátoru nebo chybu čtení; `CocoaError(.fileReadUnknown)`, když koordinátor nevrátí data.
    private func coordinatedRead(_ url: URL) throws -> Data {
        var coordinatorError: NSError?
        var data: Data?
        var readError: Error?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinatorError) { coordinatedURL in
            do { data = try Data(contentsOf: coordinatedURL) }
            catch { readError = error }
        }
        if let coordinatorError { throw coordinatorError }
        if let readError { throw readError }
        guard let data else { throw CocoaError(.fileReadUnknown) }
        return data
    }

    /// Resetuje stav sledování souboru (název i příznak uložení) při opuštění načtené session.
    func resetFileState() {
        importedFileName = nil
        isSessionSaved = false
    }

    /// Resetuje stav, když se začíná nové nahrávání nad dříve importovanou nebo uloženou session.
    func resetForNewRecording() {
        isSessionSaved = false
        importedFileName = nil
    }
}
