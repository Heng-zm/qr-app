//
//  ScannerReticleView.swift
//  GlassQR
//
//  Clean Minimalist Viewfinder Reticle (Apple & ChatGPT Style)
//

import SwiftUI

public struct ScannerReticleView: View {
    public var cornerRadius: CGFloat
    public var cornerLength: CGFloat
    public var lineWidth: CGFloat
    @State private var isPulsing: Bool = false

    public init(cornerRadius: CGFloat = 28, cornerLength: CGFloat = 36, lineWidth: CGFloat = 3.5) {
        self.cornerRadius = cornerRadius
        self.cornerLength = cornerLength
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let inset = lineWidth / 2.0
            let r = max(cornerRadius - inset, 4.0)
            let cl = cornerLength

            ZStack {
                // Clean Minimalist Corner Brackets - Exactly aligned with squircle cutout
                Path { path in
                    // Top-Left
                    path.move(to: CGPoint(x: inset, y: cl))
                    path.addLine(to: CGPoint(x: inset, y: inset + r))
                    path.addArc(
                        tangent1End: CGPoint(x: inset, y: inset),
                        tangent2End: CGPoint(x: inset + cl, y: inset),
                        radius: r
                    )
                    path.addLine(to: CGPoint(x: cl, y: inset))

                    // Top-Right
                    path.move(to: CGPoint(x: w - cl, y: inset))
                    path.addLine(to: CGPoint(x: w - inset - r, y: inset))
                    path.addArc(
                        tangent1End: CGPoint(x: w - inset, y: inset),
                        tangent2End: CGPoint(x: w - inset, y: inset + cl),
                        radius: r
                    )
                    path.addLine(to: CGPoint(x: w - inset, y: cl))

                    // Bottom-Right
                    path.move(to: CGPoint(x: w - inset, y: h - cl))
                    path.addLine(to: CGPoint(x: w - inset, y: h - inset - r))
                    path.addArc(
                        tangent1End: CGPoint(x: w - inset, y: h - inset),
                        tangent2End: CGPoint(x: w - cl, y: h - inset),
                        radius: r
                    )
                    path.addLine(to: CGPoint(x: w - cl, y: h - inset))

                    // Bottom-Left
                    path.move(to: CGPoint(x: cl, y: h - inset))
                    path.addLine(to: CGPoint(x: inset + r, y: h - inset))
                    path.addArc(
                        tangent1End: CGPoint(x: inset, y: h - inset),
                        tangent2End: CGPoint(x: inset, y: h - cl),
                        radius: r
                    )
                    path.addLine(to: CGPoint(x: inset, y: h - cl))
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)

                // High-precision minimalist center crosshair dot with breathing micro-ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(isPulsing ? 0.45 : 0.15), lineWidth: 1)
                        .frame(width: 14, height: 14)
                        .scaleEffect(isPulsing ? 1.2 : 0.85)

                    Circle()
                        .fill(Color.white.opacity(isPulsing ? 0.9 : 0.5))
                        .frame(width: 4, height: 4)
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
