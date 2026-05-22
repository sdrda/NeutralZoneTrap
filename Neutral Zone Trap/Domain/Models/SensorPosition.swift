//
//  SensorPosition.swift
//  Neutral Zone Trap
//

import Foundation

/// Jeden naměřený vzorek polohy senzoru v daném okamžiku.
nonisolated struct SensorPosition: Identifiable, Codable, Equatable, Sendable {
    /// Identifikátor senzoru, jemuž vzorek patří (slouží i jako `Identifiable.id`).
    let id: SensorHardwareID
    /// Vodorovná souřadnice polohy na hřišti v metrech.
    let x: CGFloat
    /// Svislá souřadnice polohy na hřišti v metrech.
    let y: CGFloat
    /// Okamžik, ke kterému poloha náleží (slouží k řazení a přehrávání).
    let timestamp: Date
}
