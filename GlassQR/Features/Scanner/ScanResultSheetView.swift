//
//  ScanResultSheetView.swift
//  GlassQR
//
//  Clean Minimalist Scan Result Sheet (Apple & ChatGPT Style)
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
            // Calm Dark Obsidian Glass Backdrop
            Color(red: 0.07, green: 0.07, blue: 0.09)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Drag Handle
                Capsule()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 4.5)
                    .padding(.top, 10)

                // Header
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 42, height: 42)

                        Image(systemName: iconName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(titleText)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(result.timestamp.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)

                // Clean Content Card
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

                // Clean Action Buttons
                VStack(spacing: 10) {
                    actionButtons
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }

    // MARK: - Category Cards

    @ViewBuilder
    private func wifiCard(ssid: String, password: String, security: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("WI-FI NETWORK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(security.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("SSID: ")
                        .foregroundStyle(.white.opacity(0.55))
                    Text(ssid)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                .font(.system(size: 14, design: .rounded))

                if !password.isEmpty {
                    HStack {
                        Text("Password: ")
                            .foregroundStyle(.white.opacity(0.55))
                        Text(password)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 14, design: .rounded))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func urlCard(url: URL) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("WEBSITE LINK")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text(url.host ?? "URL")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(result.payload)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func emailCard(address: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("EMAIL ADDRESS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            Text(address)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func phoneCard(number: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PHONE NUMBER")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            Text(number)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func textCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TEXT CONTENT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Text("\(text.count) chars")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            ScrollView {
                Text(text)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 90)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private var actionButtons: some View {
        switch result.category {
        case .webURL(let url):
            HStack(spacing: 12) {
                Button {
                    copyToClipboard(result.payload)
                } label: {
                    Label(copied ? "Copied" : "Copy Link", systemImage: copied ? "checkmark" : "doc.on.doc")
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
            HStack(spacing: 12) {
                if !password.isEmpty {
                    Button {
                        UIPasteboard.general.string = password
                        copyHapticTrigger += 1
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            copiedPassword = true
                        }
                    } label: {
                        Label(copiedPassword ? "Password Copied" : "Copy Password", systemImage: copiedPassword ? "checkmark" : "key")
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
            HStack(spacing: 12) {
                Button {
                    copyToClipboard(address)
                } label: {
                    Label(copied ? "Copied" : "Copy Email", systemImage: copied ? "checkmark" : "doc.on.doc")
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
            HStack(spacing: 12) {
                Button {
                    copyToClipboard(number)
                } label: {
                    Label(copied ? "Copied" : "Copy Number", systemImage: copied ? "checkmark" : "doc.on.doc")
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
            HStack(spacing: 12) {
                Button {
                    copyToClipboard(text)
                } label: {
                    Label(copied ? "Copied" : "Copy Text", systemImage: copied ? "checkmark" : "doc.on.doc")
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
        case .webURL: return "link"
        case .wifi: return "wifi"
        case .email: return "envelope"
        case .phone: return "phone"
        case .text: return "doc.text"
        }
    }

    private var titleText: String {
        switch result.category {
        case .webURL: return "Website Link"
        case .wifi: return "Wi-Fi Network"
        case .email: return "Email Address"
        case .phone: return "Phone Number"
        case .text: return "Text Payload"
        }
    }
}
