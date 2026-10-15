//
//  ScanResultItem.swift
//  GlassQR
//

import Foundation

public struct ScanResultItem: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let payload: String
    public let timestamp: Date

    public init(id: UUID = UUID(), payload: String, timestamp: Date = Date()) {
        self.id = id
        self.payload = payload
        self.timestamp = timestamp
    }

    public enum PayloadCategory: Sendable, Equatable {
        case webURL(URL)
        case wifi(ssid: String, password: String, security: String)
        case email(address: String, subject: String?, body: String?)
        case phone(number: String)
        case text(String)
    }

    public var category: PayloadCategory {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // Wi-Fi detection (e.g. WIFI:S:MySSID;T:WPA;P:MyPassword;;)
        if trimmed.hasPrefix("WIFI:") || trimmed.hasPrefix("wifi:") {
            let ssid = extractWifiField("S", from: trimmed) ?? "Unknown Network"
            let password = extractWifiField("P", from: trimmed) ?? ""
            let security = extractWifiField("T", from: trimmed) ?? "WPA"
            return .wifi(ssid: ssid, password: password, security: security)
        }

        // Email detection
        if trimmed.lowercased().hasPrefix("mailto:") {
            let emailStr = String(trimmed.dropFirst(7))
            return .email(address: emailStr, subject: nil, body: nil)
        }

        // Phone detection
        if trimmed.lowercased().hasPrefix("tel:") {
            let phoneStr = String(trimmed.dropFirst(4))
            return .phone(number: phoneStr)
        }

        // Web URL detection
        if let url = URL(string: trimmed),
           let scheme = url.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return .webURL(url)
        }

        return .text(trimmed)
    }

    public var isWebURL: Bool {
        if case .webURL = category { return true }
        return false
    }

    private func extractWifiField(_ field: String, from text: String) -> String? {
        let pattern = "\(field):([^;]*);"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }
}
