//
//  NZTDocumentTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.serialization))
struct NZTDocumentTests {

    @Test("NZTDocument exposes session and sets exportDate to now")
    func documentInit() {
        let session = TestHelpers.makeSampleSession()
        let before = Date()
        let document = NZTDocument(session: session)
        let after = Date()

        #expect(document.session.sensorTracks.count == session.sensorTracks.count)
        #expect(document.exportDate >= before)
        #expect(document.exportDate <= after)
    }

    @Test("Wire format encode/decode preserves track structure")
    func wireFormatEncodeDecode() throws {
        let session = TestHelpers.makeSampleSession()
        let wire = NZTWireFormat(
            sensorTracks: session.sensorTracks,
            exportDate: Date()
        )

        let encoded = try JSONEncoder().encode(wire)
        let decoded = try JSONDecoder().decode(NZTWireFormat.self, from: encoded)

        #expect(decoded.sensorTracks.count == session.sensorTracks.count)
        #expect(decoded.sensorTracks[0].positions.count == session.sensorTracks[0].positions.count)
        #expect(decoded.sensorTracks[1].positions.count == session.sensorTracks[1].positions.count)
    }

    @Test("Wire format round-trip preserves coordinates and timestamps")
    func wireFormatRoundTrip() throws {
        let session = TestHelpers.makeSampleSession()
        let wire = NZTWireFormat(
            sensorTracks: session.sensorTracks,
            exportDate: Date()
        )

        let encoded = try JSONEncoder().encode(wire)
        let decoded = try JSONDecoder().decode(NZTWireFormat.self, from: encoded)
        let restored = Session(sensorTracks: decoded.sensorTracks)

        let originalTimeline = session.buildTimeline()
        let restoredTimeline = restored.buildTimeline()

        #expect(originalTimeline.count == restoredTimeline.count)

        for (orig, rest) in zip(originalTimeline, restoredTimeline) {
            #expect(orig.id == rest.id)
            #expect(orig.x == rest.x)
            #expect(orig.y == rest.y)
            #expect(orig.timestamp == rest.timestamp)
        }
    }

    @Test("Decoding invalid JSON throws a DecodingError")
    func decodingInvalidDataThrows() {
        let invalidJSON = Data("not json".utf8)

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(NZTWireFormat.self, from: invalidJSON)
        }
    }
}
