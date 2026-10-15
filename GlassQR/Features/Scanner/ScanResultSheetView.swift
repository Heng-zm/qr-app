//
//  ScanResultSheetView.swift
//  GlassQR
//

import SwiftUI

public struct ScanResultSheetView: View {
    public let result: ScanResultItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var copied: Bool = false
    @State private var copyHapticTrigger: Int = 0

    public init(result: ScanResultItem) {
        self.result = result
    }

    public var body: some View {
        ZStack {
            // Refracting Mesh Gradient Sheet Backdrop
            LiquidMeshGradientView()
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // Drag Indicator Cap
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                // Header
                HStack(spacing: 12) {
                    Image(systemName: result.isWebURL ? "globe" : "text.viewfinder")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.isWebURL ? "Web Link Detected" : "Text Payload Detected")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(result.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Decoded Content Display Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAYLOAD")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    ScrollView {
                        Text(result.payload)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(18)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .padding(.horizontal, 24)

                // Interactive Glass Buttons
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = result.payload
                        copyHapticTrigger += 1
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            copied = true
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Payload", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    if result.isWebURL, let url = URL(string: result.payload) {
                        Button {
                            openURL(url)
                            dismiss()
                        } label: {
                            Label("Open in Safari", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }
}
