//
//  ScanningLaserView.swift
//  GlassQR
//
//  Clean Minimalist Scan Line (Apple & ChatGPT Style)
//

import SwiftUI

public struct ScanningLaserView: View {
    public var travelRange: CGFloat
    @State private var scanOffset: CGFloat

    public init(travelRange: CGFloat = 115) {
        self.travelRange = travelRange
        self._scanOffset = State(initialValue: -travelRange)
    }

    public var body: some View {
        ZStack {
            // Subtle Ambient Trail
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.cyan.opacity(0.04),
                            Color.clear
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: 36)
                .offset(y: scanOffset - 18)

            // Sleek Crisp Scan Line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.95),
                            Color.cyan,
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
                .shadow(color: Color.cyan.opacity(0.6), radius: 6, x: 0, y: 0)
                .offset(y: scanOffset)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.2)
                .repeatForever(autoreverses: true)
            ) {
                scanOffset = travelRange
            }
        }
    }
}
