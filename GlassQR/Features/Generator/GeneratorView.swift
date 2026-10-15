//
//  GeneratorView.swift
//  GlassQR
//

import SwiftUI

public struct GeneratorView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var generatorNamespace

    @State private var inputText: String = "https://apple.com"
    @State private var qrImage: UIImage? = nil
    @State private var copyHapticTrigger: Int = 0
    @State private var showCopiedHUD: Bool = false

    private let generatorEngine = CrispQRRenderer()

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Interactive Glass Input Bar
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.cyan)

                        TextField("Enter URL, Wi-Fi or Plain Text...", text: $inputText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        if !inputText.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    inputText = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.glass)
                            .glassEffectID("clearButton", in: generatorNamespace)
                            .glassEffectTransition(.materialize)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("inputFieldCapsule", in: generatorNamespace)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Crisp QR Vector Rendering Card
                VStack(spacing: 18) {
                    if let image = qrImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)

                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(22)
                        }
                        .frame(width: 260, height: 260)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32))
                        .glassEffectTransition(.materialize)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.08))

                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 54))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .symbolEffect(.breathe, options: .repeating)

                                Text("Type to generate Liquid QR")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(width: 260, height: 260)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32))
                    }
                }
                .padding(.vertical, 8)

                // Morphing Action Bar (Expands dynamically from droplet)
                if !inputText.isEmpty, let image = qrImage {
                    GlassEffectContainer(spacing: 20) {
                        // Copy Button
                        Button {
                            UIPasteboard.general.image = image
                            copyHapticTrigger += 1
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                showCopiedHUD = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showCopiedHUD = false
                                }
                            }
                        } label: {
                            Label("Copy Image", systemImage: "doc.on.doc.fill")
                        }
                        .buttonStyle(.glass)
                        .glassEffectID("copyActionButton", in: generatorNamespace)

                        // Native ShareLink Button
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("Liquid QR Code", image: Image(uiImage: image))
                        ) {
                            Label("Share Code", systemImage: "square.and.arrow.up.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffectID("shareActionButton", in: generatorNamespace)
                    }
                    .glassEffectTransition(.materialize)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
                }

                // Transient Copy HUD Pill
                if showCopiedHUD {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("QR Image Copied to Clipboard")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassEffect()
                    .glassEffectTransition(.materialize)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Liquid Generator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            renderQR(for: inputText)
        }
        .onChange(of: inputText) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                renderQR(for: newValue)
            }
        }
    }

    private func renderQR(for text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            qrImage = nil
            return
        }
        qrImage = generatorEngine.render(text: text)
    }
}
