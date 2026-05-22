//
//  RinkOverlayState.swift
//  Neutral Zone Trap
//

import Foundation
import CoreGraphics

/// Top-level požadavek na overlay s vlastní identitou, aby se opakované
/// publikování stejných bodů (např. dvojklik na "Heatmap") projevilo
/// jako oddělená mutace.
struct RinkOverlay: Equatable, Identifiable {
    let id: UUID
    let points: [CGPoint]

    init(points: [CGPoint]) {
        self.id = UUID()
        self.points = points
    }
}

/// Observable vlastník stavu analytických overlay nad hřištěm.
///
/// Producenti (např. player inspector view) přiřadí nový overlay; rink view
/// pozoruje změnu, aplikuje texturu a po jejím nasazení hodnotu vyčistí.
@Observable
final class RinkOverlayState {

    /// Heatmapa čekající na vykreslení. `nil` poté, co ji rink view aplikoval.
    var heatmap: RinkOverlay?

    /// Movement trail čekající na vykreslení. `nil` po aplikaci.
    var movement: RinkOverlay?

    /// Token nesoucí požadavek na smazání overlayů a obnovu podkladového
    /// obrazu hřiště. Pokaždé jiná hodnota, aby se opakovaný stisk gumy
    /// projevil i když předchozí požadavek ještě nebyl zkonzumovaný.
    /// `nil` poté, co ji rink view aplikoval.
    private(set) var clearRequest: UUID?

    /// Nahradí heatmap overlay zadanými body. No-op, když caller předá
    /// prázdné pole — prázdná heatmapa nemá renderovací smysl, takže
    /// předchozí overlay (nebo nil) zůstává.
    func setHeatmap(points: [CGPoint]) {
        guard !points.isEmpty else { return }
        heatmap = RinkOverlay(points: points)
    }

    /// Nahradí movement trail overlay zadanými body. No-op pro prázdné
    /// pole; viz ``setHeatmap(points:)`` ohledně zdůvodnění.
    func setMovement(points: [CGPoint]) {
        guard !points.isEmpty else { return }
        movement = RinkOverlay(points: points)
    }

    /// Označí heatmapu jako zkonzumovanou.
    func clearHeatmap() {
        heatmap = nil
    }

    /// Označí movement trail jako zkonzumovaný.
    func clearMovement() {
        movement = nil
    }

    /// Požádá rink view, aby smazal vykreslenou heatmapu nebo movement
    /// trail a vrátil texturu hřiště do podkladového stavu.
    func requestClear() {
        clearRequest = UUID()
    }

    /// Označí požadavek na smazání overlayů jako zkonzumovaný.
    func consumeClearRequest() {
        clearRequest = nil
    }
}
