//
//  AppConfig.swift
//  Neutral Zone Trap
//

import Foundation

/// Statická konfigurace aplikace; jmenný prostor pro síťové konstanty.
enum AppConfig {
    
    /// Výchozí UDP port, na kterém aplikace naslouchá datům ze senzorů.
    static let udpPort: UInt16 = 12345
}
