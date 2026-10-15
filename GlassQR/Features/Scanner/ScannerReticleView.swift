//
//  ScannerReticleView.swift
//  GlassQR
//

import SwiftUI

public struct ScannerReticleView: View {
    @State private var pulse: Bool = false

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let length: CGFloat = 32
            let thickness: CGFloat = 4.5

            ZStack {
                // Outer Bracket Path
                Path { path in
                    // Top Left
                    path.move(to: CGPoint(x: 0, y: length))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: length, y: 0))

                    // Top Right
                    path.move(to: CGPoint(x: w - length, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: length))

                    // Bottom Left
                    path.move(to: CGPoint(x: 0, y: h - length))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: length, y: h))

                    // Bottom Right
                    path.move(to: CGPoint(x: w - length, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - length))
                }
                .stroke(
                    LinearGradient(
                        colors: [.cyan, .white, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .cyan.opacity(pulse ? 0.8 : 0.4), radius: pulse ? 12 : 6, x: 0, y: 0)

                // Corner Optical Nodes
                Group {
                    Circle().fill(Color.white).frame(width: 5, height: 5).position(x: 0, y: 0)
                    Circle().fill(Color.white).frame(width: 5, height: 5).position(x: w, y: 0)
                    Circle().fill(Color.white).frame(width: 5, height: 5).position(x: 0, y: h)
                    Circle().fill(Color.white).frame(width: 5, height: 5).position(x: w, y: h)
                }
                .shadow(color: .cyan, radius: 4)

                // Center Subtle Glass Crosshairs
                Path { path in
                    let cx = w / 2
                    let cy = h / 2
                    let r: CGFloat = 10
                    path.move(to: CGPoint(x: cx - r, y: cy))
                    path.addLine(to: CGPoint(x: cx + r, y: cy))
                    path.move(to: CGPoint(x: cx, y: cy - r))
                    path.addLine(to: CGPoint(x: cx, y: cy + r))
                }
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
