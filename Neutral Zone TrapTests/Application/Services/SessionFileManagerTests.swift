//
//  SessionFileManagerTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.fileManager))
struct SessionFileManagerTests {

    private func makeManager() -> (SessionFileManager, Recorder) {
        let recorder = Recorder()
        let manager = SessionFileManager(recorder: recorder)
        return (manager, recorder)
    }

    @Test("exportSession stages a document and presents the exporter")
    func exportSessionSetsState() async {
        let (mgr, _) = makeManager()

        await mgr.exportSession()

        #expect(mgr.exportDocument != nil)
        #expect(mgr.isExporting == true)
    }

    @Test("markSessionSaved flips the saved flag")
    func markSessionSavedSetsFlag() {
        let (mgr, _) = makeManager()

        mgr.markSessionSaved()

        #expect(mgr.isSessionSaved == true)
    }

    /// `requestExitPlayback` vrací, zda volající může okamžitě odejít
    /// (saved → ano, unsaved → ne, se zobrazením discard dialogu).
    @Test(
        "requestExitPlayback gates exit on the saved flag and raises the dialog when unsaved",
        arguments: [
            (saved: true,  expectedCanExit: true,  expectedDialog: false),
            (saved: false, expectedCanExit: false, expectedDialog: true),
        ]
    )
    func requestExitPlaybackGate(saved: Bool, expectedCanExit: Bool, expectedDialog: Bool) {
        let (mgr, _) = makeManager()
        if saved { mgr.markSessionSaved() }

        let canExit = mgr.requestExitPlayback()

        #expect(canExit == expectedCanExit)
        #expect(mgr.showDiscardConfirmation == expectedDialog)
    }

    /// Oba reset entry-pointy mažou stejná dvě pole file-state, takže test
    /// nad nimi parametrizuje místo duplikování identického těla.
    @Test(
        "Reset entry-points clear the saved flag and imported file name",
        arguments: [Reset.fileState, Reset.newRecording]
    )
    func resetClearsFileState(reset: Reset) {
        let (mgr, _) = makeManager()
        mgr.markSessionSaved()

        switch reset {
        case .fileState:    mgr.resetFileState()
        case .newRecording: mgr.resetForNewRecording()
        }

        #expect(mgr.isSessionSaved == false)
        #expect(mgr.importedFileName == nil)
    }

    enum Reset: Sendable, CaseIterable { case fileState, newRecording }

    @Test("importSession rethrows the picker failure verbatim")
    func importSessionFailure() async {
        let (mgr, _) = makeManager()
        let testError = NSError(domain: "test", code: 42)

        // Větev .failure v importSession přehazuje původní chybu beze změny,
        // takže můžeme matchovat přesnou instanci NSError.
        await #expect(throws: NSError.self) {
            try await mgr.importSession(from: .failure(testError))
        }
    }

    @Test("importSession from a valid file populates the shared session")
    func importSessionSuccess() async throws {
        let (mgr, recorder) = makeManager()

        // Postav vzorovou session, zakóduj ji a zapiš do temp souboru.
        let sample = TestHelpers.makeSampleSession()
        let wire = NZTWireFormat(
            sensorTracks: sample.sensorTracks,
            exportDate: Date()
        )
        let data = try JSONEncoder().encode(wire)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("nzt")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        try await mgr.importSession(from: .success(url))

        let recorderSnap = await recorder.snapshot()
        #expect(recorderSnap.sensorTracks.count == sample.sensorTracks.count)
        #expect(mgr.isSessionSaved == true)
        #expect(mgr.importedFileName != nil)
    }
}
