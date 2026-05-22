//
//  RinkView.swift
//  Neutral Zone Trap
//

import SwiftUI

/// Hlavní obrazovka hřiště
struct RinkView: View {
    @Environment(ErrorRouter.self) private var errorRouter

    @State private var modeStore: AppModeState
    @State private var recorder: Recorder
    @State private var playback: Playback
    @State private var fileManager: SessionFileManager
    @State private var statistics: Statistics
    @State private var groupSelection: GroupSelection
    @State private var overlayState: RinkOverlayState
    @State private var cameraState: RinkCameraState
    @State private var positionStore: SensorPositionStore
    @State private var benchmarkLogger: BenchmarkLogger?

    @State private var streamProcessor: SensorStreamProcessor

    @State private var inspectorPresented = false
    @State private var isDropTargeted = false

    // Receiver prichazi z environmentu (vlastni ho App, viz Neutral_Zone_TrapApp).
    // Fallback na cerstvou instanci je jen pojistka pro previews/testy, kde
    // environment neni nastaveny; v bezici aplikaci se nikdy neuplatni.
    init(receiver: (any PacketReceiver)?) {
        let positionStore = SensorPositionStore()
        let statistics = Statistics()
        let recorder = Recorder()
        let benchmarkLogger = BenchmarkLogger.makeIfEnabled()
        let streamProcessor = SensorStreamProcessor(
            receiver: receiver ?? UDPReceiver(port: AppConfig.udpPort),
            store: positionStore,
            recorder: recorder,
            statistics: statistics,
            benchmarkLogger: benchmarkLogger
        )
        let playback = Playback(statistics: statistics, store: positionStore, snapshotProvider: recorder)
        let fileManager = SessionFileManager(recorder: recorder)

        _positionStore = State(initialValue: positionStore)
        _modeStore = State(initialValue: AppModeState())
        _statistics = State(initialValue: statistics)
        _recorder = State(initialValue: recorder)
        _playback = State(initialValue: playback)
        _fileManager = State(initialValue: fileManager)
        _groupSelection = State(initialValue: GroupSelection())
        _overlayState = State(initialValue: RinkOverlayState())
        _cameraState = State(initialValue: RinkCameraState())
        _benchmarkLogger = State(initialValue: benchmarkLogger)
        _streamProcessor = State(initialValue: streamProcessor)
    }

    // Computed hodnota toho, zda muzeme importovat session
    private var canAcceptDroppedSession: Bool {
        modeStore.mode == .live
    }

    var body: some View {
        @Bindable var fileManager = fileManager

        return NavigationStack {
            ZStack {
                RealityRinkView()

                // Mode indicator nahore, mirne odsazenej
                VStack {
                    ModeIndicator(mode: modeStore.mode)
                        .padding(.top, 16)
                    Spacer()
                }

                if modeStore.mode == .playback {
                    VStack {
                        Spacer()
                        HStack {
                            RinkControlPanel()
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
            .toolbar {
                RinkViewToolbar(inspectorPresented: $inspectorPresented)
            }
            
            // Overlay pro vyznaceni drag&drop
            .overlay {
                if isDropTargeted && canAcceptDroppedSession {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.accentColor, lineWidth: 4)
                        .background(Color.accentColor.opacity(0.08))
                        .allowsHitTesting(false)
                        .padding(4)
                }
            }

            // Indikátor průběhu importu. iCloud soubor může být jen
            // placeholder a~jeho stažení trvá — bez tohohle by čekání
            // vypadalo jako nicnedělání a~chyba/úspěch by přišly „odnikud".
            .overlay {
                if fileManager.isLoadingImport {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        ProgressView("Loading session…")
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity)
                }
            }
            .animation(.default, value: fileManager.isLoadingImport)
            
            // Drop destination pro drag&drop
            .dropDestination(for: URL.self) { urls, _ in
                guard canAcceptDroppedSession,
                      let url = urls.first,
                      url.pathExtension.lowercased() == "nzt" else {
                    return false
                }
                Task {
                    do {
                        try await fileManager.importSession(from: .success(url))
                        modeStore.mode = .playback
                    } catch {
                        errorRouter.report(error)
                    }
                }
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted && canAcceptDroppedSession
            }
        }

        // Modifiers pro export a import
        .fileExporter(
            isPresented: $fileManager.isExporting,
            document: fileManager.exportDocument,
            contentType: .nztSession,
            defaultFilename: "session"
        ) { result in
            switch result {
            case .success:
                fileManager.markSessionSaved()
            case .failure(let error):
                errorRouter.report(error)
            }
        }
        .fileImporter(
            isPresented: $fileManager.isImporting,
            allowedContentTypes: [.nztSession]
        ) { result in
            Task {
                do {
                    try await fileManager.importSession(from: result)
                    modeStore.mode = .playback
                } catch {
                    errorRouter.report(error)
                }
            }
        }
        .confirmationDialog(
            "Discard Recording?",
            isPresented: $fileManager.showDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                modeStore.mode = .live
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This recording has not been exported. If you leave now, it will be lost.")
        }

        // Focused values pro ovladani pres commands
        .focusedSceneValue(\.modeStore, modeStore)
        .focusedSceneValue(\.inspectorPresentedBinding, $inspectorPresented)
        .focusedSceneValue(\.fileManager, fileManager)
        .focusedSceneValue(\.recorder, recorder)

        // Rizeni stavu v tasku pro async context
        .task(id: modeStore.mode) {
            switch modeStore.mode {
            case .live:
                playback.reset()
                statistics.reset()
                fileManager.resetFileState()
                await recorder.reset()
                await positionStore.reset()
                await streamProcessor.start()
            case .recording:
                await recorder.startRecording()
            case .playback:
                await streamProcessor.stop()
                await recorder.stopRecording()
                await positionStore.reset()
                
                do {
                    try await playback.load()
                } catch {
                    errorRouter.report(error)
                }
                
                playback.play()
            }
        }

        // Uzivatelsky relevantni chyby live pipeline (napr. obsazeny port) → alert.
        .task {
            for await error in await streamProcessor.errors() {
                errorRouter.report(error)
            }
        }

        // Bocni panel
        .inspector(isPresented: $inspectorPresented) {
            PlayersInspector()
                .inspectorColumnWidth(min: 250, ideal: 300, max: 400)
        }

        // Env injection scoped jen na rink podstrom, jinde nepotrebujeme.
        .environment(modeStore)
        .environment(playback)
        .environment(fileManager)
        .environment(statistics)
        .environment(groupSelection)
        .environment(overlayState)
        .environment(cameraState)
        .environment(\.recorder, recorder)
        .environment(\.sensorPositionStore, positionStore)
        .environment(\.benchmarkLogger, benchmarkLogger)
    }
}
