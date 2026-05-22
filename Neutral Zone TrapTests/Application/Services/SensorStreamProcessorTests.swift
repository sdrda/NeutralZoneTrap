//
//  SensorStreamProcessorTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.networking))
struct SensorStreamProcessorTests {

    @Test("Parsed positions are forwarded to the position store")
    func storeReceivesParsedPositions() async throws {
        let timestamp: Double = 1713400000.0
        let packet = TestHelpers.makePacket(x: 12.5, y: -3.7, playerID: 5, timestamp: timestamp)

        let receiver = MockUDPReceiver()
        await receiver.setPackets([packet])

        let store = SensorPositionStore()
        let recorder = Recorder()
        let statistics = Statistics()

        let processor = SensorStreamProcessor(
            receiver: receiver,
            store: store,
            recorder: recorder,
            statistics: statistics
        )
        await processor.start()

        // Polluj dokud store neobdrží parsovanou pozici, nebo do timeoutu.
        let deadline = Date().addingTimeInterval(2.0)
        var snapshot: [SensorHardwareID: SensorPosition] = [:]
        let id5 = SensorHardwareID(5)
        while snapshot[id5] == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await store.snapshot()
        }

        await processor.stop()

        #expect(snapshot[id5]?.id == id5)
        #expect(snapshot[id5]?.x == CGFloat(12.5))
        #expect(snapshot[id5]?.y == CGFloat(-3.7))
    }

    @Test("Invalid packets are skipped, valid ones reach the store")
    func invalidPacketsAreSkipped() async throws {
        let validPacket = TestHelpers.makePacket(x: 5, y: 10, playerID: 3, timestamp: 1000)
        let invalidPacket = Data(repeating: 0, count: 10) // příliš krátký

        let receiver = MockUDPReceiver()
        await receiver.setPackets([invalidPacket, validPacket])

        let store = SensorPositionStore()
        let recorder = Recorder()
        let statistics = Statistics()

        let processor = SensorStreamProcessor(
            receiver: receiver,
            store: store,
            recorder: recorder,
            statistics: statistics
        )
        await processor.start()

        let deadline = Date().addingTimeInterval(2.0)
        var snapshot: [SensorHardwareID: SensorPosition] = [:]
        let id3 = SensorHardwareID(3)
        while snapshot[id3] == nil, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await store.snapshot()
        }

        await processor.stop()

        // Jen validní paket (senzor 3) měl vyprodukovat pozici.
        #expect(snapshot.count == 1)
        #expect(snapshot[id3]?.id == id3)
    }

    @Test("Live positions also flow into the recorder while recording")
    func recordingCapturesPositions() async throws {
        let baseTime: Double = 2_000_000_000
        let packets = [
            TestHelpers.makePacket(x: 1, y: 2, playerID: 9, timestamp: baseTime),
            TestHelpers.makePacket(x: 3, y: 4, playerID: 9, timestamp: baseTime + 1),
        ]

        let receiver = MockUDPReceiver()
        await receiver.setPackets(packets)

        let store = SensorPositionStore()
        let recorder = Recorder()
        let statistics = Statistics()

        await recorder.startRecording()

        let processor = SensorStreamProcessor(
            receiver: receiver,
            store: store,
            recorder: recorder,
            statistics: statistics
        )
        await processor.start()

        let deadline = Date().addingTimeInterval(2.0)
        var captured = 0
        while captured < packets.count, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            let snap = await recorder.snapshot()
            captured = snap.buildTimeline().count
        }

        await recorder.stopRecording()
        await processor.stop()

        let snapshot = await recorder.snapshot()
        #expect(snapshot.buildTimeline().count == packets.count)
    }
}
