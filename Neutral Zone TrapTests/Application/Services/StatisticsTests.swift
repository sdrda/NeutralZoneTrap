//
//  StatisticsTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.observation))
struct StatisticsTests {

    @Test("insertPosition records the sensor ID and computes a smoothed speed")
    func insertPositionRecordsIDAndComputesSpeed() {
        let store = Statistics()
        let baseTime = Date(timeIntervalSince1970: 1000)

        // Druhý sample s rozdílem 1 s + známým posunem stačí, aby vyhlazení
        // vyprodukovalo rychlost — tím se ověří, že obě pozice protekly přes
        // insertPosition do smoothing okna.
        store.insertPosition(TestHelpers.makeSensorPosition(id: 7, x: 0, y: 0, timestamp: baseTime))
        store.insertPosition(TestHelpers.makeSensorPosition(
            id: 7, x: 3, y: 4,
            timestamp: baseTime.addingTimeInterval(1)
        ))

        #expect(store.activeIDs == [7])
        // Vzdálenost 5 m za 1 s, jediný sample v okně → publikovaná hodnota je 5 m/s.
        #expect(store.speeds[7] == 5)
    }

    @Test("Repeated inserts for the same sensor leave the active set unchanged")
    func insertSameSensorTwice() {
        let store = Statistics()
        let baseTime = Date(timeIntervalSince1970: 1000)

        store.insertPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        store.insertPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 5, y: 5,
            timestamp: baseTime.addingTimeInterval(1)
        ))

        #expect(store.activeIDs == [1])
        // Oba vzorky musí dorazit do smoothing okna, jinak by se speed
        // nikdy nespočítal (potřebuje předchozí pozici).
        #expect(store.speeds[1] != nil)
    }

    @Test("Distinct sensors accumulate in the active set")
    func distinctSensorsAccumulate() {
        let store = Statistics()
        let baseTime = Date(timeIntervalSince1970: 1000)

        store.insertPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        store.insertPosition(TestHelpers.makeSensorPosition(id: 2, x: 0, y: 0, timestamp: baseTime))

        #expect(store.activeIDs == [1, 2])
    }

    @Test("First position for a sensor publishes no speed yet")
    func firstPositionNoSpeed() {
        let store = Statistics()
        let pos = SensorPosition(id: 1, x: 0, y: 0, timestamp: Date())

        store.insertPosition(pos)

        #expect(store.activeIDs == [1])
        #expect(store.speeds[1] == nil)
    }

    @Test("Different sensors track speeds independently")
    func independentSensors() {
        let store = Statistics()
        let t0 = Date()
        let t1 = t0.addingTimeInterval(1)

        store.insertPosition(SensorPosition(id: 1, x: 0, y: 0, timestamp: t0))
        store.insertPosition(SensorPosition(id: 2, x: 0, y: 0, timestamp: t0))
        store.insertPosition(SensorPosition(id: 1, x: 3, y: 4, timestamp: t1))

        #expect(store.speeds[1] == 5.0)
        #expect(store.speeds[2] == nil)
    }

    @Test("Smoothed speed uses the last `windowSize` samples")
    func smoothedSpeedUsesWindow() throws {
        // windowSize = 3 dělá matiku snadno ověřitelnou ručně:
        // po 4 vzorcích je publikovaná hodnota z okna [s2, s3, s4], ne [s1…s4].
        let store = Statistics(windowSize: 3)
        let t0 = Date(timeIntervalSince1970: 0)

        store.insertPosition(SensorPosition(id: 1, x: 0, y: 0, timestamp: t0))
        store.insertPosition(SensorPosition(id: 1, x: 10, y: 0, timestamp: t0.addingTimeInterval(1)))   // 10
        store.insertPosition(SensorPosition(id: 1, x: 30, y: 0, timestamp: t0.addingTimeInterval(2)))   // 20
        store.insertPosition(SensorPosition(id: 1, x: 60, y: 0, timestamp: t0.addingTimeInterval(3)))   // 30
        store.insertPosition(SensorPosition(id: 1, x: 100, y: 0, timestamp: t0.addingTimeInterval(4)))  // 40

        // Okno = [20, 30, 40] → publikovaná hodnota = 30
        let smoothed = try #require(store.speeds[1])
        #expect(abs(smoothed - 30) < 0.0001)
    }

    @Test("reset clears the active set, speeds, and smoothing window")
    func resetClearsState() {
        let store = Statistics()
        let baseTime = Date(timeIntervalSince1970: 1000)

        // Dva samply, aby smoothing okno mělo po čem mazat.
        store.insertPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        store.insertPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 1, y: 1,
            timestamp: baseTime.addingTimeInterval(1)
        ))
        #expect(store.speeds[1] != nil)

        store.reset()

        #expect(store.activeIDs.isEmpty)
        #expect(store.speeds.isEmpty)
    }

    @Test("After reset, next position publishes no speed yet")
    func afterResetFirstPositionNoSpeed() {
        let store = Statistics()
        let t0 = Date()
        let t1 = t0.addingTimeInterval(1)
        let t2 = t0.addingTimeInterval(2)

        store.insertPosition(SensorPosition(id: 1, x: 0, y: 0, timestamp: t0))
        store.insertPosition(SensorPosition(id: 1, x: 3, y: 4, timestamp: t1))
        store.reset()

        store.insertPosition(SensorPosition(id: 1, x: 10, y: 10, timestamp: t2))

        #expect(store.speeds[1] == nil)
    }
}
