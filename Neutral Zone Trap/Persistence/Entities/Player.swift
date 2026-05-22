//
//  Player.swift
//  Neutral Zone Trap
//

import SwiftData
import Foundation

/// SwiftData entita reprezentující hokejového hráče uloženého v perzistentním úložišti.
@Model
class Player {
    #Index<Player>([\.name])

    /// Unikátní identifikátor záznamu generovaný automaticky při vytvoření.
    var id = UUID()
    /// Celé jméno hráče indexované pro rychlé vyhledávání.
    var name: String = ""
    /// Číslo dresu hráče (nezáporné celé číslo).
    var jerseyNumber: Int = 0

    /// Skupiny, do nichž hráč patří; inverzní strana vazby `PlayerGroup.players`.
    /// Při smazání hráče se reference ve skupinách nastaví na `nil` (nullify).
    @Relationship(deleteRule: .nullify, inverse: \PlayerGroup.players)
    var groups: [PlayerGroup]?

    /// Senzory přiřazené tomuto hráči; inverzní strana vazby `Sensor.player`.
    /// Při smazání hráče se přiřazení senzorů zruší (nullify), senzory zůstanou.
    @Relationship(deleteRule: .nullify, inverse: \Sensor.player)
    var sensors: [Sensor]?

    /// Vytvoří nového hráče se zadaným jménem a číslem dresu.
    /// - Parameters:
    ///   - name: Celé jméno hráče.
    ///   - jerseyNumber: Číslo dresu hráče.
    init(name: String, jerseyNumber: Int) {
        self.name = name
        self.jerseyNumber = jerseyNumber
    }
}
