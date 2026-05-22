//
//  ModeIndicator.swift
//  Neutral Zone Trap
//

import SwiftUI

/// Vizuální badge režimu
struct ModeIndicator: View {
    let mode: AppMode

    var body: some View {
        Text(label)
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
            .accessibilityLabel("Mode: \(String(localized: label))")
    }

    private var label: LocalizedStringResource {
        switch mode {
        case .live: "Live"
        case .recording: "Recording"
        case .playback: "Playback"
        }
    }

    private var color: Color {
        switch mode {
        case .live: .green
        case .recording: .red
        case .playback: .yellow
        }
    }
}
