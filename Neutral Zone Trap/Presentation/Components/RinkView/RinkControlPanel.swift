//
//  RinkControlPanel.swift
//  Neutral Zone Trap
//

import SwiftUI

/// Plovoucí ovládací panel zobrazený během playbacku.
struct RinkControlPanel: View {
    @Environment(Playback.self) private var playback
    @Environment(SessionFileManager.self) private var fileManager

    // Aktualni pozice slider
    @State private var scrubValue: Double = 0

    // pravda, kdyz uzivatle tahne za slider
    @State private var isScrubbing = false

    // Zda playback bezel predtim, nez zacal uzivatel tahat slider
    @State private var wasPlayingBeforeScrub = false

    var body: some View {
        HStack(spacing: 12) {
            Button {
                togglePlayback()
            } label: {
                Label(
                    playback.isPlaying ? "Pause" : "Play",
                    systemImage: playback.isPlaying ? "pause.fill" : "play.fill"
                )
            }
            .accessibilityLabel(playback.isPlaying ? "Pause playback" : "Resume playback")

            if let fileName = fileManager.importedFileName {
                Text(fileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Slider(
                value: $scrubValue,
                in: 0...1,
                onEditingChanged: handleScrubChange
            )
            .frame(minWidth: 100)
            .accessibilityLabel("Playback position")
            .accessibilityValue(Text("\(Int(scrubValue * 100)) percent"))

            if let current = playbackCurrentTime {
                Text(formatTime(current))
                    .monospacedDigit()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .onAppear {
            scrubValue = playback.progress
        }
        // Držet pozici slideru v synchronizaci se skutečným playback kurzorem,
        // dokud uživatel *ne*táhne.
        .onChange(of: playback.progress) { _, newProgress in
            if !isScrubbing {
                scrubValue = newProgress
            }
        }
    }

    // MARK: - Playback intenty

    private func togglePlayback() {
        if playback.isPlaying {
            playback.pause()
        } else {
            if playback.progress >= 1.0 {
                playback.progress = 0
            }
            playback.play()
        }
    }

    private func handleScrubChange(_ editing: Bool) {
        if editing {
            isScrubbing = true
            wasPlayingBeforeScrub = playback.isPlaying
            if playback.isPlaying {
                playback.pause()
            }
        } else {
            playback.progress = scrubValue
            isScrubbing = false
            if wasPlayingBeforeScrub, !playback.isPlaying {
                playback.play()
            }
        }
    }

    // Uplynule sekundy od zacatku orehravani
    private var playbackCurrentTime: TimeInterval? {
        guard let range = playback.timeRange else { return nil }
        return playback.currentTime.timeIntervalSince(range.lowerBound)
    }

    // Formatovani casu, casem vytahnout do nejake globalni metody
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
