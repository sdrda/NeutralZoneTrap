//
//  SensorHardwareID.swift
//  Neutral Zone Trap
//

import Foundation

/// Typově bezpečný obal nad `UInt64` reprezentující hardwarový identifikátor senzoru.
///
/// Slouží jako klíč ve slovnících pozic a stop, aby z kódu bylo zřejmé,
/// že jde o identitu senzoru, nikoliv o libovolné číslo.
nonisolated struct SensorHardwareID: RawRepresentable, Hashable, Comparable, Codable, Sendable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    /// Porovnává dva identifikátory podle jejich číselné hodnoty.
    static func < (lhs: SensorHardwareID, rhs: SensorHardwareID) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Vytvoří identifikátor z celočíselného literálu (umožňuje zápis `let id: SensorHardwareID = 42`).
    init(integerLiteral value: UInt64) {
        self.rawValue = value
    }

    /// Číselná hodnota identifikátoru senzoru.
    let rawValue: UInt64

    /// Vytvoří identifikátor ze syrové číselné hodnoty (požadavek `RawRepresentable`).
    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Vytvoří identifikátor z dané číselné hodnoty (stručná varianta bez popisku argumentu).
    init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    /// Dekóduje identifikátor z jediné nepojmenované hodnoty (číslo na drátě, nikoliv objekt).
    /// - Throws: Chybu dekodéru, pokud hodnota není dekódovatelná jako `UInt64`.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(UInt64.self)
    }

    /// Zakóduje identifikátor jako jedinou číselnou hodnotu (nikoliv jako objekt s klíčem).
    /// - Throws: Chybu enkodéru při selhání zápisu.
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    /// Textová reprezentace identifikátoru: číselná hodnota jako řetězec.
    var description: String { String(rawValue) }
}
