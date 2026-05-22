//
//  RinkCameraState.swift
//  Neutral Zone Trap
//

import Foundation
import Observation

/// Observable nastavení kamery pohledu na hřiště.
@Observable
final class RinkCameraState {

    /// 3D perspektivní kamera vs. ortografická kamera shora.
    /// Toggluje se z toolbaru; `RealityRinkView` ji čte, aby vyměnil
    /// kamera komponenty na entitě.
    var is3D = true

    /// Zoom faktor aplikovaný na ortografickou kameru, gesture handler ho
    /// clampuje zhruba na `[0.05, 2.0]`. Ignorováno, když `is3D == true`.
    var orthoScale: Float = 0.5
}
