//
//  ScannerReticleView.swift
//  GlassQR
//
//  Futuristic iOS 26 Liquid Glass Optical Reticle
//

import SwiftUI

public struct ScannerReticleView: View {
    @State private var pulse: Bool = false
    @State private var radarRotation: Double = 0

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let bracketLength: CGFloat = 36
            let bracketThickness: CGFloat = 4.5

            ZStack {
                // Subtle Optical Radar Sweep Gradient
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, .cyan.opacity(0.15), .clear],
                            center: .center
                        ),
                        lineWidth: 1
                    )
                    .frame(width: w * 0.85, height: h * 0.85)
                    .rotationEffect(.degrees(radarRotation))

                // Corner Glass Lensing Brackets
                Path { path in
                    // Top Left Bracket
                    path.move(to: CGPoint(x: 0, y: bracketLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: bracketLength, y: 0))

                    // Top Right Bracket
                    path.move(to: CGPoint(x: w - bracketLength, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: bracketLength))

                    // Bottom Left Bracket
                    path.move(to: CGPoint(x: 0, y: h - bracketLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: bracketLength, y: h))

                    // Bottom Right Bracket
                    path.move(to: CGPoint(x: w - bracketLength, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - bracketLength))
                }
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.85, blue: 1.0),
                            Color.white,
                            Color(red: 0.6, green: 0.3, blue: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: bracketThickness, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .cyan.opacity(pulse ? 0.9 : 0.4), radius: pulse ? 14 : 7, x: 0, y: 0)

                // Corner Glowing Sapphire Nodes
                Group {
                    bracketCornerNode(x: 0, y: 0)
                    bracketCornerNode(x: w, y: 0)
                    bracketCornerNode(x: 0, y: h)
                    bracketCornerNode(x: w, y: h)
                }

                // Center Holographic Optical Reticle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        .frame(width: 24, height: 24)

                    Circle()
                        .fill(Color.cyan.opacity(pulse ? 0.6 : 0.3))
                        .frame(width: 4, height: 4)

                    // Crosshair Ticks
                    Path { path in
                        let cx = w / 2
                        let cy = h / 2
                        let gap: CGFloat = 16
                        let tick: CGFloat = 8

                        // Top
                        path.move(to: CGPoint(x: cx, y: cy - gap - tick))
                        path.addLine(to: CGPoint(x: cx, y: cy - gap))
                        // Bottom
                        path.move(to: CGPoint(x: cx, y: cy + gap))
                        path.addLine(to: CGPoint(x: cx, y: cy + gap + tick))
                        // Left
                        path.move(to: CGPoint(x: cx - gap - tick, y: cy))
                        path.addLine(to: CGPoint(x: cx - gap, y: cy))
                        // Right
                        path.move(to: CGPoint(x: cx + gap, y: cy))
                        path.addLine(to: CGPoint(x: cx + gap + tick, y: cy))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                radarRotation = 360
            }
        }
    }

    @ViewBuilder
    private func bracketCornerNode(x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, .cyan],
                    center: .center,
                    startRadius: 0,
                    endRadius: 4
                )
            )
            .frame(width: 6, height: 6)
            .shadow(color: .cyan, radius: 6)
            .position(x: x, y: y)
    }
}
