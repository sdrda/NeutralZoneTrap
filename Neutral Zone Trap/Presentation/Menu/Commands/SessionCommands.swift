//
//  SessionCommands.swift
//  Neutral Zone Trap
//

#if !os(tvOS)
import SwiftUI

struct SessionCommands: Commands {
    @FocusedValue(\.modeStore) private var modeStore: AppModeState?
    @FocusedValue(\.fileManager) private var fileManager: SessionFileManager?

    var body: some Commands {
        CommandGroup(after: .importExport) {
            Button("Save Session") {
                guard let fileManager else { return }
                Task { await fileManager.exportSession() }
            }
            .keyboardShortcut("s", modifiers: .command)
            .disabled(modeStore?.mode != .playback)

            Button("Import Session") {
                fileManager?.isImporting = true
            }
            .keyboardShortcut("i", modifiers: [.command])
            // Povoleno jen čistě v live režimu — během recordingu nebo
            // playbacku by import přepsal aktivní data.
            .disabled(modeStore?.mode != .live)
        }
    }
}

#endif
