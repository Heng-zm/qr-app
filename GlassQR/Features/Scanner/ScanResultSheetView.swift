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
    @State private var copiedPassword: Bool = false
    @State private var copyHapticTrigger: Int = 0

    public init(result: ScanResultItem) {
        self.result = result
    }

    public var body: some View {
        ZStack {
            // Refracting Mesh Gradient Sheet Backdrop
            LiquidMeshGradientView()
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Drag Indicator Cap
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                // Header with Dynamic Type Icon
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 48, height: 48)

                        Image(systemName: iconName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.cyan)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(titleText)
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(result.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Dynamic Category Content Body
                VStack(spacing: 12) {
                    switch result.category {
                    case .wifi(let ssid, let password, let security):
                        wifiCard(ssid: ssid, password: password, security: security)

                    case .webURL(let url):
                        urlCard(url: url)

                    case .email(let address, _, _):
                        emailCard(address: address)

                    case .phone(let number):
                        phoneCard(number: number)

                    case .text(let text):
                        textCard(text: text)
                    }
                }
                .padding(.horizontal, 24)

                // Action Buttons
                VStack(spacing: 12) {
                    actionButtons
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 12)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }

    // MARK: - Category Cards

    @ViewBuilder
    private func wifiCard(ssid: String, password: String, security: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WI-FI CREDENTIALS")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(security.uppercased())
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "wifi")
                        .foregroundStyle(.cyan)
                    Text("SSID: ")
                        .foregroundStyle(.white.opacity(0.7))
                    Text(ssid)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14, design: .rounded))

                if !password.isEmpty {
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(.indigo)
                        Text("Password: ")
                            .foregroundStyle(.white.opacity(0.7))
                        Text(password)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14, design: .rounded))
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func urlCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEBSITE LINK")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(url.host ?? "URL")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.cyan)
            }

            Text(result.payload)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func emailCard(address: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EMAIL ADDRESS")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Text(address)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func phoneCard(number: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHONE NUMBER")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            Text(number)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func textCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TEXT CONTENT")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text("\(text.count) chars")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 90)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButtons: some View {
        switch result.category {
        case .webURL(let url):
            HStack(spacing: 14) {
                Button {
                    copyToClipboard(result.payload)
                } label: {
                    Label(copied ? "Copied!" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                Button {
                    openURL(url)
                    dismiss()
                } label: {
                    Label("Open in Safari", systemImage: "arrow.up.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }

        case .wifi(_, let password, _):
            HStack(spacing: 14) {
                if !password.isEmpty {
                    Button {
                        UIPasteboard.general.string = password
                        copyHapticTrigger += 1
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            copiedPassword = true
                        }
                    } label: {
                        Label(copiedPassword ? "Password Copied!" : "Copy Password", systemImage: copiedPassword ? "checkmark" : "key")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }

                Button {
                    copyToClipboard(result.payload)
                } label: {
                    Label(copied ? "Copied" : "Copy Raw", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }

        case .email(let address, _, _):
            HStack(spacing: 14) {
                Button {
                    copyToClipboard(address)
                } label: {
                    Label(copied ? "Copied!" : "Copy Email", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if let mailURL = URL(string: "mailto:\(address)") {
                    Button {
                        openURL(mailURL)
                        dismiss()
                    } label: {
                        Label("Compose", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }

        case .phone(let number):
            HStack(spacing: 14) {
                Button {
                    copyToClipboard(number)
                } label: {
                    Label(copied ? "Copied!" : "Copy Number", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if let telURL = URL(string: "tel:\(number.replacingOccurrences(of: " ", with: ""))") {
                    Button {
                        openURL(telURL)
                        dismiss()
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }

        case .text(let text):
            HStack(spacing: 14) {
                Button {
                    copyToClipboard(text)
                } label: {
                    Label(copied ? "Copied!" : "Copy Text", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if let query = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                   let searchURL = URL(string: "https://www.google.com/search?q=\(query)") {
                    Button {
                        openURL(searchURL)
                        dismiss()
                    } label: {
                        Label("Search Web", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        copyHapticTrigger += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            copied = true
        }
    }

    private var iconName: String {
        switch result.category {
        case .webURL: return "globe"
        case .wifi: return "wifi"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .text: return "text.viewfinder"
        }
    }

    private var titleText: String {
        switch result.category {
        case .webURL: return "Web Link Detected"
        case .wifi: return "Wi-Fi Network Found"
        case .email: return "Email Address Detected"
        case .phone: return "Phone Number Found"
        case .text: return "Text Payload Detected"
        }
    }
}
