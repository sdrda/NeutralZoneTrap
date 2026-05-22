//
//  PositionParserTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.parsing))
struct PositionParserTests {

    @Test(
        "Parses valid 32-byte packet",
        arguments: [
            (x: 12.5, y: -3.7, playerID: UInt64(5), timestamp: 1713400000.0),
            (x: 0.0, y: 0.0, playerID: UInt64(0), timestamp: 0.0),
            (x: -30.0, y: -15.0, playerID: UInt64(255), timestamp: 1000.0),
            (x: 1.0, y: 2.0, playerID: UInt64.max, timestamp: 1.0),
        ]
    )
    func parsesValidPacket(x: Double, y: Double, playerID: UInt64, timestamp: Double) throws {
        let data = TestHelpers.makePacket(x: x, y: y, playerID: playerID, timestamp: timestamp)

        let result = try #require(PositionParser.transformToPlayerPosition(from: data))

        #expect(result.id == SensorHardwareID(playerID))
        #expect(result.x == CGFloat(x))
        #expect(result.y == CGFloat(y))
        #expect(result.timestamp == Date(timeIntervalSince1970: timestamp))
    }

    @Test("Returns nil for packet shorter than 32 bytes")
    func returnsNilForShortPacket() {
        let shortData = Data(repeating: 0, count: 31)

        let result = PositionParser.transformToPlayerPosition(from: shortData)

        #expect(result == nil)
    }

    @Test("Returns nil for empty packet")
    func returnsNilForEmptyPacket() {
        let result = PositionParser.transformToPlayerPosition(from: Data())

        #expect(result == nil)
    }

    @Test("Parses packet with exactly 32 bytes")
    func parsesExactly32Bytes() {
        let data = TestHelpers.makePacket(x: 1.0, y: 2.0, playerID: 10, timestamp: 500)

        let result = PositionParser.transformToPlayerPosition(from: data)

        #expect(result != nil)
    }

    @Test("Ignores extra bytes beyond 32")
    func parsesLargerThan32Bytes() throws {
        var data = TestHelpers.makePacket(x: 5.0, y: 6.0, playerID: 7, timestamp: 999)
        data.append(Data(repeating: 0xFF, count: 16)) // přebytečné bajty

        let result = try #require(PositionParser.transformToPlayerPosition(from: data))

        #expect(result.id == 7)
        #expect(result.x == CGFloat(5.0))
    }
}
