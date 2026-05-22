//
//  Playback.swift
//  Neutral Zone Trap
//

import Foundation

/// Observable služba pro přehrávání nahrané `Session`: emituje pozice v reálném čase do úložiště a do statistik. Publikovaný stav je čten view, proto je izolovaná na `MainActor`.
@Observable
final class Playback: PlaybackControl {
    /// Služba statistik, do které se během přehrávání vkládají pozice.
    private let statistics: any StatisticsIngest
    /// Úložiště, kam se emitují pozice pro vykreslení scény.
    private let store: any PositionStoreWriting
    /// Zdroj snapshotu session k přehrání (typicky recorder).
    private let snapshotProvider: any SessionSnapshotting

    /// Aktuálně načtená session; výchozí prázdná kvůli computed vlastnostem.
    private var session = Session()
    /// Časově seřazená sekvence všech pozic napříč senzory, po které se přehrává.
    private var timeline: [SensorPosition] = []
    
    /// Běžící task emitující pozice; `nil`, když přehrávání neběží.
    private var playbackTask: Task<Void, Never>?

    /// Zda právě běží přehrávací smyčka.
    private(set) var isPlaying = false

    /// Wall-clock timestamp poslední emitované pozice (poloha kurzoru).
    private(set) var currentTime: Date = .distantPast

    /// Časový rozsah načtené `Session`, nebo `nil`, když je prázdná.
    var timeRange: ClosedRange<Date>? {
        session.timeRange
    }

    /// Vytvoří službu s injektovanými závislostmi pro přehrávání.
    /// - Parameters:
    ///   - statistics: Služba statistik pro vkládání přehrávaných pozic.
    ///   - store: Úložiště pozic pro vykreslení.
    ///   - snapshotProvider: Zdroj snapshotu session k přehrání.
    init(
        statistics: any StatisticsIngest,
        store: any PositionStoreWriting,
        snapshotProvider: any SessionSnapshotting,
    ) {
        self.statistics = statistics
        self.store = store
        self.snapshotProvider = snapshotProvider
    }

    // MARK: - Load

    /// Načte aktuální snapshot ze zdroje, sestaví timeline, resetuje kurzor na začátek a přepočítá agregované statistiky.
    /// - Throws: ``SessionError/noRecordedData``, když je načtená session prázdná.
    func load() async throws {
        let snapshot = await snapshotProvider.snapshot()
        pause()

        self.session = snapshot
        self.timeline = snapshot.buildTimeline()

        currentTime = snapshot.timeRange?.lowerBound ?? .distantPast

        statistics.reset()
        statistics.recomputeAggregates(from: snapshot)
        
        if session.isEmpty() {
            throw SessionError.noRecordedData
        }
    }

    /// Normalizovaný průběh přehrávání v rozsahu 0...1 pro slider; getter mapuje kurzor na podíl, setter provede seek na odpovídající čas. Vrací 0, když je session prázdná nebo nulové délky.
    var progress: Double {
        get {
            guard let range = timeRange else { return 0 }
            let total = range.upperBound.timeIntervalSince(range.lowerBound)
            guard total > 0 else { return 0 }
            return currentTime.timeIntervalSince(range.lowerBound) / total
        }
        set {
            guard let range = timeRange else { return }
            let total = range.upperBound.timeIntervalSince(range.lowerBound)
            let target = range.lowerBound.addingTimeInterval(newValue * total)
            seek(to: target)
        }
    }

    // MARK: - Playback controls

    /// Obnoví přehrávání od aktuálního kurzoru; bez efektu, když je session prázdná nebo přehrávání už běží.
    func play() {
        guard !timeline.isEmpty, !isPlaying else { return }
        isPlaying = true
        startEmitting(from: currentTime)
    }

    /// Pozastaví přehrávání a ponechá kurzor na místě, takže další ``play()`` pokračuje od stejného timestampu.
    func pause() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }

    /// Zastaví běžící přehrávání a vrátí kurzor na začátek session.
    func reset() {
        pause()
        currentTime = timeRange?.lowerBound ?? .distantPast
    }

    /// Posune kurzor na zadaný čas a okamžitě nahradí úložiště snapshotem všech pozic v daném okamžiku, aby se scéna aktualizovala v příštím render framu; pokud služba před seekem hrála, obnoví přehrávání od nového kurzoru.
    /// - Parameter time: Cílový čas, na který se má kurzor přesunout.
    func seek(to time: Date) {
        let wasPlaying = isPlaying
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false

        currentTime = time

        let snapshot = session.snapshot(at: time)
        for position in snapshot.values {
            statistics.insertPosition(position)
        }
        Task { [store] in
            await store.replaceAll(snapshot)
        }

        if wasPlaying {
            isPlaying = true
            startEmitting(from: time)
        }
    }

    // MARK: - Private

    /// Spustí přehrávací smyčku od daného času: pozice dávkuje do přibližně 16 ms (cca 60 FPS) framů podle continuous clock, každou dávku posílá jediným aktorovým přechodem do úložiště a jediným `MainActor` přechodem do statistik a kurzoru. Po přirozeném dojetí timeline kurzor srovná na poslední timestamp a vypne přehrávání.
    /// - Parameter startTime: Čas, od kterého se začnou pozice emitovat.
    private func startEmitting(from startTime: Date) {
        playbackTask?.cancel()

        let timeline = self.timeline

        // Najde prvni pozici v case startTime nebo pozdeji.
        let startIndex = firstTimelineIndex(atOrAfter: startTime, in: timeline)

        playbackTask = Task { [timeline, store, statistics, weak self] in
            let clock = ContinuousClock()
            let playbackStart = clock.now

            // Fixni frame okno pro batchovani, priblizne 60 FPS
            let frameInterval: Duration = .milliseconds(16)

            var index = startIndex
            while index < timeline.endIndex, !Task.isCancelled {
                // Pockame, dokud prvni nedelena pozice v batchi nema nastat.
                let firstPosition = timeline[index]
                let offsetFromStart = firstPosition.timestamp.timeIntervalSince(startTime)
                let elapsed = clock.now - playbackStart
                let waitDuration = Duration.seconds(offsetFromStart) - elapsed

                if waitDuration > .zero {
                    do {
                        try await Task.sleep(for: waitDuration)
                    } catch {
                        return
                    }
                }

                // Priprava batche
                let frameTarget = (clock.now - playbackStart) + frameInterval / 2
                var batch: [SensorPosition] = []
                while index < timeline.endIndex {
                    let p = timeline[index]
                    let pOffset = Duration.seconds(p.timestamp.timeIntervalSince(startTime))
                    if pOffset <= frameTarget {
                        batch.append(p)
                        index += 1
                    } else {
                        break
                    }
                }

                // Jeden actor hop pro cely batch.
                await store.updateMany(batch)

                // Jeden MainActor hop pro statistics ingest + scrubber publish.
                let cursorTimestamp = batch.last?.timestamp
                await MainActor.run {
                    for p in batch {
                        statistics.insertPosition(p)
                    }
                    if let ts = cursorTimestamp {
                        self?.currentTime = ts
                    }
                }
            }

            // Pri prirozenem dobehnuti timeline nastavit kurzor presne na
            // posledni timestamp a vypnuti isPlaying.
            if !Task.isCancelled {
                let finalTimestamp = timeline.last?.timestamp
                await MainActor.run {
                    if let ts = finalTimestamp {
                        self?.currentTime = ts
                    }
                    self?.isPlaying = false
                }
            }
        }
    }

    /// Binárním půlením najde index první pozice v timeline s timestampem >= `time`. O(log n) vůči délce timeline.
    /// - Parameters:
    ///   - time: Hledaný čas.
    ///   - timeline: Časově seřazená sekvence pozic, ve které se hledá.
    /// - Returns: Index první vyhovující pozice, nebo `endIndex`, když žádná nevyhovuje.
    private func firstTimelineIndex(atOrAfter time: Date, in timeline: [SensorPosition]) -> Int {
        var lowerBound = timeline.startIndex
        var upperBound = timeline.endIndex

        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if timeline[middle].timestamp < time {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return lowerBound
    }
}
