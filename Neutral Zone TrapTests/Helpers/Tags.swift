//
//  Tags.swift
//  Neutral Zone TrapTests
//

import Testing

extension Tag {
    // Parsovani binarnich paketu.
    @Tag static var parsing: Self

    // Vzdalenost rychlost a dalsi prostorove metriky.
    @Tag static var metrics: Self

    // Typy datoveho modelu.
    @Tag static var model: Self

    // JSON kodovani dekodovani a serializace souboru.
    @Tag static var serialization: Self

    // Chybove typy.
    @Tag static var errors: Self

    // Prehravani session.
    @Tag static var playback: Self

    // Nahravani session.
    @Tag static var recording: Self

    // Sitova vrstva a zpracovani UDP dat.
    @Tag static var networking: Self

    // Stav Observable sluzeb a storu.
    @Tag static var observation: Self

    // Import a export souboru session.
    @Tag static var fileManager: Self

    // Integrace napric vice castmi aplikace.
    @Tag static var integration: Self
}
