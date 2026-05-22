//
//  Recorder.swift
//  Neutral Zone Trap
//

import Foundation

/// Aktor zaznamenávající příchozí pozice do doménové `Session`; serializuje přístup mezi příjmem dat a exportem.
actor Recorder: RecordingControl, PositionRecording, SessionSnapshotting, SessionLoading {
    /// Nahrávaná nebo načtená session držící trajektorie všech senzorů.
    private var session = Session()
    /// Příznak, zda právě probíhá nahrávání; jen za jeho běhu se přijímají pozice.
    private(set) var isRecording = false

    /// Spustí nové nahrávání a zahodí předchozí session; když už nahrávání běží, je bez efektu.
    func startRecording() {
        guard !isRecording else { return }
        session = Session()
        isRecording = true
    }

    /// Zastaví nahrávání; již zaznamenaná data v session zůstávají zachována.
    func stopRecording() {
        isRecording = false
    }

    /// Připojí pozici do session, pokud právě běží nahrávání.
    /// - Parameter position: Pozice senzoru k zaznamenání.
    /// - Returns: `true`, když byla pozice přidána; `false`, když nahrávání neběží.
    @discardableResult
    func append(_ position: SensorPosition) -> Bool {
        guard isRecording else { return false }
        session.addPosition(position)
        return true
    }

    /// Vrátí aktuální stav session pro export nebo přehrávání.
    /// - Returns: Hodnotová kopie nahrané `Session`.
    func snapshot() -> Session {
        session
    }

    /// Nahradí session zvenčí dodaným snapshotem (např. po importu) a vypne nahrávání.
    /// - Parameter snapshot: Session, která se má načíst.
    func load(_ snapshot: Session) {
        session = snapshot
        isRecording = false
    }

    /// Zahodí nahranou session a vrátí recorder do výchozího stavu.
    func reset() {
        session = Session()
        isRecording = false
    }
}
