//
//  PlayerGroup.swift
//  Neutral Zone Trap
//

import SwiftData
import Foundation

/// SwiftData entita reprezentující pojmenovanou skupinu hráčů (např. tým nebo lajnu) s volitelným barevným rozlišením.
@Model
class PlayerGroup {
    #Index<PlayerGroup>([\.name])

    /// Unikátní identifikátor záznamu generovaný automaticky při vytvoření.
    var id = UUID()
    /// Název skupiny indexovaný pro rychlé vyhledávání.
    var name: String = ""
    /// Barva skupiny zakódovaná jako hex řetězec (např. `"#FF5733"`); `nil`, pokud barva není nastavena.
    var colorHex: String?

    /// Hráči přiřazení do této skupiny; inverzní strana vazby `Player.groups`.
    @Relationship
    var players: [Player]?

    /// Vytvoří novou skupinu hráčů se zadaným názvem a volitelnou barvou.
    /// - Parameters:
    ///   - name: Název skupiny.
    ///   - colorHex: Hex řetězec barvy skupiny; výchozí hodnota je `nil`.
    init(name: String, colorHex: String? = nil) {
        self.name = name
        self.colorHex = colorHex
    }
}
