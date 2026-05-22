//
//  IntegrationTests.swift
//  Neutral Zone TrapTests
//
//  End-to-end integrace napříč celou kritickou cestou:
//  UDP bajty → SensorStreamProcessor → Recorder → JSON soubor →
//  SessionFileManager → Playback.
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.integration), .serialized)
struct IntegrationTests {

    // MARK: - Helpery

    // Prozene UDP pakety pres SensorStreamPosition a pomoci recorderu nahraje Session
    private func recordSession(from packets: [Data], expectedValidPositions: Int) async throws -> Session {
        let receiver = MockUDPReceiver()
        await receiver.setPackets(packets)

        let recorder = Recorder()
        let store = SensorPositionStore()
        let statistics = Statistics()

        await recorder.startRecording()

        let processor = SensorStreamProcessor(
            receiver: receiver,
            store: store,
            recorder: recorder,
            statistics: statistics
        )
        await processor.start()

        // Polluj dokud nedorazí očekávaný počet, nebo do timeoutu.
        let deadline = Date().addingTimeInterval(2.0)
        var captured = 0
        while captured < expectedValidPositions, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            let snap = await recorder.snapshot()
            captured = snap.buildTimeline().count
        }

        await recorder.stopRecording()
        await processor.stop()
        return await recorder.snapshot()
    }

    // Zapise session do docasneho .nzt souboru a vrati jeho URL.
    // Volajici je zodpovědný za nasledne smazani souboru.
    private func writeSessionToTempFile(_ session: Session) throws -> URL {
        let wire = NZTWireFormat(
            sensorTracks: session.sensorTracks,
            exportDate: Date()
        )
        let data = try JSONEncoder().encode(wire)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("nzt")
        try data.write(to: url)
        return url
    }

    // MARK: - End-to-end testy

    @Test("Raw UDP bytes travel intact through parse, record, export, import")
    func fullRoundTripPreservesAllPositions() async throws {
        let baseTime: Double = 1_713_400_000
        let packets = [
            TestHelpers.makePacket(x: 0,    y: 0,    playerID: 1, timestamp: baseTime),
            TestHelpers.makePacket(x: 3,    y: 4,    playerID: 1, timestamp: baseTime + 1),
            TestHelpers.makePacket(x: 6,    y: 8,    playerID: 1, timestamp: baseTime + 2),
            TestHelpers.makePacket(x: 10,   y: 10,   playerID: 2, timestamp: baseTime + 0.5),
            TestHelpers.makePacket(x: 13,   y: 14,   playerID: 2, timestamp: baseTime + 1.5),
        ]

        let recorded = try await recordSession(from: packets, expectedValidPositions: packets.count)
        #expect(recorded.sensorTracks.count == 2)

        let fileURL = try writeSessionToTempFile(recorded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let recorder = Recorder()
        let fileManager = SessionFileManager(recorder: recorder)
        try await fileManager.importSession(from: .success(fileURL))

        let imported = await recorder.snapshot()
        let originalTimeline = recorded.buildTimeline()
        let importedTimeline = imported.buildTimeline()
        #expect(originalTimeline.count == importedTimeline.count)
        #expect(originalTimeline == importedTimeline)

        #expect(fileManager.isSessionSaved == true)
        #expect(fileManager.importedFileName != nil)
    }

    @Test("Imported session can be played back by Playback")
    func importedSessionFeedsPlayback() async throws {
        let baseTime: Double = 2_000_000_000
        let packets = [
            TestHelpers.makePacket(x: -5, y: -5, playerID: 7, timestamp: baseTime),
            TestHelpers.makePacket(x:  5, y:  5, playerID: 7, timestamp: baseTime + 1),
        ]

        let recorded = try await recordSession(from: packets, expectedValidPositions: packets.count)
        let fileURL = try writeSessionToTempFile(recorded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let recorder = Recorder()
        let fileManager = SessionFileManager(recorder: recorder)
        try await fileManager.importSession(from: .success(fileURL))

        let statistics = Statistics()
        let playbackStore = SensorPositionStore()
        let playback = Playback(statistics: statistics, store: playbackStore, snapshotProvider: recorder)

        // Playback cerpa z recorderu, do kterého import zapsal session, takže
        // load() uspeje a odvodi timeRange z naimportovanych dat.
        try await playback.load()

        let range = try #require(playback.timeRange)
        #expect(range.lowerBound == Date(timeIntervalSince1970: baseTime))
        #expect(range.upperBound == Date(timeIntervalSince1970: baseTime + 1))

        let imported = await recorder.snapshot()
        let endTime = Date(timeIntervalSince1970: baseTime + 1)
        let snapshot = imported.snapshot(at: endTime)
        #expect(snapshot[7]?.x == 5)
        #expect(snapshot[7]?.y == 5)
    }

    @Test("Distance is preserved across export and re-import")
    func distanceSurvivesRoundTrip() async throws {
        let baseTime: Double = 1_000_000_000
        let packets = [
            TestHelpers.makePacket(x: 0, y: 0, playerID: 1, timestamp: baseTime),
            TestHelpers.makePacket(x: 3, y: 4, playerID: 1, timestamp: baseTime + 1),
            TestHelpers.makePacket(x: 6, y: 8, playerID: 1, timestamp: baseTime + 2),
        ]

        let recorded = try await recordSession(from: packets, expectedValidPositions: packets.count)
        let originalDistance = recorded.sensorTracks[0].totalDistance
        #expect(abs(originalDistance - 10.0) < 0.001)

        let fileURL = try writeSessionToTempFile(recorded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let recorder = Recorder()
        let fileManager = SessionFileManager(recorder: recorder)
        try await fileManager.importSession(from: .success(fileURL))

        let imported = await recorder.snapshot()
        let importedDistance = imported.sensorTracks[0].totalDistance
        #expect(abs(importedDistance - originalDistance) < 0.001)
    }

    @Test("Invalid packets mixed with valid ones do not corrupt the session")
    func pipelineSkipsInvalidPackets() async throws {
        let baseTime: Double = 1_500_000_000
        let packets = [
            Data(repeating: 0, count: 10),
            TestHelpers.makePacket(x: 1, y: 1, playerID: 3, timestamp: baseTime),
            Data(),
            TestHelpers.makePacket(x: 2, y: 2, playerID: 3, timestamp: baseTime + 1),
        ]

        let recorded = try await recordSession(from: packets, expectedValidPositions: 2)

        #expect(recorded.sensorTracks.count == 1)
        #expect(recorded.sensorTracks[0].positions.count == 2)
        #expect(recorded.sensorTracks[0].sensorHardwareID == 3)
    }

    @Test("Corrupt session file is rejected with SessionError.importFailed")
    func importRejectsCorruptFile() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("nzt")
        try Data("not a valid session file".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let recorder = Recorder()
        let fileManager = SessionFileManager(recorder: recorder)

        await #expect(throws: SessionError.self) {
            try await fileManager.importSession(from: .success(url))
        }
    }
}
