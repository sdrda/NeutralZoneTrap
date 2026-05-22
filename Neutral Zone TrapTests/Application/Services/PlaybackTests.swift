//
//  PlaybackTests.swift
//  Neutral Zone TrapTests
//

import Testing
import Foundation
@testable import Neutral_Zone_Trap

@Suite(.tags(.playback))
@MainActor
struct PlaybackTests {

    private typealias Context = (
        service: Playback,
        statistics: Statistics,
        store: SensorPositionStore,
        recorder: Recorder
    )

    private func makeService() -> Context {
        let statistics = Statistics()
        let store = SensorPositionStore()
        let recorder = Recorder()
        let service = Playback(statistics: statistics, store: store, snapshotProvider: recorder)
        return (service, statistics, store, recorder)
    }

    /// Naseeduje `session` do recorderu (zdroj snapshotu pro playback) a~načte
    /// ji do služby, čímž testy startují z~deterministického stavu „načteno,
    /// kurzor na začátku, nehraje".
    ///
    /// `Playback.load()` nechává přehrávání zastavené — emit rozjíždí až
    /// ``RinkView`` samostatným voláním `play()` po `load()`. Není tu tedy co
    /// pozastavovat; samotný kontrakt „load nerozjede playback" pokrývá test
    /// ``loadDoesNotAutoStartPlayback``.
    private func loadSession(_ session: Session, into ctx: Context) async {
        await ctx.recorder.load(session)
        try? await ctx.service.load()
    }

    @Test("Initial state: not playing, no time range, progress 0")
    func initialState() {
        let ctx = makeService()

        #expect(ctx.service.isPlaying == false)
        #expect(ctx.service.timeRange == nil)
        #expect(ctx.service.progress == 0)
    }

    @Test("load() picks up timeRange from the session")
    func loadSetsTimeRange() async throws {
        let ctx = makeService()

        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        // timeRange je odvozeno z načtené session, nezávisle na stavu přehrávání.
        let range = try #require(ctx.service.timeRange)
        #expect(range.lowerBound == Date(timeIntervalSince1970: 1000))
        #expect(range.upperBound == Date(timeIntervalSince1970: 1002))
    }

    @Test("load() resets currentTime to session start")
    func loadResetsCurrentTime() async {
        let ctx = makeService()

        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        #expect(ctx.service.currentTime == Date(timeIntervalSince1970: 1000))
    }

    @Test("load() leaves playback stopped; RinkView drives play() separately")
    func loadDoesNotAutoStartPlayback() async throws {
        let ctx = makeService()
        await ctx.recorder.load(TestHelpers.makeSampleSession())

        try await ctx.service.load()

        #expect(ctx.service.isPlaying == false)
    }

    @Test("load() throws noRecordedData when the recorder snapshot is empty")
    func loadThrowsForEmptySession() async {
        let ctx = makeService()
        // Recorder se neseeduje, takže jeho snapshot je prázdná session.

        await #expect(throws: SessionError.self) {
            try await ctx.service.load()
        }
        #expect(ctx.service.isPlaying == false)
        #expect(ctx.service.timeRange == nil)
    }

    @Test("Setting progress to 0.5 moves currentTime to midpoint")
    func setProgressUpdatesTime() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        ctx.service.progress = 0.5

        // Session má rozsah 2 sekundy (1000...1002), takže 50% = t=1001
        #expect(ctx.service.currentTime == Date(timeIntervalSince1970: 1001))
    }

    /// `play()` překlopí `isPlaying` jen když je nahraná session; na prázdné
    /// službě musí být no-op.
    @Test(
        "play() respects the session-loaded precondition",
        arguments: [
            (preloaded: false, expectedIsPlaying: false),
            (preloaded: true,  expectedIsPlaying: true),
        ]
    )
    func playRespectsSessionState(preloaded: Bool, expectedIsPlaying: Bool) async {
        let ctx = makeService()
        if preloaded { await loadSession(TestHelpers.makeSampleSession(), into: ctx) }

        ctx.service.play()

        #expect(ctx.service.isPlaying == expectedIsPlaying)
    }

    @Test("pause() sets isPlaying to false")
    func pauseStopsPlayback() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)
        ctx.service.play()

        ctx.service.pause()

        #expect(ctx.service.isPlaying == false)
    }

    @Test("reset() cancels emit and rewinds the cursor to the start")
    func resetRewindsToBeginning() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)
        ctx.service.play()

        ctx.service.reset()

        #expect(ctx.service.isPlaying == false)
        #expect(ctx.service.currentTime == Date(timeIntervalSince1970: 1000))
    }

    @Test("seek() ingests snapshot positions for all sensors at that time")
    func seekIngestsSnapshot() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        let seekTime = Date(timeIntervalSince1970: 1001)
        ctx.service.seek(to: seekTime)

        // Snapshot v t=1001 by měl naplnit inspector store oběma senzory.
        #expect(ctx.statistics.activeIDs.count == 2)
        #expect(ctx.service.currentTime == seekTime)
    }

    @Test("seek() while playing resumes playback from new position")
    func seekWhilePlayingResumesPlayback() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)
        ctx.service.play()

        ctx.service.seek(to: Date(timeIntervalSince1970: 1001))

        #expect(ctx.service.isPlaying == true)
    }

    @Test("seek() while paused stays paused")
    func seekWhilePausedStaysPaused() async {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        ctx.service.seek(to: Date(timeIntervalSince1970: 1001))

        #expect(ctx.service.isPlaying == false)
    }

    @Test("seek() replaces the position store with a snapshot at that time")
    func seekReplacesPositionStore() async throws {
        let ctx = makeService()
        await loadSession(TestHelpers.makeSampleSession(), into: ctx)

        ctx.service.seek(to: Date(timeIntervalSince1970: 1001))

        // Seek naplánuje asynchronní update store; krátce polluj.
        let deadline = Date().addingTimeInterval(1.0)
        var snapshot: [SensorHardwareID: SensorPosition] = [:]
        while snapshot.isEmpty, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await ctx.store.snapshot()
        }

        // Vzorová session má v t=1001 viditelné dva senzory.
        #expect(snapshot.count == 2)
    }

    // MARK: - Časový engine

    @Test("play emits all timeline positions to the position store in order")
    func playEmitsAllPositions() async throws {
        let ctx = makeService()

        // Postav minimální session: dvě časově označkované pozice ~30 ms od
        // sebe, aby playback task mohl rychle proběhnout bez křehkého
        // pollování. Reálné playback používá ContinuousClock pro reálný čas,
        // čekání jsou ohraničena timeline.
        let baseTime = Date(timeIntervalSince1970: 5000)
        var source = Session()
        source.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        source.addPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 1, y: 1,
            timestamp: baseTime.addingTimeInterval(0.03)
        ))
        source.addPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 2, y: 2,
            timestamp: baseTime.addingTimeInterval(0.06)
        ))
        await loadSession(source, into: ctx)

        ctx.service.play()
        #expect(ctx.service.isPlaying == true)

        // Počkej, až engine dokončí; celkový wall-time by měl být ~60 ms.
        let deadline = Date().addingTimeInterval(2.0)
        while ctx.service.isPlaying, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(ctx.service.isPlaying == false)
        let snapshot = await ctx.store.snapshot()
        #expect(snapshot[1]?.x == 2)
        #expect(snapshot[1]?.y == 2)
        #expect(ctx.service.currentTime == baseTime.addingTimeInterval(0.06))
    }

    @Test("play writes each emitted position into the position store")
    func playPushesPositionsToStore() async throws {
        let ctx = makeService()
        let baseTime = Date(timeIntervalSince1970: 9000)
        var source = Session()
        source.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        source.addPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 1, y: 1,
            timestamp: baseTime.addingTimeInterval(0.03)
        ))
        await loadSession(source, into: ctx)

        ctx.service.play()

        let deadline = Date().addingTimeInterval(2.0)
        var snapshot: [SensorHardwareID: SensorPosition] = [:]
        while snapshot[1]?.x != 1, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
            snapshot = await ctx.store.snapshot()
        }

        #expect(snapshot[1]?.x == 1)
        #expect(snapshot[1]?.y == 1)
    }

    @Test("play stops cleanly when reaching the end of the timeline")
    func playClearsIsPlayingAtEndOfTimeline() async throws {
        let ctx = makeService()
        let baseTime = Date(timeIntervalSince1970: 7000)
        var source = Session()
        source.addPosition(TestHelpers.makeSensorPosition(id: 1, x: 0, y: 0, timestamp: baseTime))
        source.addPosition(TestHelpers.makeSensorPosition(
            id: 1, x: 1, y: 1,
            timestamp: baseTime.addingTimeInterval(0.02)
        ))
        await loadSession(source, into: ctx)

        ctx.service.play()

        let deadline = Date().addingTimeInterval(2.0)
        while ctx.service.isPlaying, Date() < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(ctx.service.isPlaying == false)
    }
}
