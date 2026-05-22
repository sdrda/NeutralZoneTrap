//
//  RinkViewToolbar.swift
//  Neutral Zone Trap
//

import SwiftUI
import SwiftData

struct RinkViewToolbar: ToolbarContent {
    @Binding var inspectorPresented: Bool
    @Environment(AppModeState.self) private var modeStore
    @Environment(RinkCameraState.self) private var camera
    @Environment(SessionFileManager.self) private var fileManager
    @Environment(GroupSelection.self) private var groupSelection
    @Environment(ErrorRouter.self) private var errorRouter
    @Environment(RinkOverlayState.self) private var overlay
    @Environment(\.recorder) private var recorder
    @Query(sort: \PlayerGroup.name) private var groups: [PlayerGroup]

    var body: some ToolbarContent {
        @Bindable var fileManager = fileManager

        // MARK: - Leading: Ukončit playback

        if modeStore.mode == .playback {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    exitPlayback()
                } label: {
                    Label("Exit", systemImage: "trash")
                }
                .accessibilityLabel("Exit playback")
            }
        }

        // MARK: - Středové položky

        // V `.recording` ani Import ani Export nemá smysl prezentovat —
        // import by přepsal aktivní session, export je gated na playback.
        if modeStore.mode == .playback {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    Task { await fileManager.exportSession() }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .accessibilityLabel("Export session")
            }
        } else if modeStore.mode == .live {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    fileManager.isImporting = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .accessibilityLabel("Import session")
            }
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                if groups.isEmpty {
                    Text("No groups")
                } else {
                    ForEach(groups, id: \.id) { group in
                        Button {
                            toggleGroup(group)
                        } label: {
                            if groupSelection.isActive(group) {
                                Label(group.name, systemImage: "checkmark")
                            } else {
                                Text(group.name)
                            }
                        }
                    }
                }
            } label: {
                Label("Active Groups", systemImage: "person.3")
            }
            .accessibilityLabel("Toggle active player groups")
        }

        ToolbarItem(placement: .secondaryAction) {
            Button {
                overlay.requestClear()
            } label: {
                Label("Clear Overlay", systemImage: "eraser")
            }
            .accessibilityLabel("Clear heatmap and movement overlay")
        }

        ToolbarItem(placement: .secondaryAction) {
            Button {
                camera.is3D.toggle()
            } label: {
                // Text odpovídá CÍLOVÉMU módu (kam tlačítko přepne):
                // ve 3D ukazuje "2D", ve 2D ukazuje "3D".
                Text(camera.is3D ? "2D" : "3D")
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .accessibilityLabel(camera.is3D ? "Switch to 2D view" : "Switch to 3D view")
        }

        // MARK: - Primary: Record / Stop

        // Record button je viditelný v live i recording módu — v live
        // startuje nahrávání, v recording nejdřív zastaví recorder a teprve
        // podle jeho obsahu rozhodne, zda přejít do playbacku.
        if modeStore.mode != .playback {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    switch modeStore.mode {
                    case .live:
                        modeStore.mode = .recording
                    case .recording:
                        modeStore.mode = .playback
                    case .playback:
                        break
                    }
                } label: {
                    Label(
                        modeStore.mode == .recording ? "Stop Recording" : "Record",
                        systemImage: modeStore.mode == .recording ? "stop.fill" : "record.circle"
                    )
                    .symbolRenderingMode(.monochrome)
                    .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(modeStore.mode == .recording ? "Stop recording" : "Start recording")
            }
        }

        // MARK: - Primary: Inspector toggle

        ToolbarItem(placement: .primaryAction) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    inspectorPresented.toggle()
                }
            } label: {
                Label(
                    inspectorPresented ? "Close" : "Player Details",
                    systemImage: inspectorPresented ? "xmark" : "chart.xyaxis.line"
                )
                .symbolRenderingMode(.monochrome)
                .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(inspectorPresented ? "Hide player inspector" : "Show player inspector")
        }
    }
    
    /// Aktivuje skupinu pouze tehdy, když její hráči ještě nepatří
    /// do jiné aktivní skupiny; jinak hlásí přívětivou chybu.
    /// Deaktivace je vždy povolená.
    private func toggleGroup(_ group: PlayerGroup) {
        if groupSelection.isActive(group) {
            groupSelection.toggle(group)
            return
        }
        let conflicts = groupSelection.conflictingPlayerNames(
            activating: group,
            in: groups
        )
        if conflicts.isEmpty {
            groupSelection.toggle(group)
        } else {
            errorRouter.report(GroupSelectionError.conflictingPlayers(conflicts))
        }
    }

    // Ukonci playback a restartuje recorder
    private func exitPlayback() {
        if fileManager.requestExitPlayback() {
            modeStore.mode = .live
        }
    }
}
