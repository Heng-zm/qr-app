//
//  GeneratorView.swift
//  GlassQR
//
//  Optimized QR Code Generator with Smart Templates, Custom Styles, and Badges
//

import SwiftUI
import UIKit

public struct GeneratorView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var generatorNamespace

    // Template Mode
    private enum GeneratorTemplate: String, CaseIterable, Identifiable {
        case url = "Link"
        case wifi = "Wi-Fi"
        case contact = "Contact"
        case sms = "SMS"
        case email = "Email"
        case text = "Text"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .url: return "link"
            case .wifi: return "wifi"
            case .contact: return "person.crop.circle"
            case .sms: return "message.fill"
            case .email: return "envelope"
            case .text: return "doc.text"
            }
        }
    }

    // Color Styles
    private enum QRColorTheme: String, CaseIterable, Identifiable {
        case obsidian = "Obsidian"
        case cobalt = "Cobalt"
        case emerald = "Emerald"
        case berry = "Berry"
        case slate = "Slate"

        var id: String { rawValue }

        var uiColor: UIColor {
            switch self {
            case .obsidian: return UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
            case .cobalt: return UIColor(red: 0.04, green: 0.35, blue: 0.85, alpha: 1.0)
            case .emerald: return UIColor(red: 0.08, green: 0.55, blue: 0.32, alpha: 1.0)
            case .berry: return UIColor(red: 0.72, green: 0.12, blue: 0.45, alpha: 1.0)
            case .slate: return UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)
            }
        }

        var swiftColor: Color {
            Color(uiColor: uiColor)
        }
    }

    // Center Badge Options
    private enum CenterBadge: String, CaseIterable, Identifiable {
        case none = "None"
        case link = "link"
        case wifi = "wifi"
        case person = "person.fill"
        case star = "star.fill"
        case sparkles = "sparkles"

        var id: String { rawValue }

        var iconName: String? {
            self == .none ? nil : rawValue
        }
    }

    @State private var selectedTemplate: GeneratorTemplate = .url
    @State private var selectedTheme: QRColorTheme = .obsidian
    @State private var selectedBadge: CenterBadge = .none

    // Raw Inputs
    @State private var inputText: String = "https://apple.com"

    // Wi-Fi Specialized Inputs
    @State private var wifiSSID: String = ""
    @State private var wifiPassword: String = ""
    @State private var wifiSecurity: String = "WPA"

    // Contact Specialized Inputs
    @State private var contactName: String = "Alex Rivera"
    @State private var contactPhone: String = "+1 555 019 2834"
    @State private var contactEmail: String = "alex@example.com"
    @State private var contactOrg: String = "Acme Design"

    // SMS Specialized Inputs
    @State private var smsNumber: String = ""
    @State private var smsMessage: String = ""

    // Email Specialized Inputs
    @State private var emailAddress: String = ""
    @State private var emailSubject: String = ""

    // Rendered QR State
    @State private var qrImage: UIImage? = nil
    @State private var copyHapticTrigger: Int = 0
    @State private var toastMessage: String? = nil

    private let generatorEngine = CrispQRRenderer()

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Template Selector Carousel
                templateSelector
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                // Dynamic Input Form Section
                inputSection
                    .padding(.horizontal, 20)

                // Style & Badge Customization Platter
                stylingPlatter
                    .padding(.horizontal, 20)

                // Crisp QR Code Display Card
                qrDisplayCard
                    .padding(.vertical, 4)

                // Action Bar (Copy, Save to Photos, Share)
                if !currentPayload.isEmpty, let image = qrImage {
                    actionBar(image: image)
                        .padding(.horizontal, 24)
                }

                // Transient Notification Toast
                if let msg = toastMessage {
                    toastBanner(message: msg)
                }

                Spacer(minLength: 94)
            }
        }
        .navigationTitle("Generator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            renderCurrentQR()
        }
        .task(id: currentPayload) {
            // 120ms Debounce to prevent CPU churn during fast typing
            do {
                try await Task.sleep(nanoseconds: 120_000_000)
                renderCurrentQR()
            } catch {}
        }
        .onChange(of: selectedTheme) { _, _ in
            renderCurrentQR()
        }
        .onChange(of: selectedBadge) { _, _ in
            renderCurrentQR()
        }
    }

    // MARK: - UI Subviews

    private var templateSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
            .padding(.horizontal, 4)
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

            case .contact:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Full Name", text: $contactName)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)

                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Phone Number", text: $contactPhone)
                            .keyboardType(.phonePad)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)

                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Email (Optional)", text: $contactEmail)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)
                }

            case .sms:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Recipient Phone Number", text: $smsNumber)
                            .keyboardType(.phonePad)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(cleanPillBackground)

                    HStack(spacing: 10) {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 20)
                        TextField("Message Body (Optional)", text: $smsMessage)
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

    // MARK: - Styling Platter (Color & Center Badge)

    private var stylingPlatter: some View {
        HStack(spacing: 16) {
            colorThemeSelector
            Spacer()
            badgeSelector
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var colorThemeSelector: some View {
        HStack(spacing: 8) {
            ForEach(QRColorTheme.allCases) { theme in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedTheme = theme
                    }
                } label: {
                    themeDot(for: theme)
                }
            }
        }
    }

    @ViewBuilder
    private func themeDot(for theme: QRColorTheme) -> some View {
        ZStack {
            Circle()
                .fill(theme.swiftColor)
                .frame(width: 22, height: 22)

            if selectedTheme == theme {
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
        }
        .frame(width: 28, height: 28)
    }

    private var badgeSelector: some View {
        Menu {
            ForEach(CenterBadge.allCases) { badge in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selectedBadge = badge
                    }
                } label: {
                    badgeMenuLabel(for: badge)
                }
            }
        } label: {
            badgeMenuTrigger
        }
    }

    @ViewBuilder
    private func badgeMenuLabel(for badge: CenterBadge) -> some View {
        if badge == .none {
            Text("No Center Icon")
        } else {
            Label(badge.rawValue.capitalized, systemImage: badge.rawValue)
        }
    }

    private var badgeMenuTrigger: some View {
        HStack(spacing: 6) {
            Image(systemName: selectedBadge.iconName ?? "circle.slash")
                .font(.system(size: 12))
            Text(selectedBadge == .none ? "Icon" : selectedBadge.rawValue.capitalized)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 9))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .foregroundStyle(Color.white.opacity(0.85))
        .background(Capsule().fill(Color.white.opacity(0.08)))
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
        HStack(spacing: 10) {
            // Copy Image
            Button {
                UIPasteboard.general.image = image
                triggerToast("QR Image Copied")
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            // Save to Photos
            Button {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                triggerToast("Saved to Photos")
            } label: {
                Label("Save", systemImage: "arrow.down.to.line")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)

            // Native Share
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("QR Code", image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }

    private func toastBanner(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Text(message)
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

    private func triggerToast(_ message: String) {
        copyHapticTrigger += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    // MARK: - Payload Computation

    private var currentPayload: String {
        switch selectedTemplate {
        case .url, .text:
            return inputText.trimmingCharacters(in: .whitespacesAndNewlines)

        case .wifi:
            guard !wifiSSID.isEmpty else { return "" }
            return "WIFI:S:\(wifiSSID);T:\(wifiSecurity);P:\(wifiPassword);;"

        case .contact:
            guard !contactName.isEmpty else { return "" }
            var vcard = "BEGIN:VCARD\nVERSION:3.0\nFN:\(contactName)\n"
            if !contactPhone.isEmpty { vcard += "TEL:\(contactPhone)\n" }
            if !contactEmail.isEmpty { vcard += "EMAIL:\(contactEmail)\n" }
            if !contactOrg.isEmpty { vcard += "ORG:\(contactOrg)\n" }
            vcard += "END:VCARD"
            return vcard

        case .sms:
            guard !smsNumber.isEmpty else { return "" }
            if !smsMessage.isEmpty {
                return "SMSTO:\(smsNumber):\(smsMessage)"
            }
            return "SMSTO:\(smsNumber):"

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
        case .contact:
            contactName = "Alex Rivera"
            contactPhone = "+1 555 019 2834"
            contactEmail = "alex@example.com"
            contactOrg = "Acme Design"
        case .sms:
            smsNumber = "+1 555 019 2834"
            smsMessage = "Hey there from GlassQR!"
        case .email:
            emailAddress = "developer@apple.com"
            emailSubject = "GlassQR Inquiry"
        case .text:
            inputText = "Hello from GlassQR"
        }
    }

    private func renderCurrentQR() {
        let payload = currentPayload
        guard !payload.isEmpty else {
            qrImage = nil
            return
        }
        qrImage = generatorEngine.render(
            text: payload,
            foregroundColor: selectedTheme.uiColor,
            backgroundColor: .white,
            centerIconName: selectedBadge.iconName
        )
    }
}
