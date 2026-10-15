//
//  GeneratorView.swift
//  GlassQR
//
//  Optimized QR Code Generator with Smart Templates & Debouncing
//

import SwiftUI

public struct GeneratorView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var generatorNamespace

    // Template Mode
    private enum GeneratorTemplate: String, CaseIterable, Identifiable {
        case url = "Link"
        case wifi = "Wi-Fi"
        case email = "Email"
        case text = "Text"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .url: return "link"
            case .wifi: return "wifi"
            case .email: return "envelope"
            case .text: return "doc.text"
            }
        }
    }

    @State private var selectedTemplate: GeneratorTemplate = .url

    // Raw Inputs
    @State private var inputText: String = "https://apple.com"

    // Wi-Fi Specialized Inputs
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    @State private var wifiSecurity: String = "WPA"

    // Email Specialized Inputs
    @State private var emailAddress: String = ""
    @State private var emailSubject: String = ""

    // Rendered QR State
    @State private var qrImage: UIImage? = nil
    @State private var copyHapticTrigger: Int = 0
    @State private var showCopiedHUD: Bool = false

    private let generatorEngine = CrispQRRenderer()

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Template Selector Platter
                templateSelector
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                // Dynamic Input Form Card
                inputSection
                    .padding(.horizontal, 20)

                // Crisp QR Card Display
                qrDisplayCard
                    .padding(.vertical, 4)

                // Action Bar (Copy & ShareLink)
                if !currentPayload.isEmpty, let image = qrImage {
                    actionBar(image: image)
                        .padding(.horizontal, 24)
                }

                // Transient Copy Notification
                if showCopiedHUD {
                    copiedToast
                }

                Spacer(minLength: 32)
            }
        }
        .navigationTitle("Generator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            renderQR(for: currentPayload)
        }
        .task(id: currentPayload) {
            // 120ms Debounce to prevent CPU churn during fast typing
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
                renderQR(for: currentPayload)
            } catch {}
        }
    }

    // MARK: - Subviews

    private var templateSelector: some View {
        HStack(spacing: 8) {
            ForEach(GeneratorTemplate.allCases) { template in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTemplate = template
                        applyTemplateDefaults()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: template.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(template.rawValue)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .foregroundStyle(selectedTemplate == template ? Color.black : Color.white.opacity(0.75))
                    .background {
                        if selectedTemplate == template {
                            Capsule().fill(Color.white)
                        } else {
                            Capsule().fill(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 12) {
            switch selectedTemplate {
            case .url, .text:
                HStack(spacing: 12) {
                    Image(systemName: selectedTemplate == .url ? "link" : "text.alignleft")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    TextField(
                        selectedTemplate == .url ? "https://example.com" : "Type plain text note...",
                        text: $inputText
                    )
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)

                    if !inputText.isEmpty {
                        clearButton { inputText = "" }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(cleanPillBackground)

            case .wifi:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "wifi")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Network Name (SSID)", text: $wifiSSID)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)

                    HStack(spacing: 10) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        SecureField("Password", text: $wifiPassword)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)
                }

            case .email:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Recipient Email", text: $emailAddress)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)

                    HStack(spacing: 10) {
                        Image(systemName: "pencil")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Subject (Optional)", text: $emailSubject)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)
                }
            }
        }
    }

    private var cleanPillBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    private func clearButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var qrDisplayCard: some View {
        ZStack {
            if let image = qrImage {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 8)

                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                }
                .frame(width: 250, height: 250)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
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
                            .font(.system(size: 44, weight: .light))
                            .foregroundStyle(.white.opacity(0.25))

                        Text("Enter info to generate QR")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }
                .frame(width: 250, height: 250)
            }
        }
    }

    private func actionBar(image: UIImage) -> some View {
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
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }

    private var copiedToast: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Text("QR Copied to Clipboard")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.16, green: 0.16, blue: 0.18))
                .shadow(color: Color.black.opacity(0.3), radius: 8)
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Payload Computation

    private var currentPayload: String {
        switch selectedTemplate {
        case .url, .text:
            return inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        case .wifi:
            guard !wifiSSID.isEmpty else { return "" }
            return "WIFI:S:\(wifiSSID);T:\(wifiSecurity);P:\(wifiPassword);;"
        case .email:
            guard !emailAddress.isEmpty else { return "" }
            if !emailSubject.isEmpty {
                let encodedSubject = emailSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "mailto:\(emailAddress)?subject=\(encodedSubject)"
            }
            return "mailto:\(emailAddress)"
        }
    }

    private func applyTemplateDefaults() {
        switch selectedTemplate {
        case .url:
            inputText = "https://apple.com"
        case .wifi:
            wifiSSID = "ApplePark_Guest"
            wifiPassword = "LiquidGlass2026"
        case .email:
            emailAddress = "developer@apple.com"
            emailSubject = "GlassQR Inquiry"
        case .text:
            inputText = "Hello from GlassQR"
        }
    }

    private func renderQR(for text: String) {
        guard !text.isEmpty else {
            qrImage = nil
            return
        }
        qrImage = generatorEngine.render(text: text)
    }
}
