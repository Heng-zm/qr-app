//
//  ScannerReticleView.swift
//  GlassQR
//
//  Clean Minimalist Viewfinder Reticle (Apple & ChatGPT Style)
//

import SwiftUI

public struct ScannerReticleView: View {
    @State private var isPulsing: Bool = false

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let cornerLength: CGFloat = 36
            let lineWidth: CGFloat = 3.5
            let cornerRadius: CGFloat = 26

            ZStack {
                // Clean Minimalist Corner Brackets
                Path { path in
                    // Top-Left
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: cornerRadius))
                    path.addQuadCurve(
                        to: CGPoint(x: cornerRadius, y: 0),
                        control: CGPoint(x: 0, y: 0)
                    )
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))

                    // Top-Right
                    path.move(to: CGPoint(x: w - cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: w - cornerRadius, y: 0))
                    path.addQuadCurve(
                        to: CGPoint(x: w, y: cornerRadius),
                        control: CGPoint(x: w, y: 0)
                    )
                    path.addLine(to: CGPoint(x: w, y: cornerLength))

                    // Bottom-Left
                    path.move(to: CGPoint(x: 0, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: h - cornerRadius))
                    path.addQuadCurve(
                        to: CGPoint(x: cornerRadius, y: h),
                        control: CGPoint(x: 0, y: h)
                    )
                    path.addLine(to: CGPoint(x: cornerLength, y: h))

                    // Bottom-Right
                    path.move(to: CGPoint(x: w - cornerLength, y: h))
                    path.addLine(to: CGPoint(x: w - cornerRadius, y: h))
                    path.addQuadCurve(
                        to: CGPoint(x: w, y: h - cornerRadius),
                        control: CGPoint(x: w, y: h)
                    )
                    path.addLine(to: CGPoint(x: w, y: h - cornerLength))
                }
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 2)

                // Minimalist Center Crosshair Dot
                Circle()
                    .fill(Color.white.opacity(isPulsing ? 0.7 : 0.35))
                    .frame(width: 4, height: 4)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
