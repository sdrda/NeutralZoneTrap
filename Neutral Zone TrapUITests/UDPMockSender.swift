//
//  UDPMockSender.swift
//  Neutral Zone TrapUITests
//
//  Test-side helper that fires UDP position packets at the running app on
//  127.0.0.1:12345. Packet layout matches `PositionParser`:
//
//     offset 0   x           Double LE (8 B)
//     offset 8   y           Double LE (8 B)
//     offset 16  id          Double LE (8 B)
//     offset 24  timestamp   Double LE (8 B)  // seconds since 1970
//

import Foundation
import Network

final class UDPMockSender {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "ui-tests.udp-mock-sender")

    init(host: String = "127.0.0.1", port: UInt16 = 12345) {
        let endpoint = NWEndpoint.Host(host)
        let nwPort = NWEndpoint.Port(rawValue: port)!
        connection = NWConnection(host: endpoint, port: nwPort, using: .udp)
        connection.start(queue: queue)
    }

    /// Posílá paket s uvedenými parametry
    func send(id: Double, x: Double = 0, y: Double = 0) {
        var packet = Data(capacity: 32)
        withUnsafeBytes(of: x) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: y) { packet.append(contentsOf: $0) }
        withUnsafeBytes(of: id) { packet.append(contentsOf: $0) }
        let ts = Date().timeIntervalSince1970
        withUnsafeBytes(of: ts) { packet.append(contentsOf: $0) }

        connection.send(content: packet, completion: .idempotent)
    }

    func close() {
        connection.cancel()
    }
}
