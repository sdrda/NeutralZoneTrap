//
//  AppMode.swift
//  Neutral Zone Trap
//

import Foundation
import Observation

/// Provozní režim aplikace; `Sendable` hodnota sdílená napříč vrstvami.
enum AppMode: Equatable, Sendable {
    /// Živý příjem dat ze senzorů bez ukládání do nahrávky.
    case live
    /// Živý příjem se současným zaznamenáváním pozic do `Session`.
    case recording
    /// Přehrávání dříve nahrané nebo importované `Session`.
    case playback
}

/// Observable držitel aktuálního režimu aplikace; čteno a měněno na `MainActor` skrze SwiftUI.
@Observable
final class AppModeState {

    /// Aktuální režim aplikace; při startu výchozí `.live`.
    // Pri startu defaultne mode
    var mode: AppMode = .live
}
