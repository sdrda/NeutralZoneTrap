//
//  RecordingControl.swift
//  Neutral Zone Trap
//

import Foundation

/// Abstrakce řízení životního cyklu nahrávání — spuštění, zastavení a reset.
///
/// Konformní typ (`Recorder`) je actor. Protokol je záměrně oddělen od `PositionRecording`,
/// aby komponenty zodpovědné za zápis pozic (např. `SensorStreamProcessor`) nemohly
/// nahrávání samy spouštět ani zastavovat. Prezentační vrstva injektuje
/// `any RecordingControl & SessionSnapshotting` přes prostředí SwiftUI.
protocol RecordingControl: Sendable {
    /// Zahájí nové nahrávání; předchozí obsah session je zahozen a interní příznak nahrávání nastaven.
    func startRecording() async
    /// Ukončí aktivní nahrávání; zaznamenaná data session zůstávají zachována.
    func stopRecording() async
    /// Zastaví nahrávání a smaže celý obsah aktuální session.
    func reset() async
}
