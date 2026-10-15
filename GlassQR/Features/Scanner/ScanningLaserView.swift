//
//  ScanningLaserView.swift
//  GlassQR
//
//  Radiant Liquid Glass Optical Laser
//

import SwiftUI

public struct ScanningLaserView: View {
    @State private var scanOffset: CGFloat = -115

    public init() {}

    public var body: some View {
        ZStack {
            // Refractive Ambient Light Fan
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.22),
                            Color.indigo.opacity(0.08),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 56)
                .offset(y: scanOffset - 28)

            // Radiant Dual Core Laser Beam
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(0.0),
                            Color(red: 0.2, green: 0.9, blue: 1.0),
                            Color.white,
                            Color(red: 0.2, green: 0.9, blue: 1.0),
                            Color.cyan.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3.5)
                .shadow(color: .cyan, radius: 12, x: 0, y: 0)
                .shadow(color: .white, radius: 4, x: 0, y: 0)
                .offset(y: scanOffset)

            // Micro Optical Beam Flare
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .shadow(color: .cyan, radius: 8)
                .offset(y: scanOffset)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.1)
                .repeatForever(autoreverses: true)
            ) {
                scanOffset = 115
            }
        }
    }
}
