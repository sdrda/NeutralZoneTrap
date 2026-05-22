//
//  ColorHexTests.swift
//  Neutral Zone TrapTests
//

import Testing
import SwiftUI
@testable import Neutral_Zone_Trap

@MainActor
@Suite(.tags(.parsing))
struct ColorHexTests {

    @Test("Hex string with leading hash parses to expected components")
    func parsesHashPrefixed() {
        let color = Color(hex: "#FF8000")
        let hex = color.toHexString()

        #expect(hex == "#FF8000")
    }

    @Test("Hex string without leading hash parses to expected components")
    func parsesWithoutPrefix() {
        let color = Color(hex: "00FF00")
        let hex = color.toHexString()

        #expect(hex == "#00FF00")
    }

    @Test("Round trip preserves hex value", arguments: [
        "#000000",
        "#FFFFFF",
        "#7F7F7F",
        "#10AAFF",
        "#A52A2A",
    ])
    func roundTripPreservesValue(hex: String) {
        let result = Color(hex: hex).toHexString()
        #expect(result == hex)
    }

    @Test("paletteName returns a non-empty string for every group palette colour")
    func paletteNameCoverage() {
        for color in Color.groupPalette {
            #expect(color.paletteName.isEmpty == false)
        }
    }
}
