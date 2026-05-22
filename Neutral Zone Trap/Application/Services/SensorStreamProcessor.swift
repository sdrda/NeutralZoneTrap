//
//  SensorStreamProcessor.swift
//  Neutral Zone Trap
//

import Foundation
import os

private nonisolated let logger = Logger.app(category: "SensorStreamProcessor")

/// Aktor tvořící jádro datové pipeline: konzumuje pakety z `PacketReceiver`, parsuje je na validní pozice senzorů a distribuuje je do úložiště, recorderu a statistik.
actor SensorStreamProcessor: StreamProcessing {
    /// Zdroj příchozích UDP paketů; sdílený napříč okny a vlastněný App.
    private let receiver: any PacketReceiver
    /// Cíl pro zápis poslední pozice každého senzoru.
    private let store: any PositionStoreWriting
    /// Recorder zaznamenávající pozice do nahrávané session.
    private let recorder: any PositionRecording
    /// Služba statistik počítající rychlosti a vzdálenosti.
    private let statistics: any StatisticsIngest
    /// Volitelný logger latencí pro měření výkonu pipeline.
    private let benchmarkLogger: BenchmarkLogger?

    /// Běžící consumer task odebírající a zpracovávající stream paketů.
    private var consumeTask: Task<Void, Never>?

    /// Continuation streamu uživatelsky relevantních chyb pipeline (např. obsazený UDP port).
    private var errorContinuation: AsyncStream<NetworkError>.Continuation?

    /// Vytvoří procesor s injektovanými závislostmi pipeline.
    /// - Parameters:
    ///   - receiver: Zdroj příchozích paketů.
    ///   - store: Úložiště poslední pozice senzorů.
    ///   - recorder: Recorder pro zápis pozic do session.
    ///   - statistics: Služba pro průběžný výpočet statistik.
    ///   - benchmarkLogger: Volitelný logger latencí; výchozí `nil` (měření vypnuto).
    init(
        receiver: any PacketReceiver,
        store: any PositionStoreWriting,
        recorder: any PositionRecording,
        statistics: any StatisticsIngest,
        benchmarkLogger: BenchmarkLogger? = nil
    ) {
        self.receiver = receiver
        self.store = store
        self.recorder = recorder
        self.statistics = statistics
        self.benchmarkLogger = benchmarkLogger
    }

    /// Spustí consumer task, který odebírá stream z receiveru, parsuje pakety a distribuuje pozice; opakované volání za běhu je bez efektu.
    func start() {
        guard consumeTask == nil else { return }
        consumeTask = Task { [weak self] in
            // Odber drzi jen receiver (sdileny napric okny)
            guard let stream = await self?.subscribe() else { return }
            do {
                for try await data in stream {
                    // Pro benchmark
                    let receivedAt = Date.now

                    // Parsovani paketu na pozici
                    guard let position = PositionParser.transformToPlayerPosition(from: data) else {
                        continue
                    }

                    guard let self else { break }
                    await self.distribute(position, receivedAt: receivedAt)
                }
            } catch is CancellationError {
                // Ocekavame behem ukonceni.
            } catch let error as NetworkError {
                logger.error("Sensor stream failed: \(error.localizedDescription)")
                await self?.report(error)
            } catch {
                // Zalogovani chyby
                logger.error("Sensor stream failed: \(error.localizedDescription)")
            }
        }
    }

    /// Zruší pouze tento odběr; sdílený receiver běží dál pro ostatní okna a zrušený consumer task se z něj odhlásí sám.
    func stop() {
        consumeTask?.cancel()
        consumeTask = nil
    }

    /// Připojí se k receiveru a vrátí stream paketů; vyčleněno do vlastní metody, aby si self držela jen po dobu navázání odběru, ne po celou konzumaci.
    private func subscribe() async -> AsyncThrowingStream<Data, Error> {
        await receiver.startReceiving()
    }

    /// Propaguje chybu pipeline do streamu chyb, pokud někdo odebírá.
    private func report(_ error: NetworkError) {
        errorContinuation?.yield(error)
    }

    /// Vrátí stream uživatelsky relevantních chyb pipeline k odběru z UI.
    /// - Returns: `AsyncStream` chyb typu `NetworkError`.
    /// - Note: Uchovává se jen poslední continuation; opakované volání předchozí odběr nahradí.
    func errors() -> AsyncStream<NetworkError> {
        let (stream, continuation) = AsyncStream.makeStream(of: NetworkError.self)
        errorContinuation = continuation
        return stream
    }

    /// Rozešle pozici cílům pipeline: volitelně zaznamená latenci pro benchmark, zapíše do úložiště a recorderu a vloží do statistik. Statistics jsou observable pro view, proto jejich ingest běží na `MainActor`.
    /// - Parameters:
    ///   - position: Naparsovaná pozice senzoru k distribuci.
    ///   - receivedAt: Wall-clock čas přijetí paketu, použitý pro měření latence.
    private func distribute(_ position: SensorPosition, receivedAt: Date) async {
        // V pripade zapnuteho benchmarku
        await benchmarkLogger?.recordReceived(id: position.id, sentAt: position.timestamp, receivedAt: receivedAt)

        // Update pozic ve storu
        await store.update(position)

        // Zapsani do recorderu
        await recorder.append(position)

        // Statistics je observable pro view, hop musi probehnout na MainActoru.
        Task { @MainActor [statistics] in
            statistics.insertPosition(position)
        }
    }

    /// Zruší consumer task při uvolnění procesoru (zavření okna), čímž ukončí jeho stream a odhlásí odběr ze sdíleného receiveru.
    deinit {
        consumeTask?.cancel()
    }
}
