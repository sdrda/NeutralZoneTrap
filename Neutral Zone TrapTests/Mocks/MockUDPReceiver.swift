//
//  MockUDPReceiver.swift
//  Neutral Zone TrapTests
//

import Foundation
@testable import Neutral_Zone_Trap

actor MockUDPReceiver: PacketReceiver {
    private var packets: [Data] = []
    private(set) var isReceiving = false

    func setPackets(_ packets: [Data]) {
        self.packets = packets
    }

    func startReceiving() -> AsyncThrowingStream<Data, Error> {
        isReceiving = true
        let packets = self.packets
        return AsyncThrowingStream { continuation in
            for packet in packets {
                continuation.yield(packet)
            }
            continuation.finish()
        }
    }

    func stopReceiving() {
        isReceiving = false
    }
}
