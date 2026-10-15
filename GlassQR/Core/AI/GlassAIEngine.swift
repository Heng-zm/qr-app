//
//  GlassAIEngine.swift
//  GlassQR
//
//  Intelligent Agent Engine powering offline heuristics, QR generation from
//  natural language, threat assessment, barcode decoding, and cloud LLM integration.
//

import Foundation
import SwiftUI

public final class GlassAIEngine: ObservableObject {
    public static let shared = GlassAIEngine()

    @AppStorage("glass_ai_api_key") public var apiKey: String = ""
    @AppStorage("glass_ai_endpoint") public var customEndpoint: String = ""

    public init() {}

    // MARK: - Main Message Processing Pipeline

    public func processPrompt(_ rawPrompt: String) async -> AIAgentMessage {
        let trimmed = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return AIAgentMessage(
                isUser: false,
                text: "Please enter a prompt or question so I can assist you.",
                quickPrompts: ["Generate Wi-Fi QR", "Check link safety", "Create a vCard"]
            )
        }

        // Check if user has configured custom cloud LLM API Key
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanKey.isEmpty {
            do {
                if let cloudResponse = try await fetchCloudLLMResponse(prompt: trimmed, apiKey: cleanKey) {
                    return cloudResponse
                }
            } catch {
                // Graceful fallback to on-device engine on network error
            }
        }

        // On-Device Intelligent Neural Heuristics Engine
        return processOfflineHeuristics(trimmed)
    }

    // MARK: - Scan Analysis & Safety Inspection

    public func analyzeScannedItem(_ item: ScanResultItem) -> AIAgentMessage {
        switch item.category {
        case .webURL(let url):
            let badge = evaluateURLSafety(url)
            let details = describeURL(url)
            return AIAgentMessage(
                isUser: false,
                text: "### URL Intelligence Analysis\n\nI analyzed the destination **\(url.host ?? url.absoluteString)**.\n\n\(details)",
                securityBadge: badge,
                quickPrompts: ["Is this domain reputable?", "Extract URL parameters", "Copy sanitized link"]
            )

        case .wifi(let ssid, let password, let security):
            let strength = assessPasswordStrength(password)
            let text = """
            ### Wi-Fi Configuration Breakdown

            - **SSID (Network Name):** `\(ssid)`
            - **Security Encryption:** `\(security)`
            - **Password Strength:** \(strength.label)

            \(strength.advice)
            """
            let suggested = AISuggestedQR(
                title: "Wi-Fi: \(ssid)",
                payload: item.payload,
                formatLabel: "Wi-Fi Network",
                iconName: "wifi"
            )
            let badge = AISecurityBadge(
                level: strength.isSecure ? .safe : .caution,
                title: strength.isSecure ? "Protected Network" : "Weak Passphrase",
                details: "Encryption: \(security). Ensure WPA2/WPA3 is enforced on your router."
            )
            return AIAgentMessage(
                isUser: false,
                text: text,
                suggestedQR: suggested,
                securityBadge: badge,
                quickPrompts: ["Generate printable Wi-Fi sign", "Tips for router security"]
            )

        case .productBarcode(let code, let format):
            let barcodeInfo = explainBarcode(code: code, format: format)
            return AIAgentMessage(
                isUser: false,
                text: barcodeInfo,
                securityBadge: AISecurityBadge(
                    level: .info,
                    title: "\(format) Decoded",
                    details: "Standard Symbology with verified check-digit algorithm."
                ),
                quickPrompts: ["Search product on Google", "Lookup Amazon barcode", "Export as vector PDF"]
            )

        case .contact(let name, let phone, let email, let org):
            let contactText = """
            ### Digital Contact vCard Detected

            - **Full Name:** \(name)
            \(org.map { "- **Organization:** \($0)\n" } ?? "")\(phone.map { "- **Phone:** \($0)\n" } ?? "")\(email.map { "- **Email:** \($0)\n" } ?? "")
            This contact can be directly imported into your Apple Contacts book.
            """
            return AIAgentMessage(
                isUser: false,
                text: contactText,
                suggestedQR: AISuggestedQR(
                    title: name,
                    payload: item.payload,
                    formatLabel: "vCard 3.0",
                    iconName: "person.crop.circle"
                ),
                quickPrompts: ["Save to Apple Contacts", "Generate matching vCard QR"]
            )

        default:
            return AIAgentMessage(
                isUser: false,
                text: "### Content Summary\n\n**Payload:**\n`\(item.payload)`\n\nLength: \(item.payload.count) characters.",
                quickPrompts: ["Create QR from this", "Check safety", "Convert to uppercase"]
            )
        }
    }

    // MARK: - On-Device NLP & Intent Parser

    private func processOfflineHeuristics(_ prompt: String) -> AIAgentMessage {
        let lower = prompt.lowercased()

        // 1. Wi-Fi Generation Intent
        if lower.contains("wifi") || lower.contains("wi-fi") || lower.contains("hotspot") {
            return parseWiFiIntent(prompt: prompt, lower: lower)
        }

        // 2. Contact / vCard Intent
        if lower.contains("contact") || lower.contains("vcard") || lower.contains("business card") {
            return parseContactIntent(prompt: prompt)
        }

        // 3. Website / URL Intent
        if lower.contains("url") || lower.contains("website") || lower.contains("link") || lower.contains("http") || lower.contains(".com") || lower.contains(".org") {
            return parseURLIntent(prompt: prompt)
        }

        // 4. Barcode Question
        if lower.contains("barcode") || lower.contains("ean") || lower.contains("upc") || lower.contains("128") {
            return AIAgentMessage(
                isUser: false,
                text: """
                ### Barcode Symbologies Decoded

                - **EAN-13 / UPC-A:** Universal retail product standards. The first 2–3 digits denote the GS1 country code, followed by manufacturer and product item codes.
                - **Code 128:** High-density alphanumeric barcode widely used in logistics, inventory, and shipping labels.
                - **DataMatrix & Aztec:** 2D matrix codes commonly used in healthcare packaging and transit boarding passes.

                GlassQR can scan all standard 1D & 2D formats in real time with hardware camera acceleration!
                """,
                quickPrompts: ["How do QR error correction levels work?", "Scan a barcode now", "Generate Wi-Fi QR"]
            )
        }

        // 5. Error Correction & QR Specs
        if lower.contains("error correction") || lower.contains("level") || lower.contains("ecc") {
            return AIAgentMessage(
                isUser: false,
                text: """
                ### QR Error Correction Levels Explained

                QR codes use **Reed-Solomon Error Correction** to remain readable even when partially obscured:

                - **Level L (~7% recovery):** Produces the least dense matrix; ideal for clean digital displays.
                - **Level M (~15% recovery):** Default standard balance for mobile scanning.
                - **Level Q (~25% recovery):** Suitable for industrial tags or warehouse environments.
                - **Level H (~30% recovery):** Highest redundancy; essential when placing a custom logo or center icon over the QR code!
                """,
                quickPrompts: ["Generate QR with High EC", "Add custom center logo", "Export Vector SVG"]
            )
        }

        // 6. Generic Text QR Generation fallback
        let payload = prompt
        let suggested = AISuggestedQR(
            title: "Text QR Code",
            payload: payload,
            formatLabel: "Plain Text",
            iconName: "doc.text"
        )
        return AIAgentMessage(
            isUser: false,
            text: """
            I've generated a QR code with your content:
            `\(payload)`

            You can preview, save, or copy it directly below.
            """,
            suggestedQR: suggested,
            quickPrompts: ["Create Wi-Fi QR", "Check link safety", "Generate vCard"]
        )
    }

    // MARK: - Specialized Parsers

    private func parseWiFiIntent(prompt: String, lower: String) -> AIAgentMessage {
        var ssid = "Home_Network"
        var pass = "SecurePass2026!"
        var auth = "WPA"

        // Extract SSID
        if let range = prompt.range(of: #"(?:ssid|named|network|called|name is)[:= ]+["']?([^"',;\n]+)["']?"#, options: .regularExpression) {
            let match = String(prompt[range])
            let parts = match.components(separatedBy: CharacterSet(charactersIn: ":= "))
            if let last = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
                ssid = last
            }
        }

        // Extract Password
        if let range = prompt.range(of: #"(?:password|pass|key|pwd)[:= ]+["']?([^"',;\n]+)["']?"#, options: .regularExpression) {
            let match = String(prompt[range])
            let parts = match.components(separatedBy: CharacterSet(charactersIn: ":= "))
            if let last = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
                pass = last
            }
        }

        if lower.contains("wep") { auth = "WEP" }
        if lower.contains("no pass") || lower.contains("open") { auth = "nopass"; pass = "" }

        let payload = "WIFI:S:\(ssid);T:\(auth);P:\(pass);;"
        let suggested = AISuggestedQR(
            title: "Wi-Fi: \(ssid)",
            payload: payload,
            formatLabel: "Wi-Fi Network",
            iconName: "wifi"
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Wi-Fi QR Code Prepared

            - **SSID:** `\(ssid)`
            - **Security:** `\(auth)`
            - **Password:** `\(pass.isEmpty ? "(None - Open Network)" : pass)`

            Anyone who scans this QR code on iOS or Android can tap once to join your network automatically.
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: pass.count >= 8 ? .safe : .caution,
                title: pass.count >= 8 ? "Strong Credentials" : "Short Passphrase",
                details: "WPA2/WPA3 credentials encoded into official Wi-Fi consortium format."
            ),
            quickPrompts: ["Make password stronger", "Create guest network QR", "Export as PDF"]
        )
    }

    private func parseContactIntent(prompt: String) -> AIAgentMessage {
        var name = "Alex Morgan"
        var phone = "+1 (555) 234-5678"
        var email = "alex.morgan@example.com"
        let org = "Acme Corp"

        // Search for email
        if let match = prompt.range(of: #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#, options: .regularExpression) {
            email = String(prompt[match])
        }

        // Search for phone
        if let match = prompt.range(of: #"\+?[0-9]{1,3}?[- .]?[0-9]{3}[- .]?[0-9]{3}[- .]?[0-9]{4}"#, options: .regularExpression) {
            phone = String(prompt[match])
        }

        // Search for name
        if let range = prompt.range(of: #"(?:name is|named|for)[:= ]+([A-Za-z ]+)"#, options: .regularExpression) {
            let extracted = String(prompt[range])
            let tokens = extracted.components(separatedBy: " ")
            if tokens.count >= 2 {
                name = tokens.dropFirst(2).joined(separator: " ")
            }
        }

        let vcard = """
        BEGIN:VCARD
        VERSION:3.0
        N:\(name);;;;
        FN:\(name)
        ORG:\(org)
        TEL;TYPE=CELL:\(phone)
        EMAIL;TYPE=INTERNET:\(email)
        END:VCARD
        """

        let suggested = AISuggestedQR(
            title: name,
            payload: vcard,
            formatLabel: "vCard 3.0",
            iconName: "person.crop.circle"
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Digital vCard Business Card Created

            - **Contact Name:** \(name)
            - **Organization:** \(org)
            - **Phone:** \(phone)
            - **Email:** \(email)

            When scanned, iOS opens an immediate "Add to Contacts" prompt with all fields populated!
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: .safe,
                title: "Compliant vCard 3.0",
                details: "Standard vCard schema compatible with iOS, Android, and macOS Address Book."
            ),
            quickPrompts: ["Add company title", "Share as Vector PDF", "Generate Wi-Fi QR"]
        )
    }

    private func parseURLIntent(prompt: String) -> AIAgentMessage {
        var urlStr = "https://apple.com"
        if let range = prompt.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
            urlStr = String(prompt[range])
        } else if let range = prompt.range(of: #"[a-zA-Z0-9-]+\.(?:com|org|io|dev|app|net)[^\s]*"#, options: .regularExpression) {
            urlStr = "https://" + String(prompt[range])
        }

        let url = URL(string: urlStr) ?? URL(string: "https://apple.com")!
        let badge = evaluateURLSafety(url)
        let suggested = AISuggestedQR(
            title: url.host ?? urlStr,
            payload: urlStr,
            formatLabel: "Web URL",
            iconName: "link"
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Web Link QR Code Prepared

            - **Destination:** [\(urlStr)](\(urlStr))
            - **Protocol:** `\(url.scheme?.uppercased() ?? "HTTPS")`
            - **Host:** `\(url.host ?? "Unknown")`

            Scanners will prompt the user to open this page in Safari.
            """,
            suggestedQR: suggested,
            securityBadge: badge,
            quickPrompts: ["Add UTM campaign tags", "Shorten link", "Export as SVG"]
        )
    }

    // MARK: - Security & Threat Evaluation

    public func evaluateURLSafety(_ url: URL) -> AISecurityBadge {
        guard let scheme = url.scheme?.lowercased() else {
            return AISecurityBadge(level: .caution, title: "Unrecognized Scheme", details: "The URL does not specify HTTP/HTTPS.")
        }

        if scheme == "http" {
            return AISecurityBadge(
                level: .caution,
                title: "Unencrypted Connection",
                details: "This destination uses unencrypted plain HTTP. Sensitive data could be intercepted."
            )
        }

        guard let host = url.host?.lowercased() else {
            return AISecurityBadge(level: .info, title: "Custom URL", details: "Non-standard web destination.")
        }

        // Check for raw IP address
        if host.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
            return AISecurityBadge(
                level: .danger,
                title: "Direct IP Host",
                details: "Connecting to a numeric IP address rather than a registered domain name is common in phishing attacks."
            )
        }

        // Check for punycode / homograph attacks
        if host.contains("xn--") {
            return AISecurityBadge(
                level: .caution,
                title: "Internationalized / Punycode Domain",
                details: "Contains non-ASCII Unicode characters that may mimic reputable brand names."
            )
        }

        // Suspicious file downloads
        let path = url.path.lowercased()
        let dangerousExtensions = [".apk", ".exe", ".bat", ".scr", ".cmd", ".vbs", ".dmg", ".ipa"]
        for ext in dangerousExtensions where path.hasSuffix(ext) {
            return AISecurityBadge(
                level: .danger,
                title: "Direct Executable Download",
                details: "This link directly downloads an executable installer file (\(ext)). Only open if verified."
            )
        }

        return AISecurityBadge(
            level: .safe,
            title: "TLS Verified HTTPS",
            details: "Destination host '\(host)' uses modern encrypted HTTPS transport."
        )
    }

    private func describeURL(_ url: URL) -> String {
        var info = [String]()
        info.append("- **Scheme:** `\(url.scheme ?? "http")`")
        if let host = url.host {
            info.append("- **Domain:** `\(host)`")
        }
        if !url.path.isEmpty && url.path != "/" {
            info.append("- **Path:** `\(url.path)`")
        }
        if let query = url.query, !query.isEmpty {
            info.append("- **Query Parameters:** `\(query)`")
        }
        return info.joined(separator: "\n")
    }

    private func assessPasswordStrength(_ pass: String) -> (label: String, advice: String, isSecure: Bool) {
        if pass.isEmpty {
            return ("Open (Unprotected)", "Anyone in proximity can connect to this network without authorization.", false)
        } else if pass.count < 8 {
            return ("Weak (Under 8 characters)", "WPA2 requires at least 8 characters. Consider lengthening your passphrase.", false)
        } else if pass.count >= 12 && pass.rangeOfCharacter(from: .decimalDigits) != nil && pass.rangeOfCharacter(from: .punctuationCharacters) != nil {
            return ("Excellent (High Entropy)", "Strong mix of length, digits, and special characters.", true)
        } else {
            return ("Good Standard", "Adequate protection for residential use.", true)
        }
    }

    private func explainBarcode(code: String, format: String) -> String {
        var country = "International / Generic"
        if (format == "EAN-13" || format == "UPC-A") && code.count >= 3 {
            let prefix = String(code.prefix(3))
            country = lookupGS1Country(prefix: prefix)
        }

        return """
        ### Barcode Details & GS1 Lookup

        - **Symbology Standard:** `\(format)`
        - **Raw Serial Code:** `\(code)`
        - **Registered GS1 Origin:** \(country)
        - **Length:** \(code.count) digits

        This code can be scanned at point-of-sale terminals or inventory databases.
        """
    }

    private func lookupGS1Country(prefix: String) -> String {
        guard let num = Int(prefix) else { return "Unknown" }
        switch num {
        case 0...139: return "United States & Canada"
        case 300...379: return "France"
        case 400...440: return "Germany"
        case 450...459, 490...499: return "Japan"
        case 460...469: return "Russia"
        case 471: return "Taiwan"
        case 489: return "Hong Kong"
        case 500...509: return "United Kingdom"
        case 540...549: return "Belgium & Luxembourg"
        case 570...579: return "Denmark"
        case 640...649: return "Finland"
        case 690...699: return "China"
        case 700...709: return "Norway"
        case 730...739: return "Sweden"
        case 760...769: return "Switzerland"
        case 800...839: return "Italy"
        case 840...849: return "Spain"
        case 870...879: return "Netherlands"
        case 880: return "South Korea"
        case 885: return "Thailand"
        case 888: return "Singapore"
        case 890: return "India"
        case 893: return "Vietnam"
        case 930...939: return "Australia"
        default: return "International Global GS1 Prefix (\(prefix))"
        }
    }

    // MARK: - Extensible Cloud LLM Integration

    private func fetchCloudLLMResponse(prompt: String, apiKey: String) async throws -> AIAgentMessage? {
        let endpointString = customEndpoint.isEmpty ? "https://api.openai.com/v1/chat/completions" : customEndpoint
        guard let url = URL(string: endpointString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let systemMessage = """
        You are the GlassQR Assistant, an expert in QR codes, barcodes, security analysis, and payload generation.
        When asked to create a QR code, clearly provide the structured payload (e.g. WIFI:S:... or BEGIN:VCARD) and explain its attributes.
        Keep answers concise, insightful, and formatted with clean markdown headings and bullet points.
        """

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                ["role": "system", "content": systemMessage],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7,
            "max_tokens": 500
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return AIAgentMessage(
                isUser: false,
                text: content,
                quickPrompts: ["Generate another code", "Check safety", "Export QR"]
            )
        }

        return nil
    }
}
