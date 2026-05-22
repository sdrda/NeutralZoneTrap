//
//  SessionAnalyticsTests.swift
//  Neutral Zone TrapTests
//
//  Čisté logické testy analytických helperů na `Session`. Běží bez jakéhokoli
//  napojení view-modelu nebo persistence, protože helpery operují nad
//  immutable value type.
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.model, .metrics))
struct SessionAnalyticsTests {

    // MARK: - totalDistance

    @Test("totalDistance returns 0 for an unknown sensor")
    func totalDistanceUnknownSensorReturnsZero() {
        let session = TestHelpers.makeSampleSession()

        #expect(session.totalDistance(forSensor: SensorHardwareID(99)) == 0)
    }

    @Test("totalDistance reflects accumulated track distance")
    func totalDistanceReflectsAccumulatedDistance() {
        // Senzor 1 ve vzorové session: (0,0) → (3,4) → (6,8) = 5m + 5m
        let session = TestHelpers.makeSampleSession()

        #expect(abs(session.totalDistance(forSensor: SensorHardwareID(1)) - 10.0) < 0.0001)
    }

    // MARK: - points

    @Test("points returns empty array for unknown sensor")
    func pointsUnknownSensorIsEmpty() {
        let session = TestHelpers.makeSampleSession()

        #expect(session.points(forSensor: SensorHardwareID(99)).isEmpty)
    }

    @Test("points returns positions in original order for the requested sensor")
    func pointsReturnsRecordedPositions() {
        let session = TestHelpers.makeSampleSession()

        let points = session.points(forSensor: SensorHardwareID(1))

        #expect(points.count == 3)
        #expect(points[0] == CGPoint(x: 0, y: 0))
        #expect(points[1] == CGPoint(x: 3, y: 4))
        #expect(points[2] == CGPoint(x: 6, y: 8))
    }

    @Test("points(forSensors:) concatenates multiple sensor tracks")
    func pointsForSensorsConcatenates() {
        let session = TestHelpers.makeSampleSession()

        let points = session.points(forSensors: [SensorHardwareID(1), SensorHardwareID(2)])

        // senzor 1 má 3 pozice, senzor 2 má 2
        #expect(points.count == 5)
    }

    @Test("points(forSensors:) skips unknown sensors silently")
    func pointsForSensorsSkipsUnknown() {
        let session = TestHelpers.makeSampleSession()

        let points = session.points(forSensors: [SensorHardwareID(1), SensorHardwareID(42)])

        #expect(points.count == 3)
    }

    @Test("points(forSensors:) returns empty for empty input")
    func pointsForSensorsEmptyInput() {
        let session = TestHelpers.makeSampleSession()

        #expect(session.points(forSensors: [SensorHardwareID]()).isEmpty)
    }
}
