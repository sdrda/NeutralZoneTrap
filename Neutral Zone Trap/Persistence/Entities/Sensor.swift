//
//  Sensor.swift
//  Neutral Zone Trap
//

import SwiftData
import Foundation

/// SwiftData entita reprezentující fyzický UWB senzor přiřaditelný konkrétnímu hráči.
@Model
class Sensor: Identifiable {
    #Index<Sensor>([\.hardwareId])

    /// Unikátní identifikátor záznamu generovaný automaticky při vytvoření.
    var id: UUID = UUID()
    /// Hardwarový identifikátor senzoru jako 64bitové celé číslo indexované pro rychlé vyhledávání.
    /// Odpovídá hodnotě přenášené v UDP datagramech ze senzorové sítě.
    var hardwareId: UInt64 = 0

    /// Hráč, jemuž je senzor aktuálně přiřazen; inverzní strana vazby `Player.sensors`.
    /// Hodnota `nil` znamená, že senzor není přiřazen žádnému hráči.
    @Relationship
    var player: Player?

    /// Vytvoří nový záznam senzoru se zadaným hardwarovým identifikátorem.
    /// - Parameters:
    ///   - id: Identifikátor záznamu; výchozí hodnota je nově generované `UUID()`.
    ///   - hardwareId: Hardwarový identifikátor senzoru přenášený v UDP datagramech.
    init(id: UUID = UUID(), hardwareId: UInt64) {
        self.id = id
        self.hardwareId = hardwareId
    }

    /// Typově bezpečná obálka hardwarového identifikátoru jako `SensorHardwareID`.
    var hardwareID: SensorHardwareID {
        SensorHardwareID(hardwareId)
    }
}

