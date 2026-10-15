//
//  LiquidMeshGradientView.swift
//  GlassQR
//

import SwiftUI

public struct LiquidMeshGradientView: View {
    public init() {}

    public var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let t = Float(date * 0.75)

            // Dynamic oscillation points creating fluid liquid surface
            let p1x = 0.5 + 0.16 * cos(t * 0.6)
            let p1y = 0.5 + 0.16 * sin(t * 0.8)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [p1x, p1y], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(red: 0.07, green: 0.03, blue: 0.20), // Midnight Indigo
                    Color(red: 0.18, green: 0.05, blue: 0.38), // Electric Violet
                    Color(red: 0.03, green: 0.30, blue: 0.52), // Deep Cyan
                    Color(red: 0.12, green: 0.08, blue: 0.30), // Royal Indigo
                    Color(red: 0.55, green: 0.10, blue: 0.50), // Liquid Magenta
                    Color(red: 0.00, green: 0.58, blue: 0.80), // Electric Cyan
                    Color(red: 0.04, green: 0.01, blue: 0.15), // Deep Midnight
                    Color(red: 0.30, green: 0.06, blue: 0.42), // Indigo Violet
                    Color(red: 0.06, green: 0.40, blue: 0.60)  // Glowing Cyan
                ]
            )
            .ignoresSafeArea()
        }
    }
}
