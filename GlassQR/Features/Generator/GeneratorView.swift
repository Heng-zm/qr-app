//
//  GeneratorView.swift
//  GlassQR
//
//  Clean Minimalist QR Code Generator (Apple & ChatGPT Style)
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
                // ChatGPT-style Clean Floating Input Capsule
                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))

                    TextField("Enter URL, Wi-Fi or text...", text: $inputText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)

                    if !inputText.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                inputText = ""
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Clean Crisp QR Card Display
                VStack(spacing: 20) {
                    if let image = qrImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 6)

                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                        }
                        .frame(width: 250, height: 250)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )

                            VStack(spacing: 10) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 48, weight: .light))
                                    .foregroundStyle(.white.opacity(0.25))

                                Text("Enter text to generate QR")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                        }
                        .frame(width: 250, height: 250)
                    }
                }
                .padding(.vertical, 6)

                // Clean Action Bar
                if !inputText.isEmpty, let image = qrImage {
                    HStack(spacing: 14) {
                        Button {
                            UIPasteboard.general.image = image
                            copyHapticTrigger += 1
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                showCopiedHUD = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showCopiedHUD = false
                                }
                            }
                        } label: {
                            Label("Copy Image", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("QR Code", image: Image(uiImage: image))
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                    .padding(.horizontal, 24)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
                }

                // Clean Floating Copied Notification Pill
                if showCopiedHUD {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Copied to Clipboard")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.15, green: 0.15, blue: 0.18))
                            .shadow(color: Color.black.opacity(0.3), radius: 8)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer(minLength: 32)
            }
        }
        .navigationTitle("Generator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            renderQR(for: inputText)
        }
        .onChange(of: inputText) { _, newValue in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
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
