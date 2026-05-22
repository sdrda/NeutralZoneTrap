//
//  SensorMetricsTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.metrics))
struct SensorMetricsTests {

    @Test(
        "Distance between two points",
        arguments: [
            (ax: 5.0, ay: 5.0, bx: 5.0, by: 5.0, expected: 0.0),    // stejný bod
            (ax: 0.0, ay: 0.0, bx: 3.0, by: 0.0, expected: 3.0),    // horizontální
            (ax: 0.0, ay: 0.0, bx: 0.0, by: 4.0, expected: 4.0),    // vertikální
            (ax: 0.0, ay: 0.0, bx: 3.0, by: 4.0, expected: 5.0),    // 3-4-5 diagonála
            (ax: -3.0, ay: -4.0, bx: 0.0, by: 0.0, expected: 5.0),  // záporné souřadnice
        ]
    )
    func distanceBetweenPoints(ax: Double, ay: Double, bx: Double, by: Double, expected: Double) {
        let a = TestHelpers.makeSensorPosition(id: 1, x: ax, y: ay)
        let b = TestHelpers.makeSensorPosition(id: 1, x: bx, y: by)

        let d = SensorMetrics.distance(from: a, to: b)

        #expect(d == expected)
    }

    @Test("Distance is symmetric: d(a,b) == d(b,a)")
    func distanceIsSymmetric() {
        let a = TestHelpers.makeSensorPosition(id: 1, x: 1, y: 2)
        let b = TestHelpers.makeSensorPosition(id: 1, x: 4, y: 6)

        let ab = SensorMetrics.distance(from: a, to: b)
        let ba = SensorMetrics.distance(from: b, to: a)

        #expect(ab == ba)
    }

    @Test(
        "Speed for varying time intervals",
        arguments: [
            (interval: 1.0, expected: Optional<Double>.some(5.0)),
            (interval: 0.0, expected: Optional<Double>.none),
            (interval: -1.0, expected: Optional<Double>.none),
        ]
    )
    func speedForTimeInterval(interval: TimeInterval, expected: Double?) {
        let baseTime = Date(timeIntervalSince1970: 1000)
        let a = TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime)
        let b = TestHelpers.makeSensorPosition(id: 1, x: 3, y: 4, timestamp: baseTime.addingTimeInterval(interval))

        let speed = SensorMetrics.speed(from: a, to: b)

        #expect(speed == expected)
    }

}
