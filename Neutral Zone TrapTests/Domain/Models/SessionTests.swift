//
//  SessionTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.model))
struct SessionTests {

    @Test("Adding a position creates a new sensor track")
    func addPositionCreatesNewTrack() {
        var session = Session()
        let pos = TestHelpers.makeSensorPosition(id: 1, x: 5, y: 5)

        session.addPosition(pos)

        #expect(session.sensorTracks.count == 1)
        #expect(session.sensorTracks[0].sensorHardwareID == 1)
        #expect(session.sensorTracks[0].positions.count == 1)
    }

    @Test("Adding position for same sensor appends to existing track")
    func addPositionToExistingTrack() {
        var session = Session()
        session.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0))
        session.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 3, y: 4))

        #expect(session.sensorTracks.count == 1)
        #expect(session.sensorTracks[0].positions.count == 2)
    }

    @Test("Different sensor IDs create separate tracks")
    func addPositionDifferentSensorsCreatesSeparateTracks() {
        var session = Session()
        session.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0))
        session.addPosition(TestHelpers.makeSensorPosition(id: 2, x: 10, y: 10))

        #expect(session.sensorTracks.count == 2)
    }

    @Test("buildTimeline sorts all positions by timestamp")
    func buildTimelineSortsByTimestamp() {
        let baseTime = Date(timeIntervalSince1970: 1000)
        var session = Session()
        session.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime.addingTimeInterval(2)))
        session.addPosition(TestHelpers.makeSensorPosition(id: 2, x: 5, y: 5, timestamp: baseTime))
        session.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 1, y: 1, timestamp: baseTime.addingTimeInterval(1)))

        let timeline = session.buildTimeline()

        #expect(timeline.count == 3)
        #expect(timeline[0].timestamp == baseTime)
        #expect(timeline[1].timestamp == baseTime.addingTimeInterval(1))
        #expect(timeline[2].timestamp == baseTime.addingTimeInterval(2))
    }

    @Test("buildTimeline returns empty array for empty session")
    func buildTimelineEmpty() {
        let session = Session()
        let timeline = session.buildTimeline()

        #expect(timeline.isEmpty)
    }

    @Test("timeRange returns first..last timestamp")
    func timeRangeReturnsCorrectBounds() throws {
        let session = TestHelpers.makeSampleSession()

        let range = try #require(session.timeRange)
        #expect(range.lowerBound == Date(timeIntervalSince1970: 1000))
        #expect(range.upperBound == Date(timeIntervalSince1970: 1002))
    }

    @Test("timeRange is nil for empty session")
    func timeRangeNilForEmptySession() {
        let session = Session()

        #expect(session.timeRange == nil)
    }

    @Test("Snapshot at mid-session returns last known position per sensor")
    func snapshotAtMiddleTime() {
        let session = TestHelpers.makeSampleSession()
        let snapshotTime = Date(timeIntervalSince1970: 1001) // v t=1s

        let snapshot = session.snapshot(at: snapshotTime)

        // Senzor 1: pozice v t=1s existuje -> (3, 4)
        #expect(snapshot[1]?.x == 3)
        #expect(snapshot[1]?.y == 4)

        // Senzor 2: pozice v t=0.5s je poslední před t=1s -> (10, 10)
        #expect(snapshot[2]?.x == 10)
        #expect(snapshot[2]?.y == 10)
    }

    @Test("Snapshot before all data returns empty dictionary")
    func snapshotBeforeAllData() {
        let session = TestHelpers.makeSampleSession()
        let earlyTime = Date(timeIntervalSince1970: 999)

        let snapshot = session.snapshot(at: earlyTime)

        #expect(snapshot.isEmpty)
    }

    @Test("Snapshot at end returns latest position for each sensor")
    func snapshotAtEndReturnsAllLatest() {
        let session = TestHelpers.makeSampleSession()
        let endTime = Date(timeIntervalSince1970: 1002)

        let snapshot = session.snapshot(at: endTime)

        #expect(snapshot[1]?.x == 6)
        #expect(snapshot[1]?.y == 8)
        #expect(snapshot[2]?.x == 13)
        #expect(snapshot[2]?.y == 14)
    }

    @Test("Direct value assignment copies tracks")
    func valueAssignmentCopiesTracks() {
        var session = Session()
        let sample = TestHelpers.makeSampleSession()

        session = sample

        #expect(session.sensorTracks.count == sample.sensorTracks.count)
    }

    @Test("clear empties the session")
    func clearEmpties() {
        var session = TestHelpers.makeSampleSession()
        #expect(session.sensorTracks.isEmpty == false)

        session.clear()

        #expect(session.sensorTracks.isEmpty)
    }
}
