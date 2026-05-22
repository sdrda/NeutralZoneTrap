//
//  Logger+App.swift
//  Neutral Zone Trap
//

import os

/// Rozšíření `Logger` o tovární metodu pro jednotné kategorizované logování v aplikaci.
extension Logger {
    nonisolated private static let subsystem = "com.nzt.app"

    /// Vytvoří `Logger` se subsystémem `com.nzt.app` a zadanou kategorií.
    /// - Parameter category: Řetězec kategorie zobrazovaný v Instruments a Console.app.
    /// - Returns: Nakonfigurovaná instance `Logger`.
    nonisolated static func app(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
