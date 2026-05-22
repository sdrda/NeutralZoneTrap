//
//  Color+Hex.swift
//  Neutral Zone Trap
//

import SwiftUI

// Pro ukladani barev
extension Color {

    // MARK: - Hex konverze

    /// Vytvoří Color z hex stringu
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }

    /// Vrací #RRGGBB hex string
    func toHexString() -> String {
        let resolved = self.resolve(in: EnvironmentValues())
        let r = Int((resolved.red * 255).rounded())
        let g = Int((resolved.green * 255).rounded())
        let b = Int((resolved.blue * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // MARK: - Paleta skupin

    /// Barevná paleta pro skupiny
    static let groupPalette: [Color] = [
        .red, .orange, .yellow, .green, .mint, .teal,
        .cyan, .blue, .indigo, .purple, .pink, .brown
    ]

    /// Lokalizovaná paleta
    var paletteName: String {
        switch self {
        case .red:    return String(localized: "Red")
        case .orange: return String(localized: "Orange")
        case .yellow: return String(localized: "Yellow")
        case .green:  return String(localized: "Green")
        case .mint:   return String(localized: "Mint")
        case .teal:   return String(localized: "Teal")
        case .cyan:   return String(localized: "Cyan")
        case .blue:   return String(localized: "Blue")
        case .indigo: return String(localized: "Indigo")
        case .purple: return String(localized: "Purple")
        case .pink:   return String(localized: "Pink")
        case .brown:  return String(localized: "Brown")
        default:      return ""
        }
    }
}
