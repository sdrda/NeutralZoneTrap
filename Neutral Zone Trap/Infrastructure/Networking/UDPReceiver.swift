//
//  UDPReceiver.swift
//  Neutral Zone Trap
//

import Foundation
import Network

/// Actor přijímající UDP datagramy na pevně zvoleném portu a distribuující je fan-outem
/// všem registrovaným odběratelům; sdílený napříč okny aplikace.
/// - Note: Konformuje s `PacketReceiver`. UDP listener se spustí líně při prvním volání
///   `startReceiving()` a běží, dokud existuje alespoň jeden odběratel.
actor UDPReceiver: PacketReceiver {
    private let port: NWEndpoint.Port
    private var listenerTask: Task<Void, Never>?

    /// Aktivní odběratelé streamu
    private var subscribers: [UUID: AsyncThrowingStream<Data, Error>.Continuation] = [:]

    /// Vytvoří receiver vázaný na zadaný UDP port.
    /// - Parameter port: Číslo UDP portu (1–65535), na kterém se bude naslouchat.
    /// - Warning: Předává neplatné číslo portu způsobí `preconditionFailure`.
    init(port: UInt16) {
        guard let resolvedPort = NWEndpoint.Port(rawValue: port) else {
            preconditionFailure("Invalid UDP port number: \(port)")
        }
        self.port = resolvedPort
    }

    /// Zaregistruje nového odběratele a vrátí mu stream příchozích UDP datagramů.
    /// Listener se spustí při prvním registrovaném odběrateli.
    /// Pokud port nelze otevřít (např. je již obsazen), stream skončí chybou `NetworkError.portUnavailable`.
    /// Buffer je omezen na 512 nejnovějších paketů; starší pakety jsou při přetečení zahozeny.
    /// - Returns: `AsyncThrowingStream<Data, Error>` doručující kopie každého přijatého datagramu.
    func startReceiving() -> AsyncThrowingStream<Data, Error> {
        let id = UUID()
        
        // Buffering newest at to neroste linearne
        let (stream, continuation) = AsyncThrowingStream.makeStream(
            of: Data.self,
            bufferingPolicy: .bufferingNewest(512)
        )

        // Kdyz odberatelovi skonci stream (okno se zavre / consumer se zrusi),
        // odhlasime ho. Socket bezi dal pro ostatni okna.
        continuation.onTermination = { [weak self] _ in
            Task { await self?.removeSubscriber(id) }
        }

        subscribers[id] = continuation
        startListenerIfNeeded()
        return stream
    }

    /// Ukončí příjem paketů: dokončí streamy všech odběratelů a zruší UDP listener.
    func stopReceiving() {
        for continuation in subscribers.values {
            continuation.finish()
        }
        subscribers.removeAll()
        listenerTask?.cancel()
        listenerTask = nil
    }

    private func removeSubscriber(_ id: UUID) {
        subscribers[id] = nil
    }

    /// Rozešlě paket všem aktuálním odběratelům.
    private func broadcast(_ data: Data) {
        for continuation in subscribers.values {
            continuation.yield(data)
        }
    }

    private func fail(_ error: any Error) {
        let resolved: any Error = UDPReceiver.isAddressInUse(error)
            ? NetworkError.portUnavailable(port: port.rawValue)
            : error
        for continuation in subscribers.values {
            continuation.finish(throwing: resolved)
        }
        subscribers.removeAll()
        listenerTask = nil
    }

    private func clearListener() {
        listenerTask = nil
    }

    private func startListenerIfNeeded() {
        guard listenerTask == nil else { return }
        let port = self.port
        listenerTask = Task { [weak self] in
            do {
                // Inicializuje NetworkListener
                let listener = try NetworkListener(
                    using: .parameters {
                        UDP()
                    }.localPort(port)
                )

                // Spusti NetworkListener a fan-outuje prichozi pakety.
                try await listener.run { [weak self] connection in
                    for try await (data, _) in connection.messages {
                        await self?.broadcast(data)
                    }
                }

                await self?.clearListener()
            } catch is CancellationError {
                await self?.clearListener()
            } catch {
                await self?.fail(error)
            }
        }
    }

    // Rozpozna "address already in use"
    private static func isAddressInUse(_ error: any Error) -> Bool {
        if let nwError = error as? NWError, case .posix(.EADDRINUSE) = nwError {
            return true
        }
        if let posixError = error as? POSIXError, posixError.code == .EADDRINUSE {
            return true
        }
        let nsError = error as NSError
        return nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(EADDRINUSE)
    }

    deinit {
        for continuation in subscribers.values {
            continuation.finish()
        }
        listenerTask?.cancel()
    }
}
