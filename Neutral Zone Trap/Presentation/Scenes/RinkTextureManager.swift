//
//  RinkTextureManager.swift
//  Neutral Zone Trap
//

import Foundation
import CoreGraphics
import RealityKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Nahrazuje texturu materiálu hřiště vykresleným heatmapou nebo movement
/// overlay. MainActor-izolovaný projektovým defaultem, protože podkladový
/// `TextureResource` je vázán na RealityKit scénu na hlavním vlákně.
final class RinkTextureManager {
    var textureResource: TextureResource?

    private let config: any RinkConfiguration
    private let heatmapRenderer: HeatmapRenderer
    private let movementRenderer: MovementRenderer

    init(config: any RinkConfiguration) {
        self.config = config
        self.heatmapRenderer = HeatmapRenderer(config: config)
        self.movementRenderer = MovementRenderer(config: config)
    }

    /// Vyrenderuje heatmapu na concurrent poolu a swapne výsledek
    /// do textury hřiště. No-op, když renderer vrátí nil.
    func setHeatmapTexture(from points: [CGPoint]) async {
        let finalImage = await heatmapRenderer.render(points: points)
        guard let finalImage else { return }

        if let texture = textureResource {
            try? texture.replace(
                withImage: finalImage,
                options: .init(semantic: .color)
            )
        }
    }

    /// Vyrenderuje movement trajektorii na concurrent poolu a swapne
    /// výsledek do textury hřiště. No-op, když renderer vrátí nil.
    func setMovementTexture(from points: [CGPoint]) async {
        let finalImage = await movementRenderer.renderConcurrent(points: points)
        guard let finalImage else { return }

        if let texture = textureResource {
            try? texture.replace(
                withImage: finalImage,
                options: .init(semantic: .color)
            )
        }
    }

    /// Swapne texturu zpátky na podkladový obraz hřiště, čímž odstraní
    /// vykreslenou heatmapu nebo movement trail.
    func restoreBase(_ baseImage: CGImage) {
        guard let texture = textureResource else { return }
        try? texture.replace(
            withImage: baseImage,
            options: .init(semantic: .color)
        )
    }
}
