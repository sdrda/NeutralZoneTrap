//
//  SensorTrackTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.model))
struct SensorTrackTests {

    @Test("New track is empty with zero distance")
    func initializesEmpty() {
        let track = SensorTrack(sensorHardwareID: 1)

        #expect(track.positions.isEmpty)
        #expect(track.totalDistance == 0)
        #expect(track.sensorHardwareID == 1)
    }

    @Test("First position does not increase total distance")
    func addFirstPositionKeepsDistanceZero() {
        var track = SensorTrack(sensorHardwareID: 1)
        let pos = TestHelpers.makeSensorPosition(id: 1, x: 5, y: 5)

        track.addPosition(pos)

        #expect(track.positions.count == 1)
        #expect(track.totalDistance == 0)
    }

    @Test("Second position accumulates Euclidean distance")
    func addSecondPositionAccumulatesDistance() {
        var track = SensorTrack(sensorHardwareID: 1)
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 3, y: 4))

        #expect(track.positions.count == 2)
        #expect(track.totalDistance == 5.0)
    }

    @Test("Distance accumulates over multiple positions")
    func accumulatesDistanceOverMultiplePositions() {
        var track = SensorTrack(sensorHardwareID: 1)
        // (0,0) -> (3,4) = 5
        // (3,4) -> (6,8) = 5
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 3, y: 4))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 6, y: 8))

        #expect(track.positions.count == 3)
        #expect(track.totalDistance == 10.0)
    }

    @Test("Stationary positions add zero distance")
    func stationaryPositionsAddZeroDistance() {
        var track = SensorTrack(sensorHardwareID: 1)
        let pos = TestHelpers.makeSensorPosition(id: 1, x: 5, y: 5)

        track.addPosition(pos)
        track.addPosition(pos)
        track.addPosition(pos)

        #expect(track.positions.count == 3)
        #expect(track.totalDistance == 0)
    }

    // MARK: - Chronologické řazení

    @Test("In-order positions stay in order")
    func inOrderPositionsStayInOrder() {
        let base = Date(timeIntervalSince1970: 1000)
        var track = SensorTrack(sensorHardwareID: 1)

        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: base))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 0, timestamp: base.addingTimeInterval(1)))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 2, y: 0, timestamp: base.addingTimeInterval(2)))

        #expect(track.positions.count == 3)
        #expect(track.positions[0].timestamp == base)
        #expect(track.positions[1].timestamp == base.addingTimeInterval(1))
        #expect(track.positions[2].timestamp == base.addingTimeInterval(2))
    }

    @Test("Out-of-order position is inserted at correct chronological index")
    func outOfOrderPositionIsInsertedCorrectly() {
        let base = Date(timeIntervalSince1970: 1000)
        var track = SensorTrack(sensorHardwareID: 1)

        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: base))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 2, y: 0, timestamp: base.addingTimeInterval(2)))
        // Vlož pozici s timestampem mezi dvě existující
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 0, timestamp: base.addingTimeInterval(1)))

        #expect(track.positions.count == 3)
        #expect(track.positions[0].timestamp == base)
        #expect(track.positions[1].timestamp == base.addingTimeInterval(1))
        #expect(track.positions[2].timestamp == base.addingTimeInterval(2))
    }

    @Test("Position with earliest timestamp is inserted at the beginning")
    func earliestTimestampInsertedAtBeginning() {
        let base = Date(timeIntervalSince1970: 1000)
        var track = SensorTrack(sensorHardwareID: 1)

        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 0, timestamp: base.addingTimeInterval(1)))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 2, y: 0, timestamp: base.addingTimeInterval(2)))
        // Vlož pozici před všechny existující
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: base))

        #expect(track.positions.count == 3)
        #expect(track.positions[0].timestamp == base)
        #expect(track.positions[1].timestamp == base.addingTimeInterval(1))
        #expect(track.positions[2].timestamp == base.addingTimeInterval(2))
    }

    @Test("Total distance is recalculated after out-of-order insertion")
    func totalDistanceRecalculatedAfterReorder() {
        let base = Date(timeIntervalSince1970: 1000)
        var track = SensorTrack(sensorHardwareID: 1)

        // (0,0) -> (3,0) = vzdálenost 3
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: base))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 3, y: 0, timestamp: base.addingTimeInterval(2)))
        #expect(track.totalDistance == 3.0)

        // Vlož (1,0) mezi ně: (0,0)->(1,0) = 1, (1,0)->(3,0) = 2, celkem = 3
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 0, timestamp: base.addingTimeInterval(1)))
        #expect(track.totalDistance == 3.0)
    }

    @Test("Equal timestamps are appended without reorder")
    func equalTimestampsAppended() {
        let base = Date(timeIntervalSince1970: 1000)
        var track = SensorTrack(sensorHardwareID: 1)

        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: base))
        track.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 0, timestamp: base))

        #expect(track.positions.count == 2)
        // Oba se stejným časem, druhý by měl být připojen za první
        #expect(track.positions[0].x == 0)
        #expect(track.positions[1].x == 1)
    }
}
