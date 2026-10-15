//
//  ScanningLaserView.swift
//  GlassQR
//

import SwiftUI

public struct ScanningLaserView: View {
    @State private var scanOffset: CGFloat = -110

    public init() {}

    public var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .cyan.opacity(0.0),
                        .cyan.opacity(0.85),
                        .white,
                        .cyan.opacity(0.85),
                        .cyan.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 3)
            .shadow(color: .cyan, radius: 8, x: 0, y: 0)
            .offset(y: scanOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    scanOffset = 110
                }
            }
    }
}
