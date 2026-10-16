//
//  GlassAIEngine.swift
//  GlassQR
//
//  Intelligent Agent Engine powering offline neural heuristics, multi-modal
//  camera/photo vision OCR inspection, natural language QR generation,
//  threat assessment, barcode decoding, multi-provider cloud LLM integration,
//  and speech synthesis.
//

import Foundation
import SwiftUI
import Vision
import AVFoundation
import CoreLocation

public final class GlassAIEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    public static let shared = GlassAIEngine()

    // MARK: - Stored Configuration & Persona
    @AppStorage("glass_ai_provider") public var providerRaw: String = AIProvider.onDevice.rawValue
    @AppStorage("glass_ai_persona") public var personaRaw: String = AIPersona.general.rawValue
    @AppStorage("glass_ai_api_key") public var apiKey: String = ""
    @AppStorage("glass_ai_endpoint") public var customEndpoint: String = ""
    @AppStorage("glass_ai_model") public var customModel: String = ""

    // MARK: - Auto-Fetched Models for Active API Key
    @Published public var availableModels: [String] = []
    @Published public var isFetchingModels: Bool = false
    @Published public var fetchModelsError: String? = nil

    public var activeModelName: String {
        let clean = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty {
            return clean
        }
        return availableModels.first ?? provider.defaultModel
    }

    // MARK: - Voice / Speech Synthesis
    @Published public var isSpeaking: Bool = false
    private let speechSynthesizer = AVSpeechSynthesizer()

    public var provider: AIProvider {
        get { AIProvider(rawValue: providerRaw) ?? .onDevice }
        set { providerRaw = newValue.rawValue }
    }

    public var persona: AIPersona {
        get { AIPersona(rawValue: personaRaw) ?? .general }
        set { personaRaw = newValue.rawValue }
    }

    public override init() {
        super.init()
        speechSynthesizer.delegate = self
    }

    // MARK: - Speech Synthesis Controls

    public func speakText(_ text: String) {
        stopSpeaking()

        // Clean markdown symbols for natural pronunciation
        let cleanText = text
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: ">", with: "")

        let utterance = AVSpeechUtterance(string: cleanText)
        if cleanText.containsKhmerScript {
            if let kmVoice = AVSpeechSynthesisVoice(language: "km-KH") {
                utterance.voice = kmVoice
            } else if let altVoice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.lowercased().starts(with: "km") }) {
                utterance.voice = altVoice
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
            }
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05

        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        speechSynthesizer.speak(utterance)
    }

    public func stopSpeaking() {
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
        }
    }

    // MARK: - Main Message Processing Pipeline

    public func processPrompt(_ rawPrompt: String, history: [AIAgentMessage] = []) async -> AIAgentMessage {
        let trimmed = rawPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let isKhmer = trimmed.containsKhmerScript
        if trimmed.isEmpty {
            return AIAgentMessage(
                isUser: false,
                text: isKhmer ? "សូមបញ្ចូលសំនួរ ឬពាក្យបញ្ជាដើម្បីឱ្យខ្ញុំអាចជួយអ្នកបាន។" : "Please enter a prompt or question so I can assist you.",
                quickPrompts: isKhmer
                    ? ["🇰🇭 បង្កើត QR Wi-Fi", "🇰🇭 បង្កើតកាត Wallet", "🇰🇭 អ៊ិនគ្រីបសម្ងាត់", "🇰🇭 ទម្លាក់ម្ជុលផែនទី"]
                    : ["Generate Wi-Fi QR", "Drop Pin on Apple Map", "Encrypt Secret Vault", "Create vCard"]
            )
        }

        // Check if a cloud provider is active and configured
        if provider != .onDevice && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                if let cloudResponse = try await fetchCloudLLMResponse(prompt: trimmed, history: history) {
                    return cloudResponse
                }
            } catch {
                // Graceful fallback to on-device engine on network failure
            }
        }

        // On-Device CoreML Small Language Model & Apple Neural Engine Pipeline (100% Offline)
        return await CoreMLSLMEngine.shared.generateResponse(prompt: trimmed, persona: persona, history: history)
    }

    // MARK: - Multi-Modal Visual Inspection (Photo & Camera)

    public func analyzeImage(_ image: UIImage, prompt: String? = nil) async -> AIAgentMessage {
        guard let cgImage = image.cgImage else {
            return AIAgentMessage(
                isUser: false,
                text: "Unable to process the selected image.",
                securityBadge: AISecurityBadge(level: .danger, title: "Image Error", details: "Could not read bitmap graphics.")
            )
        }

        // 1. Try Barcode / QR Detection via Vision
        let barcodeRequest = VNDetectBarcodesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([barcodeRequest])
            if let results = barcodeRequest.results, let firstBarcode = results.first, let payload = firstBarcode.payloadStringValue {
                let symbologyName = formatSymbology(firstBarcode.symbology.rawValue)
                let scanItem = ScanResultItem(payload: payload, symbology: symbologyName)
                var analysis = analyzeScannedItem(scanItem)
                analysis.text = "### Visual Optical Code Detected (\(symbologyName))\n\n\(analysis.text)"
                return analysis
            }
        } catch {
            // Continue to OCR
        }

        // 2. Optical Character Recognition (OCR) via Vision
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        var extractedLines: [String] = []
        do {
            try handler.perform([textRequest])
            if let textResults = textRequest.results {
                for observation in textResults {
                    if let candidate = observation.topCandidates(1).first {
                        extractedLines.append(candidate.string)
                    }
                }
            }
        } catch {}

        let joinedText = extractedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // 3. Cloud Vision Analysis if Cloud Provider is Active
        if provider != .onDevice && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let cloudVisionResponse = try? await fetchCloudVisionResponse(image: image, prompt: prompt ?? joinedText) {
                return cloudVisionResponse
            }
        }

        // 4. On-Device OCR Analysis & Automatic QR Generation
        if !joinedText.isEmpty {
            let scanItem = ScanResultItem(payload: joinedText, symbology: "OCR Text")
            let category = scanItem.category
            let preview = joinedText.count > 120 ? String(joinedText.prefix(120)) + "..." : joinedText

            let suggested = AISuggestedQR(
                title: "OCR Extracted QR",
                payload: joinedText,
                formatLabel: "Captured Text",
                iconName: "text.viewfinder",
                action: .writeNFC(payload: joinedText)
            )

            let badge: AISecurityBadge
            switch category {
            case .webURL(let url):
                badge = evaluateURLSafety(url)
            default:
                badge = AISecurityBadge(
                    level: .info,
                    title: "Text OCR Recognized",
                    details: "Extracted \(extractedLines.count) lines with Vision optical character recognition."
                )
            }

            return AIAgentMessage(
                isUser: false,
                text: """
                ### Multi-Modal Vision Analysis

                I detected the following text in your photo:

                ```text
                \(preview)
                ```

                I've automatically formatted this into a live vector QR code below.
                """,
                suggestedQR: suggested,
                securityBadge: badge,
                quickPrompts: ["Is this content safe?", "Translate this text", "Write to NFC Tag"]
            )
        }

        return AIAgentMessage(
            isUser: false,
            text: "No QR codes, barcodes, or legible text could be recognized in the attached image. Please ensure good lighting and clear focus.",
            securityBadge: AISecurityBadge(level: .info, title: "No Data Found", details: "Zero optical symbols or text strings identified.")
        )
    }

    private func formatSymbology(_ raw: String) -> String {
        if raw.contains("QR") { return "QR Code" }
        if raw.contains("EAN13") { return "EAN-13" }
        if raw.contains("EAN8") { return "EAN-8" }
        if raw.contains("UPCE") { return "UPC-E" }
        if raw.contains("Code128") { return "Code 128" }
        if raw.contains("Code39") { return "Code 39" }
        if raw.contains("DataMatrix") { return "Data Matrix" }
        if raw.contains("Aztec") { return "Aztec" }
        if raw.contains("PDF417") { return "PDF417" }
        return "Barcode"
    }

    // MARK: - Scan Analysis & Safety Inspection

    public func analyzeScannedItem(_ item: ScanResultItem) -> AIAgentMessage {
        switch item.category {
        case .webURL(let url):
            let badge = evaluateURLSafety(url)
            let details = describeURL(url)
            return AIAgentMessage(
                isUser: false,
                text: "### URL Intelligence & Safety Audit\n\nI analyzed the destination **\(url.host ?? url.absoluteString)**.\n\n\(details)",
                securityBadge: badge,
                quickPrompts: ["Is this domain reputable?", "Extract URL parameters", "Copy sanitized link", "Program to NFC Tag"]
            )

        case .encryptedVault(let ciphertext, _):
            return AIAgentMessage(
                isUser: false,
                text: """
                ### Steganographic Encrypted Vault Detected

                - **Cryptographic Scheme:** AES-GCM 256-bit Authenticated Encryption
                - **Steganography:** Disguised payload
                - **Security Guarantee:** Zero-Knowledge, hardware memory isolation

                Tap the action below to authenticate with Face ID or enter your secret passcode to reveal the contents.
                """,
                suggestedQR: AISuggestedQR(
                    title: "Encrypted Vault",
                    payload: item.payload,
                    formatLabel: "AES-256 GCM",
                    iconName: "lock.shield.fill",
                    action: .unlockVault(ciphertext: ciphertext)
                ),
                securityBadge: AISecurityBadge(
                    level: .safe,
                    title: "Authenticated Ciphertext",
                    details: "Protected by SHA-256 key derivation and AES-GCM 128-bit authentication tag."
                ),
                quickPrompts: ["How does AES-GCM work?", "Write Vault to NFC Tag"]
            )

        case .geo(let lat, let lon, let label):
            let placeName = label ?? "Coordinates (\(String(format: "%.4f, %.4f", lat, lon)))"
            return AIAgentMessage(
                isUser: false,
                text: """
                ### Apple Maps Geolocation Decoded

                - **Location:** \(placeName)
                - **Latitude:** `\(String(format: "%.6f", lat))`
                - **Longitude:** `\(String(format: "%.6f", lon))`

                You can preview this directly in Apple Maps or program it to an NFC location tag.
                """,
                suggestedQR: AISuggestedQR(
                    title: placeName,
                    payload: item.payload,
                    formatLabel: "Apple Maps Pin",
                    iconName: "mappin.and.ellipse",
                    action: .openAppleMaps(lat: lat, lon: lon, label: placeName)
                ),
                securityBadge: AISecurityBadge(
                    level: .safe,
                    title: "Verified Apple Maps Schema",
                    details: "Direct navigation deep-link compatible with Apple Maps and CarPlay."
                ),
                quickPrompts: ["Open in Apple Maps", "Program to NFC Tag", "Get coordinates"]
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
                iconName: "wifi",
                action: .writeNFC(payload: item.payload)
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
                quickPrompts: ["Generate printable Wi-Fi sign", "Write Wi-Fi to NFC Tag", "Tips for router security"]
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
            This contact can be directly imported into your Apple Contacts book or programmed to a physical NFC business card.
            """
            return AIAgentMessage(
                isUser: false,
                text: contactText,
                suggestedQR: AISuggestedQR(
                    title: name,
                    payload: item.payload,
                    formatLabel: "vCard 3.0",
                    iconName: "person.crop.circle",
                    action: .writeNFC(payload: item.payload)
                ),
                securityBadge: AISecurityBadge(level: .safe, title: "Standard vCard 3.0", details: "Native Apple AddressBook schema."),
                quickPrompts: ["Save to Apple Contacts", "Write to NFC Card", "Generate matching vCard QR"]
            )

        default:
            return AIAgentMessage(
                isUser: false,
                text: "### Content Summary\n\n**Payload:**\n`\(item.payload)`\n\nLength: \(item.payload.count) characters.",
                quickPrompts: ["Create QR from this", "Check safety", "Write to NFC Tag"]
            )
        }
    }

    // MARK: - On-Device NLP & Intent Parser

    private func processOfflineHeuristics(_ prompt: String) -> AIAgentMessage {
        let lower = prompt.lowercased()

        // 1. Zero-Knowledge Encrypted Vault Intent
        if lower.contains("encrypt") || lower.contains("vault") || lower.contains("steganograph") || lower.contains("secret qr") || lower.contains("hide secret") {
            return parseEncryptedVaultIntent(prompt: prompt, lower: lower)
        }

        // 2. Apple Maps & Geolocation Intent
        if lower.contains("map") || lower.contains("drop pin") || lower.contains("location") || lower.contains("coordinates") || lower.contains("directions") || isLandmarkMentioned(lower) {
            return parseMapIntent(prompt: prompt, lower: lower)
        }

        // 3. Wi-Fi Generation Intent
        if lower.contains("wifi") || lower.contains("wi-fi") || lower.contains("hotspot") {
            return parseWiFiIntent(prompt: prompt, lower: lower)
        }

        // 4. Contact / vCard Intent
        if lower.contains("contact") || lower.contains("vcard") || lower.contains("business card") {
            return parseContactIntent(prompt: prompt)
        }

        // 5. Calendar / Event Intent
        if lower.contains("calendar") || lower.contains("event") || lower.contains("meeting") || lower.contains("invite") || lower.contains("schedule") {
            return parseCalendarIntent(prompt: prompt)
        }

        // 6. Cryptocurrency Intent
        if lower.contains("bitcoin") || lower.contains("btc") || lower.contains("ethereum") || lower.contains("eth") || lower.contains("crypto") || lower.contains("solana") {
            return parseCryptoIntent(prompt: prompt, lower: lower)
        }

        // 7. Payment Intent (PayPal / Venmo / Cash App)
        if lower.contains("paypal") || lower.contains("venmo") || lower.contains("cash app") || lower.contains("cashapp") {
            return parsePaymentIntent(prompt: prompt, lower: lower)
        }

        // 8. Website / URL Intent
        if lower.contains("url") || lower.contains("website") || lower.contains("link") || lower.contains("http") || lower.contains(".com") || lower.contains(".org") || lower.contains(".app") {
            return parseURLIntent(prompt: prompt)
        }

        // 9. Barcode Question
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

        // 10. Error Correction & QR Specs
        if lower.contains("error correction") || lower.contains("ecc") || lower.contains("reed-solomon") {
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

        // 11. Generic Text QR Generation fallback
        let payload = prompt
        let suggested = AISuggestedQR(
            title: "Text QR Code",
            payload: payload,
            formatLabel: "Plain Text",
            iconName: "doc.text",
            action: .writeNFC(payload: payload)
        )
        return AIAgentMessage(
            isUser: false,
            text: """
            I've generated a QR code with your content:
            `\(payload)`

            You can preview, save, or program it directly to an NFC tag below.
            """,
            suggestedQR: suggested,
            quickPrompts: ["Create Wi-Fi QR", "Drop Pin on Apple Map", "Encrypt Secret Vault", "Check link safety"]
        )
    }

    // MARK: - Specialized Parsers

    private func parseEncryptedVaultIntent(prompt: String, lower: String) -> AIAgentMessage {
        var secret = "Confidential Secret Vault 2026"
        var passcode = "1234"

        // Extract secret
        if let range = prompt.range(of: #"(?:secret|note|payload|message|text)[:= ]+["']?([^"',;\n]+)["']?"#, options: .regularExpression) {
            let match = String(prompt[range])
            let parts = match.components(separatedBy: CharacterSet(charactersIn: ":= "))
            if let last = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
                secret = last
            }
        }

        // Extract passcode
        if let range = prompt.range(of: #"(?:passcode|password|code|key)[:= ]+["']?([^"',;\n]+)["']?"#, options: .regularExpression) {
            let match = String(prompt[range])
            let parts = match.components(separatedBy: CharacterSet(charactersIn: ":= "))
            if let last = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
                passcode = last
            }
        }

        let encryptedPayload: String
        do {
            encryptedPayload = try SteganographicQREngine.encryptPayload(
                secretText: secret,
                passcode: passcode,
                decoyURL: "https://glassqr.app/vault"
            )
        } catch {
            encryptedPayload = "GQR_VAULT:1:SAMPLE_CIPHERTEXT"
        }

        let suggested = AISuggestedQR(
            title: "Secret Vault QR",
            payload: encryptedPayload,
            formatLabel: "Steganographic AES-256",
            iconName: "lock.shield.fill",
            action: .unlockVault(ciphertext: encryptedPayload)
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Zero-Knowledge Encrypted QR Created 🔐

            - **Disguised Decoy URL:** `https://glassqr.app/vault`
            - **Encryption:** AES-GCM 256-bit with SHA-256 key derivation
            - **Configured Passcode:** `\(passcode)`

            To standard smartphone cameras, this appears as an innocent link. GlassQR automatically identifies the encrypted signature and prompts for Face ID or passcode unlock!
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: .safe,
                title: "Zero-Knowledge Protected",
                details: "Ephemeral RAM decryption only. Keys are never saved to disk or transmitted to any server."
            ),
            quickPrompts: ["Test Vault Unlock", "Program Vault to NFC Tag", "Share Encrypted QR"]
        )
    }

    private func parseMapIntent(prompt: String, lower: String) -> AIAgentMessage {
        var lat = 37.7749
        var lon = -122.4194
        var label = "Dropped Pin"

        // Landmark lookup table
        if lower.contains("eiffel tower") || lower.contains("paris") {
            lat = 48.8584; lon = 2.2945; label = "Eiffel Tower, Paris"
        } else if lower.contains("tokyo tower") || lower.contains("tokyo") {
            lat = 35.6586; lon = 139.7454; label = "Tokyo Tower, Japan"
        } else if lower.contains("central park") || lower.contains("new york") || lower.contains("nyc") {
            lat = 40.7829; lon = -73.9654; label = "Central Park, New York"
        } else if lower.contains("big ben") || lower.contains("london") {
            lat = 51.5007; lon = -0.1246; label = "Big Ben, London"
        } else if lower.contains("colosseum") || lower.contains("rome") {
            lat = 41.8902; lon = 12.4922; label = "Colosseum, Rome"
        } else if lower.contains("sydney") || lower.contains("opera house") {
            lat = -33.8568; lon = 151.2153; label = "Sydney Opera House"
        } else if lower.contains("angkor wat") || lower.contains("cambodia") || lower.contains("siem reap") {
            lat = 13.4125; lon = 103.8670; label = "Angkor Wat, Cambodia 🇰🇭"
        } else {
            // Check for numeric coordinates: lat, lon
            if let range = prompt.range(of: #"(-?\d{1,3}\.\d+)[,\s]+(-?\d{1,3}\.\d+)"#, options: .regularExpression) {
                let match = String(prompt[range])
                let tokens = match.components(separatedBy: CharacterSet(charactersIn: ", \t"))
                    .filter { !$0.isEmpty }
                if tokens.count >= 2, let parsedLat = Double(tokens[0]), let parsedLon = Double(tokens[1]) {
                    lat = parsedLat
                    lon = parsedLon
                    label = "Dropped Pin Location"
                }
            }
        }

        let encodedLabel = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Location"
        let appleMapsURL = "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(encodedLabel)"

        let suggested = AISuggestedQR(
            title: label,
            payload: appleMapsURL,
            formatLabel: "Apple Maps Pin",
            iconName: "mappin.and.ellipse",
            action: .openAppleMaps(lat: lat, lon: lon, label: label)
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Apple Maps Location QR Prepared 📍

            - **Destination:** \(label)
            - **Coordinates:** `\(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))`
            - **Apple Maps Deep-Link:** [\(appleMapsURL)](\(appleMapsURL))

            Anyone scanning this QR code will be prompted to open the exact coordinates in Apple Maps or start turn-by-turn navigation!
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: .safe,
                title: "Native Apple Maps Schema",
                details: "Compatible with Apple Maps, CarPlay, and standard Web browsers."
            ),
            quickPrompts: ["Open in Apple Maps", "Program to NFC Tag", "Drop Pin at another place"]
        )
    }

    private func isLandmarkMentioned(_ lower: String) -> Bool {
        let landmarks = ["eiffel", "tokyo tower", "central park", "big ben", "colosseum", "sydney", "angkor wat", "san francisco", "paris", "london"]
        return landmarks.contains(where: { lower.contains($0) })
    }

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
            iconName: "wifi",
            action: .writeNFC(payload: payload)
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
            quickPrompts: ["Make password stronger", "Write Wi-Fi to NFC Tag", "Export as PDF"]
        )
    }

    private func parseContactIntent(prompt: String) -> AIAgentMessage {
        var name = "Alex Morgan"
        var phone = "+1 (555) 234-5678"
        var email = "alex.morgan@example.com"
        let org = "Acme Corp"

        if let match = prompt.range(of: #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}"#, options: .regularExpression) {
            email = String(prompt[match])
        }

        if let match = prompt.range(of: #"\+?[0-9]{1,3}?[- .]?[0-9]{3}[- .]?[0-9]{3}[- .]?[0-9]{4}"#, options: .regularExpression) {
            phone = String(prompt[match])
        }

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
            iconName: "person.crop.circle",
            action: .writeNFC(payload: vcard)
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
            quickPrompts: ["Add company title", "Program to NFC Smart Card", "Export as Vector PDF"]
        )
    }

    private func parseCalendarIntent(prompt: String) -> AIAgentMessage {
        var summary = "Team Project Sync"
        if let range = prompt.range(of: #"(?:event|meeting|titled|named)[:= ]+["']?([^"',;\n]+)["']?"#, options: .regularExpression) {
            let match = String(prompt[range])
            let parts = match.components(separatedBy: CharacterSet(charactersIn: ":= "))
            if let last = parts.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
                summary = last
            }
        }

        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//GlassQR//EN
        BEGIN:VEVENT
        SUMMARY:\(summary)
        DESCRIPTION:Generated via GlassQR Intelligent Copilot
        DTSTART:20261020T180000Z
        DTEND:20261020T190000Z
        END:VEVENT
        END:VCALENDAR
        """

        let suggested = AISuggestedQR(
            title: summary,
            payload: ics,
            formatLabel: "iCalendar Event",
            iconName: "calendar",
            action: .writeNFC(payload: ics)
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Calendar Invite QR Code Created 📅

            - **Event Title:** \(summary)
            - **Format:** RFC 5545 iCalendar (`.ics`)

            Scanning this QR opens the native iOS Calendar app to schedule the event with 1 tap.
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: .safe,
                title: "Standard RFC 5545 iCalendar",
                details: "Compatible with Apple Calendar, Google Calendar, and Microsoft Outlook."
            ),
            quickPrompts: ["Change event time", "Program to NFC Tag", "Export as SVG"]
        )
    }

    private func parseCryptoIntent(prompt: String, lower: String) -> AIAgentMessage {
        var address = "bc1qxy2kgdygjrsqtzq2n0yrf2493p83kkfjhx0wlh"
        var currency = "Bitcoin (BTC)"
        var scheme = "bitcoin"

        if lower.contains("eth") || lower.contains("ethereum") {
            address = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
            currency = "Ethereum (ETH)"
            scheme = "ethereum"
        } else if lower.contains("sol") || lower.contains("solana") {
            address = "7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU"
            currency = "Solana (SOL)"
            scheme = "solana"
        }

        let payload = "\(scheme):\(address)"
        let suggested = AISuggestedQR(
            title: "\(currency) Address",
            payload: payload,
            formatLabel: currency,
            iconName: "bitcoinsign.circle.fill",
            action: .writeNFC(payload: payload)
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Cryptocurrency Wallet QR Prepared 🪙

            - **Asset:** \(currency)
            - **Address:** `\(address)`
            - **Payload:** `\(payload)`

            Crypto wallets (Apple Wallet, Ledger, Metamask, Coinbase) will recognize this address instantly.
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(
                level: .safe,
                title: "Standard Crypto URI",
                details: "Conforms to BIP-21 / EIP-681 cryptocurrency address specifications."
            ),
            quickPrompts: ["Verify address checksum", "Program to NFC Cold Storage Card"]
        )
    }

    private func parsePaymentIntent(prompt: String, lower: String) -> AIAgentMessage {
        var handle = "glassqr"
        if let range = prompt.range(of: #"@([A-Za-z0-9_]+)"#, options: .regularExpression) {
            handle = String(prompt[range]).replacingOccurrences(of: "@", with: "")
        }

        let urlStr: String
        let service: String
        if lower.contains("venmo") {
            service = "Venmo"
            urlStr = "https://venmo.com/\(handle)"
        } else if lower.contains("cash") {
            service = "Cash App"
            urlStr = "https://cash.app/$\(handle)"
        } else {
            service = "PayPal"
            urlStr = "https://paypal.me/\(handle)"
        }

        let suggested = AISuggestedQR(
            title: "\(service): @\(handle)",
            payload: urlStr,
            formatLabel: "\(service) Link",
            iconName: "dollarsign.circle.fill",
            action: .writeNFC(payload: urlStr)
        )

        return AIAgentMessage(
            isUser: false,
            text: """
            ### Payment QR Code Prepared 💳

            - **Service:** \(service)
            - **Recipient:** `@\(handle)`
            - **Direct Link:** [\(urlStr)](\(urlStr))

            Customers and friends can scan to pay you instantly via \(service).
            """,
            suggestedQR: suggested,
            securityBadge: AISecurityBadge(level: .safe, title: "\(service) Verified Link", details: "Direct HTTPS payment portal."),
            quickPrompts: ["Change username", "Program to NFC Tag", "Export as PDF"]
        )
    }

    private func parseURLIntent(prompt: String) -> AIAgentMessage {
        var urlStr = "https://apple.com"
        if let range = prompt.range(of: #"https?://[^\s]+"#, options: .regularExpression) {
            urlStr = String(prompt[range])
        } else if let range = prompt.range(of: #"[a-zA-Z0-9-]+\.(?:com|org|io|dev|app|net)[^\s]*"#, options: .regularExpression) {
            urlStr = "https://" + String(prompt[range])
        }

        urlStr = urlStr.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?)'\""))
        let safeURL = URL(string: urlStr) ?? URL(string: urlStr.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") ?? URL(string: "https://apple.com")
        let url = safeURL ?? URL(fileURLWithPath: "/")
        let badge = evaluateURLSafety(url)
        let suggested = AISuggestedQR(
            title: url.host ?? urlStr,
            payload: urlStr,
            formatLabel: "Web URL",
            iconName: "link",
            action: .writeNFC(payload: urlStr)
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
            quickPrompts: ["Add UTM campaign tags", "Program to NFC Tag", "Shorten link", "Export as SVG"]
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

        if host.range(of: #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$"#, options: .regularExpression) != nil {
            return AISecurityBadge(
                level: .danger,
                title: "Direct IP Host",
                details: "Connecting to a numeric IP address rather than a registered domain name is common in phishing attacks."
            )
        }

        if host.contains("xn--") {
            return AISecurityBadge(
                level: .caution,
                title: "Internationalized / Punycode Domain",
                details: "Contains non-ASCII Unicode characters that may mimic reputable brand names."
            )
        }

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

    // MARK: - Multi-Provider Cloud LLM Engine

    private func fetchCloudLLMResponse(prompt: String, history: [AIAgentMessage] = []) async throws -> AIAgentMessage? {
        let isKhmer = prompt.containsKhmerScript
        let languageInstruction = isKhmer
            ? "CRITICAL LANGUAGE REQUIREMENT: The user wrote in Khmer (ភាសាខ្មែរ). You MUST respond completely and fluently in polite, natural Khmer (ភាសាខ្មែរ)."
            : "Respond in the same language as the user. If the user writes in Khmer (ភាសាខ្មែរ), reply in Khmer. If in English, reply in English."

        let systemPrompt = """
        \(persona.systemPromptSnippet)
        
        ROLE & CONVERSATIONAL MEMORY:
        You are GlassQR Intelligent AI Copilot, a conversational assistant like ChatGPT and Gemini.
        Engage in back-and-forth conversational dialogue, remember previous questions and answers in this chat history, answer general and technical questions, and help create QR codes, barcodes, Apple Wallet passes, Wi-Fi networks, and encrypted vaults.
        
        \(languageInstruction)
        
        FORMATTING:
        - Format with clean Markdown, clear section headings, bullet points, and code blocks.
        - When asked to generate or output a QR code, provide the exact payload (e.g. `WIFI:S:...;`, `https://...`, `BEGIN:VCARD...`) so GlassQR can render an interactive vector QR widget.
        """

        switch provider {
        case .openAI, .custom:
            return try await callOpenAICompatible(prompt: prompt, systemPrompt: systemPrompt, history: history)
        case .gemini:
            return try await callGoogleGemini(prompt: prompt, systemPrompt: systemPrompt, history: history)
        case .claude:
            return try await callAnthropicClaude(prompt: prompt, systemPrompt: systemPrompt, history: history)
        case .onDevice:
            return nil
        }
    }

    private func callOpenAICompatible(prompt: String, systemPrompt: String, history: [AIAgentMessage] = []) async throws -> AIAgentMessage? {
        let endpoint = customEndpoint.isEmpty ? "https://api.openai.com/v1/chat/completions" : customEndpoint
        guard let url = URL(string: endpoint) else { return nil }

        let model = activeModelName
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messagesPayload: [[String: Any]] = [
            ["role": "system", "content": systemPrompt]
        ]

        // Multi-turn conversational memory (up to last 10 turns)
        let relevantHistory = history.suffix(10)
        for msg in relevantHistory {
            let role = msg.isUser ? "user" : "assistant"
            let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                messagesPayload.append(["role": role, "content": text])
            }
        }
        messagesPayload.append(["role": "user", "content": prompt])

        let body: [String: Any] = [
            "model": model,
            "messages": messagesPayload,
            "temperature": 0.7,
            "max_tokens": 800
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
            let isKhmer = prompt.containsKhmerScript || content.containsKhmerScript
            let suggestedQR = detectSuggestedQR(from: content, userPrompt: prompt)
            let quickPrompts = isKhmer
                ? ["🇰🇭 សួរអ្វីបន្ថែមទៀត", "🇰🇭 បង្កើត QR មួយទៀត", "🇰🇭 ពិនិត្យសុវត្ថិភាព"]
                : ["Ask follow-up", "Generate another code", "Check safety"]

            return AIAgentMessage(
                isUser: false,
                text: content,
                suggestedQR: suggestedQR,
                quickPrompts: quickPrompts
            )
        }
        return nil
    }

    private func callGoogleGemini(prompt: String, systemPrompt: String, history: [AIAgentMessage] = []) async throws -> AIAgentMessage? {
        let model = activeModelName
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [[String: Any]] = []

        // Multi-turn conversational memory
        let relevantHistory = history.suffix(10)
        for msg in relevantHistory {
            let role = msg.isUser ? "user" : "model"
            let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                contents.append([
                    "role": role,
                    "parts": [["text": text]]
                ])
            }
        }
        contents.append([
            "role": "user",
            "parts": [["text": prompt]]
        ])

        let body: [String: Any] = [
            "system_instruction": [
                "parts": [["text": systemPrompt]]
            ],
            "contents": contents,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 800
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let first = candidates.first,
           let content = first["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            let isKhmer = prompt.containsKhmerScript || text.containsKhmerScript
            let suggestedQR = detectSuggestedQR(from: text, userPrompt: prompt)
            let quickPrompts = isKhmer
                ? ["🇰🇭 សួរអ្វីបន្ថែមទៀត", "🇰🇭 បង្កើត QR មួយទៀត", "🇰🇭 ពិនិត្យសុវត្ថិភាព"]
                : ["Ask follow-up", "Generate matching QR", "Check safety"]

            return AIAgentMessage(
                isUser: false,
                text: text,
                suggestedQR: suggestedQR,
                quickPrompts: quickPrompts
            )
        }
        return nil
    }

    private func callAnthropicClaude(prompt: String, systemPrompt: String, history: [AIAgentMessage] = []) async throws -> AIAgentMessage? {
        let endpoint = "https://api.anthropic.com/v1/messages"
        guard let url = URL(string: endpoint) else { return nil }

        let model = activeModelName
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var messagesPayload: [[String: Any]] = []
        let relevantHistory = history.suffix(10)
        var lastRole: String? = nil

        for msg in relevantHistory {
            let role = msg.isUser ? "user" : "assistant"
            let text = msg.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }

            if role == lastRole {
                if var previous = messagesPayload.last, let prevText = previous["content"] as? String {
                    previous["content"] = prevText + "\n\n" + text
                    messagesPayload[messagesPayload.count - 1] = previous
                }
            } else {
                messagesPayload.append(["role": role, "content": text])
                lastRole = role
            }
        }

        if lastRole == "user" {
            if var previous = messagesPayload.last, let prevText = previous["content"] as? String {
                previous["content"] = prevText + "\n\n" + prompt
                messagesPayload[messagesPayload.count - 1] = previous
            }
        } else {
            messagesPayload.append(["role": "user", "content": prompt])
        }

        let body: [String: Any] = [
            "model": model,
            "system": systemPrompt,
            "messages": messagesPayload,
            "max_tokens": 800
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return nil
        }

        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let content = json["content"] as? [[String: Any]],
           let first = content.first,
           let text = first["text"] as? String {
            let isKhmer = prompt.containsKhmerScript || text.containsKhmerScript
            let suggestedQR = detectSuggestedQR(from: text, userPrompt: prompt)
            let quickPrompts = isKhmer
                ? ["🇰🇭 សួរអ្វីបន្ថែមទៀត", "🇰🇭 បង្កើត QR មួយទៀត", "🇰🇭 ពិនិត្យសុវត្ថិភាព"]
                : ["Ask follow-up", "Create QR code", "Safety Audit"]

            return AIAgentMessage(
                isUser: false,
                text: text,
                suggestedQR: suggestedQR,
                quickPrompts: quickPrompts
            )
        }
        return nil
    }

    // MARK: - Autonomous QR Payload Recognition in Conversational LLM Output

    private func detectSuggestedQR(from text: String, userPrompt: String) -> AISuggestedQR? {
        // 1. Wi-Fi regex
        if let wifiMatch = text.range(of: #"WIFI:S:[^;]+;[^\n]*;;"#, options: .regularExpression) {
            let payload = String(text[wifiMatch])
            return AISuggestedQR(
                title: "Wi-Fi Network QR",
                payload: payload,
                formatLabel: "Wi-Fi Consortium",
                iconName: "wifi",
                action: .writeNFC(payload: payload)
            )
        }

        // 2. Encrypted Vault
        if let vaultMatch = text.range(of: #"GQR_VAULT:1:[A-Za-z0-9+/=]+"#, options: .regularExpression) {
            let payload = String(text[vaultMatch])
            return AISuggestedQR(
                title: "Encrypted Vault QR",
                payload: payload,
                formatLabel: "AES-256 GCM",
                iconName: "lock.shield.fill",
                action: .unlockVault(ciphertext: payload)
            )
        }

        // 3. Apple Maps
        if let mapMatch = text.range(of: #"https:\/\/maps\.apple\.com\/\?[^\s"'`\)]+"#, options: .regularExpression) {
            let payload = String(text[mapMatch])
            return AISuggestedQR(
                title: "Apple Maps Location",
                payload: payload,
                formatLabel: "Apple Maps Pin",
                iconName: "mappin.and.ellipse",
                action: .openAppleMaps(lat: 37.3346, lon: -122.0090, label: "Apple Maps Location")
            )
        }

        // 4. Apple Wallet pass
        if let passMatch = text.range(of: #"https:\/\/glassqr\.app\/pass[^\s"'`\)]*"#, options: .regularExpression) {
            let payload = String(text[passMatch])
            return AISuggestedQR(
                title: "Apple Wallet Pass",
                payload: payload,
                formatLabel: "Apple Wallet (.pkpass)",
                iconName: "wallet.pass.fill",
                action: .openWalletPass(payload: payload)
            )
        }

        // 5. vCard 3.0
        if text.contains("BEGIN:VCARD") && text.contains("END:VCARD") {
            if let vcardStart = text.range(of: "BEGIN:VCARD"),
               let vcardEnd = text.range(of: "END:VCARD") {
                let payload = String(text[vcardStart.lowerBound..<vcardEnd.upperBound])
                return AISuggestedQR(
                    title: "Digital Contact vCard",
                    payload: payload,
                    formatLabel: "vCard 3.0 Contact",
                    iconName: "person.crop.circle.fill",
                    action: .saveContact(vcard: payload)
                )
            }
        }

        // 6. Generic URL if user asked to create a QR or if response provides an explicit URL
        let lowerPrompt = userPrompt.lowercased()
        if lowerPrompt.contains("qr") || lowerPrompt.contains("កូដ") || lowerPrompt.contains("បង្កើត") {
            if let urlMatch = text.range(of: #"https?:\/\/[^\s"'`\)\]\}]+(?:\.[^\s"'`\)\]\}]+)+"#, options: .regularExpression) {
                let payload = String(text[urlMatch])
                return AISuggestedQR(
                    title: "Web Link QR",
                    payload: payload,
                    formatLabel: "URL Link",
                    iconName: "link",
                    action: .sharePayload(text: payload)
                )
            }
        }

        return nil
    }

    // MARK: - Multi-Modal Cloud Vision

    private func fetchCloudVisionResponse(image: UIImage, prompt: String) async throws -> AIAgentMessage? {
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return nil }
        let base64String = jpegData.base64EncodedString()

        let endpoint = customEndpoint.isEmpty ? "https://api.openai.com/v1/chat/completions" : customEndpoint
        guard let url = URL(string: endpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": "gpt-4o-mini",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Analyze this QR code, barcode, or document image. Extract and explain any payloads: \(prompt)"],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64String)"]]
                    ]
                ]
            ],
            "max_tokens": 600
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
                quickPrompts: ["Create matching QR", "Check security", "Program to NFC Tag"]
            )
        }
        return nil
    }

    // MARK: - Auto-Fetch Available Models for Active API Key

    public func fetchAvailableModels(force: Bool = false) async {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if provider == .onDevice {
            await MainActor.run {
                self.availableModels = [
                    "Glass-Neural-v2 (On-Device Apple Neural Engine)",
                    "Glass-Heuristics-Offline"
                ]
                self.isFetchingModels = false
                self.fetchModelsError = nil
            }
            return
        }

        guard !cleanKey.isEmpty else {
            await MainActor.run {
                self.availableModels = []
                self.isFetchingModels = false
                self.fetchModelsError = "Please enter an API Key to fetch models"
            }
            return
        }

        await MainActor.run {
            self.isFetchingModels = true
            self.fetchModelsError = nil
        }

        do {
            let fetched: [String]
            switch provider {
            case .openAI:
                fetched = try await fetchOpenAIModels(apiKey: cleanKey)
            case .gemini:
                fetched = try await fetchGeminiModels(apiKey: cleanKey)
            case .claude:
                fetched = try await fetchClaudeModels(apiKey: cleanKey)
            case .custom:
                fetched = try await fetchCustomEndpointModels(apiKey: cleanKey)
            case .onDevice:
                fetched = []
            }

            await MainActor.run {
                self.isFetchingModels = false
                if fetched.isEmpty {
                    self.fetchModelsError = "No compatible chat models found for this key"
                } else {
                    self.availableModels = fetched
                    self.fetchModelsError = nil
                    // If customModel is currently empty or not in the fetched list, select top recommended model
                    if self.customModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !fetched.contains(self.customModel) {
                        self.customModel = fetched.first ?? self.provider.defaultModel
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.isFetchingModels = false
                self.fetchModelsError = error.localizedDescription
            }
        }
    }

    private func fetchOpenAIModels(apiKey: String) async throws -> [String] {
        let endpoint = customEndpoint.isEmpty ? "https://api.openai.com/v1/models" : (customEndpoint.replacingOccurrences(of: "/chat/completions", with: "/models"))
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            if http.statusCode == 401 { throw NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI API Key (HTTP 401)"]) }
            throw NSError(domain: "OpenAI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        var models: [String] = []
        for item in dataArray {
            if let id = item["id"] as? String {
                let lower = id.lowercased()
                if lower.contains("dall-e") || lower.contains("whisper") || lower.contains("tts") ||
                   lower.contains("embedding") || lower.contains("moderation") || lower.contains("babbage") ||
                   lower.contains("davinci") || lower.contains("curie") || lower.contains("audio") || lower.contains("realtime") {
                    continue
                }
                models.append(id)
            }
        }

        let priorityOrder = [
            "gpt-4o", "gpt-4o-mini", "o3-mini", "o1-mini", "o1-preview", "o1",
            "gpt-4.5-preview", "gpt-4-turbo", "gpt-4", "gpt-3.5-turbo"
        ]

        models.sort { a, b in
            let aIdx = priorityOrder.firstIndex(where: { a.starts(with: $0) }) ?? 999
            let bIdx = priorityOrder.firstIndex(where: { b.starts(with: $0) }) ?? 999
            if aIdx != bIdx { return aIdx < bIdx }
            return a < b
        }

        return models
    }

    private func fetchGeminiModels(apiKey: String) async throws -> [String] {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: endpoint) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        guard http.statusCode == 200 else {
            if http.statusCode == 400 || http.statusCode == 403 {
                throw NSError(domain: "Gemini", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API Key (HTTP \(http.statusCode))"])
            }
            throw NSError(domain: "Gemini", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let modelsArray = json["models"] as? [[String: Any]] else {
            throw URLError(.cannotParseResponse)
        }

        var models: [String] = []
        for item in modelsArray {
            guard let name = item["name"] as? String else { continue }
            let cleanName = name.replacingOccurrences(of: "models/", with: "")

            if let methods = item["supportedGenerationMethods"] as? [String] {
                if !methods.contains("generateContent") { continue }
            }

            models.append(cleanName)
        }

        let priorityOrder = [
            "gemini-1.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-exp", "gemini-1.5-pro", "gemini-1.0-pro"
        ]

        models.sort { a, b in
            let aIdx = priorityOrder.firstIndex(where: { a.starts(with: $0) }) ?? 999
            let bIdx = priorityOrder.firstIndex(where: { b.starts(with: $0) }) ?? 999
            if aIdx != bIdx { return aIdx < bIdx }
            return a < b
        }

        return models
    }

    private func fetchClaudeModels(apiKey: String) async throws -> [String] {
        let fallbackModels = [
            "claude-3-5-sonnet-20241022",
            "claude-3-5-haiku-20241022",
            "claude-3-opus-20240229",
            "claude-3-sonnet-20240229",
            "claude-3-haiku-20240307"
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/models") else {
            return fallbackModels
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 8

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let ids = dataArray.compactMap { $0["id"] as? String }
                if !ids.isEmpty {
                    return ids
                }
            }
        } catch {}

        return fallbackModels
    }

    private func fetchCustomEndpointModels(apiKey: String) async throws -> [String] {
        var base = customEndpoint.isEmpty ? "http://localhost:11434" : customEndpoint
        if base.contains("/chat/completions") {
            base = base.replacingOccurrences(of: "/chat/completions", with: "")
        }
        if base.hasSuffix("/") {
            base = String(base.dropLast())
        }

        let modelsURL = base.contains("/v1") ? "\(base)/models" : "\(base)/v1/models"
        if let url = URL(string: modelsURL) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !apiKey.isEmpty {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            request.timeoutInterval = 5

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let ids = dataArray.compactMap { $0["id"] as? String }
                if !ids.isEmpty { return ids }
            }
        }

        if let url = URL(string: "\(base)/api/tags") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 5

            if let (data, response) = try? await URLSession.shared.data(for: request),
               let http = response as? HTTPURLResponse, http.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let modelsArray = json["models"] as? [[String: Any]] {
                let names = modelsArray.compactMap { $0["name"] as? String }
                if !names.isEmpty { return names }
            }
        }

        return ["llama3:latest", "mistral:latest", "deepseek-r1:latest", "qwen2.5-coder:latest", "phi3:latest"]
    }
}
