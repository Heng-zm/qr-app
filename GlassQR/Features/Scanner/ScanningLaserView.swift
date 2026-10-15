//
//  ScanningLaserView.swift
//  GlassQR
//

import SwiftUI

public struct ScanningLaserView: View {
    @State private var scanOffset: CGFloat = -110

    public init() {}

    public var body: some View {
        ZStack {
            // Light Cone / Shimmer Fan above the beam
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .cyan.opacity(0.18),
                            .indigo.opacity(0.04),
                            .clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 48)
                .offset(y: scanOffset - 24)

            // Primary Refractive Laser Beam
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .cyan.opacity(0.0),
                            .cyan.opacity(0.9),
                            .white,
                            .cyan.opacity(0.9),
                            .cyan.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)
                .shadow(color: .cyan, radius: 10, x: 0, y: 0)
                .shadow(color: .white, radius: 4, x: 0, y: 0)
                .offset(y: scanOffset)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                scanOffset = 110
            }
        }
    }
}
