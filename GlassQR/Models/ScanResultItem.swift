//
//  ScanResultItem.swift
//  GlassQR
//

import Foundation

public struct ScanResultItem: Identifiable, Equatable, Sendable, Codable {
    public let id: UUID
    public let payload: String
    public let timestamp: Date
    public let symbology: String

    public init(
        id: UUID = UUID(),
        payload: String,
        timestamp: Date = Date(),
        symbology: String = "QR Code"
    ) {
        self.id = id
        self.payload = payload
        self.timestamp = timestamp
        self.symbology = symbology
    }

    private enum CodingKeys: String, CodingKey {
        case id, payload, timestamp, symbology
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.payload = try container.decode(String.self, forKey: .payload)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.symbology = try container.decodeIfPresent(String.self, forKey: .symbology) ?? "QR Code"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(payload, forKey: .payload)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(symbology, forKey: .symbology)
    }

    public enum PayloadCategory: Sendable, Equatable {
        case webURL(URL)
        case wifi(ssid: String, password: String, security: String)
        case email(address: String, subject: String?, body: String?)
        case phone(number: String)
        case sms(number: String, message: String?)
        case contact(name: String, phone: String?, email: String?, org: String?)
        case geo(latitude: Double, longitude: Double, label: String?)
        case encryptedVault(ciphertext: String, decoyURL: String?)
        case productBarcode(code: String, format: String)
        case text(String)
    }

    public var category: PayloadCategory {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        // Steganographic Encrypted Vault check
        if SteganographicQREngine.isEncryptedPayload(trimmed),
           let ciphertext = SteganographicQREngine.extractCiphertext(from: trimmed) {
            return .encryptedVault(ciphertext: ciphertext, decoyURL: trimmed)
        }

        // Product Barcodes (EAN, UPC, Code 128, etc.)
        if symbology != "QR Code" {
            let isNumericCode = trimmed.allSatisfy { $0.isNumber }
            if isNumericCode && (trimmed.count == 8 || trimmed.count == 12 || trimmed.count == 13 || trimmed.count == 14) {
                return .productBarcode(code: trimmed, format: symbology)
            }
        }

        // vCard Contact detection (e.g. BEGIN:VCARD ... END:VCARD)
        if trimmed.uppercased().contains("BEGIN:VCARD") {
            let name = extractVCardField("FN", from: trimmed) ?? extractVCardField("N", from: trimmed) ?? "Contact"
            let phone = extractVCardField("TEL", from: trimmed)
            let email = extractVCardField("EMAIL", from: trimmed)
            let org = extractVCardField("ORG", from: trimmed)
            return .contact(name: name, phone: phone, email: email, org: org)
        }

        // Wi-Fi detection (e.g. WIFI:S:MySSID;T:WPA;P:MyPassword;;)
        if trimmed.hasPrefix("WIFI:") || trimmed.hasPrefix("wifi:") {
            let ssid = extractWifiField("S", from: trimmed) ?? "Unknown Network"
            let password = extractWifiField("P", from: trimmed) ?? ""
            let security = extractWifiField("T", from: trimmed) ?? "WPA"
            return .wifi(ssid: ssid, password: password, security: security)
        }

        // SMS detection (e.g. SMSTO:12345:Hello or sms:12345?body=Hello)
        if trimmed.uppercased().hasPrefix("SMSTO:") {
            let components = trimmed.dropFirst(6).split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            let number = String(components.first ?? "")
            let message = components.count > 1 ? String(components[1]) : nil
            return .sms(number: number, message: message)
        }
        if trimmed.lowercased().hasPrefix("sms:") {
            let raw = String(trimmed.dropFirst(4))
            if let questionIndex = raw.firstIndex(of: "?") {
                let number = String(raw[..<questionIndex])
                let query = String(raw[raw.index(after: questionIndex)...])
                var body: String? = nil
                for item in query.split(separator: "&") {
                    let pair = item.split(separator: "=", maxSplits: 1)
                    if pair.first?.lowercased() == "body", pair.count > 1 {
                        body = String(pair[1]).removingPercentEncoding
                    }
                }
                return .sms(number: number, message: body)
            } else {
                return .sms(number: raw, message: nil)
            }
        }

        // Email detection
        if trimmed.lowercased().hasPrefix("mailto:") {
            let emailStr = String(trimmed.dropFirst(7))
            if let questionIndex = emailStr.firstIndex(of: "?") {
                let address = String(emailStr[..<questionIndex])
                return .email(address: address, subject: nil, body: nil)
            }
            return .email(address: emailStr, subject: nil, body: nil)
        }

        // Phone detection
        if trimmed.lowercased().hasPrefix("tel:") {
            let phoneStr = String(trimmed.dropFirst(4))
            return .phone(number: phoneStr)
        }

        // Geo Location detection (e.g. geo:37.7749,-122.4194)
        if trimmed.lowercased().hasPrefix("geo:") {
            let coords = String(trimmed.dropFirst(4)).split(separator: ",")
            if coords.count >= 2,
               let lat = Double(coords[0].trimmingCharacters(in: .whitespaces)),
               let lon = Double(coords[1].split(separator: "?").first?.trimmingCharacters(in: .whitespaces) ?? "") {
                return .geo(latitude: lat, longitude: lon, label: nil)
            }
        }

        // Apple Maps & Google Maps URL detection
        if trimmed.contains("maps.apple.com") || trimmed.contains("maps.google.com") {
            if let url = URL(string: trimmed), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var lat: Double? = nil
                var lon: Double? = nil
                var label: String? = nil

                if let ll = components.queryItems?.first(where: { $0.name == "ll" })?.value {
                    let parts = ll.split(separator: ",")
                    if parts.count >= 2 {
                        lat = Double(parts[0].trimmingCharacters(in: .whitespaces))
                        lon = Double(parts[1].trimmingCharacters(in: .whitespaces))
                    }
                }
                if let q = components.queryItems?.first(where: { $0.name == "q" })?.value {
                    label = q
                    if lat == nil {
                        let parts = q.split(separator: ",")
                        if parts.count >= 2 {
                            lat = Double(parts[0].trimmingCharacters(in: .whitespaces))
                            lon = Double(parts[1].trimmingCharacters(in: .whitespaces))
                        }
                    }
                }
                if let validLat = lat, let validLon = lon {
                    return .geo(latitude: validLat, longitude: validLon, label: label)
                }
            }
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

    private func extractVCardField(_ field: String, from text: String) -> String? {
        let pattern = "(?i)\(field)(?:;[^:]*)?:([^\r\n]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
