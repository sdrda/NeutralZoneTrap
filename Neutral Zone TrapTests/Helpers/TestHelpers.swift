//
//  TestHelpers.swift
//  Neutral Zone TrapTests
//

import Foundation
@testable import Neutral_Zone_Trap

/// Helpery pro konstrukci testovacích dat
enum TestHelpers {

    /// Vytvoří 32bajtový UDP paket se zadanými hodnotami v little-endian formátu.
    static func makePacket(x: Double, y: Double, playerID: UInt64, timestamp: Double) -> Data {
        var data = Data(count: 32)
        data.withUnsafeMutableBytes { buffer in
            buffer.storeBytes(of: x, toByteOffset: 0, as: Double.self)
            buffer.storeBytes(of: y, toByteOffset: 8, as: Double.self)
            buffer.storeBytes(of: playerID.littleEndian, toByteOffset: 16, as: UInt64.self)
            buffer.storeBytes(of: timestamp, toByteOffset: 24, as: Double.self)
        }
        return data
    }

    static func makeSensorPosition(id: UInt64, x: CGFloat, y: CGFloat, timestamp: Date = Date()) -> SensorPosition {
        SensorPosition(id: SensorHardwareID(id), x: x, y: y, timestamp: timestamp)
    }

    /// Vytvoří session se známými pozicemi pro testování
    static func makeSampleSession() -> Session {
        let baseTime = Date(timeIntervalSince1970: 1000)
        var session = Session()

        // Senzor 1: 3 pozice
        session.addPosition(makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        session.addPosition(makeSensorPosition(id: 1, x: 3, y: 4, timestamp: baseTime.addingTimeInterval(1)))
        session.addPosition(makeSensorPosition(id: 1, x: 6, y: 8, timestamp: baseTime.addingTimeInterval(2)))

        // Senzor 2: 2 pozice
        session.addPosition(makeSensorPosition(id: 2, x: 10, y: 10, timestamp: baseTime.addingTimeInterval(0.5)))
        session.addPosition(makeSensorPosition(id: 2, x: 13, y: 14, timestamp: baseTime.addingTimeInterval(1.5)))

        return session
    }
}
