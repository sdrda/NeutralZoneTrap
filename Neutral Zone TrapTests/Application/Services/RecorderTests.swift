//
//  RecorderTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.recording))
struct RecorderTests {

    @Test("startRecording clears the session")
    func startRecordingResetsSession() async {
        let recorder = Recorder()

        // Předem nahraj nějaká data do recorderovy interní session přes load.
        await recorder.load(TestHelpers.makeSampleSession())
        var snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.isEmpty == false)

        // Spuštění nahrávání resetuje session.
        await recorder.startRecording()
        snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.isEmpty)
    }

    @Test("append writes to the session while recording")
    func appendWritesWhenActive() async {
        let recorder = Recorder()
        let baseTime = Date(timeIntervalSince1970: 1000)

        await recorder.startRecording()
        await recorder.append(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        await recorder.append(TestHelpers.makeSensorPosition(
            id: 1, x: 3, y: 4,
            timestamp: baseTime.addingTimeInterval(1)
        ))

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.count == 1)
        #expect(snapshot.sensorTracks[0].positions.count == 2)
    }

    @Test("append is a no-op while not recording")
    func appendIgnoredWhenInactive() async {
        let recorder = Recorder()

        await recorder.append(TestHelpers.makeSensorPosition(
            id: 1, x: 0, y: 0,
            timestamp: Date(timeIntervalSince1970: 1000)
        ))

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.isEmpty)
    }

    @Test("append stops writing after stopRecording")
    func appendStopsAfterStop() async {
        let recorder = Recorder()
        let baseTime = Date(timeIntervalSince1970: 1000)

        await recorder.startRecording()
        await recorder.append(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        await recorder.stopRecording()
        await recorder.append(TestHelpers.makeSensorPosition(
            id: 1, x: 3, y: 4,
            timestamp: baseTime.addingTimeInterval(1)
        ))

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.count == 1)
        #expect(snapshot.sensorTracks[0].positions.count == 1)
    }

    @Test("Calling startRecording twice is a no-op")
    func doubleStartRecordingIsIgnored() async {
        let recorder = Recorder()

        await recorder.startRecording()
        await recorder.startRecording() // mělo by být no-op

        #expect(await recorder.isRecording == true)
    }

    @Test("reset clears session and stops recording")
    func resetClearsAndStops() async {
        let recorder = Recorder()
        let baseTime = Date(timeIntervalSince1970: 1000)

        await recorder.startRecording()
        await recorder.append(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))

        await recorder.reset()

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.isEmpty)
        #expect(await recorder.isRecording == false)
    }

    @Test("load replaces the internal session with the given snapshot")
    func loadReplacesSession() async {
        let recorder = Recorder()
        let imported = TestHelpers.makeSampleSession()

        await recorder.load(imported)

        let snapshot = await recorder.snapshot()
        #expect(snapshot.sensorTracks.count == imported.sensorTracks.count)
    }

    @Test("load with an empty session keeps the snapshot empty")
    func loadEmptySessionKeepsSnapshotEmpty() async {
        let recorder = Recorder()

        await recorder.load(Session())

        let snapshot = await recorder.snapshot()
        #expect(snapshot.isEmpty())
    }
}
