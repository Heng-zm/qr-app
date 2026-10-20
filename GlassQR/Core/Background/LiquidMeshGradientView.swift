//
//  LiquidMeshGradientView.swift
//  GlassQR
//
//  Calm Obsidian & Slate Ambient Mesh (Apple & ChatGPT Style)
//

import SwiftUI

public struct LiquidMeshGradientView: View {
    public init() {}

    public var body: some View {
        // Ambient cadence: the undulation period is ~10s, so 24fps is visually
        // continuous — while freeing 2.5–5x of the per-frame budget that the
        // display refresh rate was spending on three always-mounted instances
        // (app root, tab container, assistant) for map/camera/scroll work.
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let t = Float(date * 0.45)

            // Calm, slow organic undulating surface
            let p1x = 0.5 + 0.12 * cos(t * 0.5)
            let p1y = 0.5 + 0.12 * sin(t * 0.7)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [p1x, p1y], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.07), // Deep Obsidian
                    Color(red: 0.09, green: 0.09, blue: 0.12), // Charcoal
                    Color(red: 0.04, green: 0.08, blue: 0.14), // Midnight Slate
                    Color(red: 0.08, green: 0.08, blue: 0.11), // Graphite
                    Color(red: 0.10, green: 0.07, blue: 0.14), // Subtle Violet Slate
                    Color(red: 0.04, green: 0.12, blue: 0.16), // Deep Steel Cyan
                    Color(red: 0.03, green: 0.03, blue: 0.05), // Pure Pitch
                    Color(red: 0.07, green: 0.06, blue: 0.10), // Midnight Zinc
                    Color(red: 0.05, green: 0.09, blue: 0.13)  // Soft Dark Steel
                ]
            )
            .ignoresSafeArea()
        }
    }
}
