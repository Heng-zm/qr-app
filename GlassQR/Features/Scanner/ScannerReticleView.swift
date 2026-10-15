//
//  ScannerReticleView.swift
//  GlassQR
//

import SwiftUI

public struct ScannerReticleView: View {
    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let length: CGFloat = 28
            let thickness: CGFloat = 4

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
            .stroke(Color.cyan, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        }
    }
}
