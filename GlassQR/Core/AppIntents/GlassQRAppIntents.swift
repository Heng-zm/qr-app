//
//  GlassQRAppIntents.swift
//  GlassQR
//
//  Apple AppIntents & Siri Shortcuts Architecture for GlassQR.
//  Enables Siri voice triggers, Shortcuts app automations, and deep-link routing.
//

import AppIntents
import SwiftUI
import UIKit

// MARK: - App Intent Enums

public enum QRThemeIntentEnum: String, AppEnum {
    case obsidian = "Obsidian"
    case cobalt = "Cobalt"
    case emerald = "Emerald"
    case berry = "Berry"
    case slate = "Slate"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "QR Theme"
    public static var caseDisplayRepresentations: [QRThemeIntentEnum: DisplayRepresentation] = [
        .obsidian: "Obsidian Dark",
        .cobalt: "Cobalt Blue",
        .emerald: "Emerald Green",
        .berry: "Berry Pink",
        .slate: "Slate Gray"
    ]

    public var uiColor: UIColor {
        switch self {
        case .obsidian: return UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0)
        case .cobalt: return UIColor(red: 0.04, green: 0.35, blue: 0.85, alpha: 1.0)
        case .emerald: return UIColor(red: 0.08, green: 0.55, blue: 0.32, alpha: 1.0)
        case .berry: return UIColor(red: 0.72, green: 0.12, blue: 0.45, alpha: 1.0)
        case .slate: return UIColor(red: 0.22, green: 0.25, blue: 0.32, alpha: 1.0)
        }
    }
}

public enum QRDotShapeIntentEnum: String, AppEnum {
    case square = "Classic Square"
    case dots = "Circular Dots"
    case squircle = "Squircle"
    case liquid = "Liquid Droplets"

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Dot Shape"
    public static var caseDisplayRepresentations: [QRDotShapeIntentEnum: DisplayRepresentation] = [
        .square: "Classic Square",
        .dots: "Circular Dots",
        .squircle: "Squircle",
        .liquid: "Liquid Droplets"
    ]

    public var dotShape: QRDotShape {
        switch self {
        case .square: return .square
        case .dots: return .dots
        case .squircle: return .squircle
        case .liquid: return .liquid
        }
    }
}

// MARK: - 1. Generate QR Code Intent

public struct GenerateQRCodeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Generate QR Code"
    public static var description = IntentDescription("Generates a vector-sharp QR code image with custom styling from text or link.")

    @Parameter(title: "Content", description: "Text or URL to encode")
    public var content: String

    @Parameter(title: "Theme", default: .obsidian)
    public var theme: QRThemeIntentEnum

    @Parameter(title: "Dot Shape", default: .squircle)
    public var dotShape: QRDotShapeIntentEnum

    public static var parameterSummary: some ParameterSummary {
        Summary("Generate QR Code for \(\.$content)") {
            \.$theme
            \.$dotShape
        }
    }

    public init() {
        self.content = "https://apple.com"
        self.theme = .obsidian
        self.dotShape = .squircle
    }

    public init(content: String, theme: QRThemeIntentEnum = .obsidian, dotShape: QRDotShapeIntentEnum = .squircle) {
        self.content = content
        self.theme = theme
        self.dotShape = dotShape
    }

    public func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let renderer = CrispQRRenderer()
        guard let img = renderer.render(
            text: content,
            foregroundColor: theme.uiColor,
            backgroundColor: .white,
            dotShape: dotShape.dotShape
        ), let pngData = img.pngData() else {
            throw IntentError.message("Failed to generate QR code")
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("GlassQR_\(UUID().uuidString).png")
        try pngData.write(to: tempURL)

        let intentFile = IntentFile(fileURL: tempURL, filename: "GlassQR.png", type: .png)
        return .result(value: intentFile)
    }
}

// MARK: - 2. Scan Clipboard Content Intent

public struct ScanClipboardIntent: AppIntent {
    public static var title: LocalizedStringResource = "Generate QR from Clipboard"
    public static var description = IntentDescription("Reads the clipboard and creates a sharp styled QR code immediately.")

    public init() {}

    @MainActor
    public func perform() async throws -> some ReturnsValue<IntentFile> {
        guard let clipboardString = UIPasteboard.general.string,
              !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw IntentError.message("Clipboard is empty or does not contain text")
        }

        let renderer = CrispQRRenderer()
        guard let img = renderer.render(
            text: clipboardString,
            foregroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1.0),
            backgroundColor: .white,
            dotShape: .squircle,
            eyeFrame: .rounded,
            eyePupil: .squircle
        ), let pngData = img.pngData() else {
            throw IntentError.message("Failed to encode clipboard text")
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("ClipboardQR_\(UUID().uuidString).png")
        try pngData.write(to: tempURL)

        return .result(value: IntentFile(fileURL: tempURL, filename: "ClipboardQR.png", type: .png))
    }
}

// MARK: - 3. Encrypt Secret QR Intent

public struct EncryptToQRIntent: AppIntent {
    public static var title: LocalizedStringResource = "Encrypt Secret to QR"
    public static var description = IntentDescription("Encrypts confidential text with authenticated AES-256 GCM and outputs a steganographic QR code.")

    @Parameter(title: "Secret Text")
    public var secretText: String

    @Parameter(title: "Passcode")
    public var passcode: String

    public init() {
        self.secretText = ""
        self.passcode = ""
    }

    public init(secretText: String, passcode: String) {
        self.secretText = secretText
        self.passcode = passcode
    }

    public func perform() async throws -> some ReturnsValue<IntentFile> {
        let encryptedPayload: String
        do {
            encryptedPayload = try SteganographicQREngine.encrypt(
                secretText: secretText,
                passcode: passcode,
                decoyURL: "https://glassqr.app/vault"
            )
        } catch {
            throw IntentError.message("Encryption failed: \(error.localizedDescription)")
        }

        let renderer = CrispQRRenderer()
        guard let img = renderer.render(
            text: encryptedPayload,
            foregroundColor: UIColor(red: 0.05, green: 0.22, blue: 0.16, alpha: 1.0),
            backgroundColor: .white,
            dotShape: .squircle,
            eyeFrame: .squircle,
            eyePupil: .diamond
        ), let pngData = img.pngData() else {
            throw IntentError.message("Failed to render encrypted QR")
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("VaultQR_\(UUID().uuidString).png")
        try pngData.write(to: tempURL)

        return .result(value: IntentFile(fileURL: tempURL, filename: "EncryptedVaultQR.png", type: .png))
    }
}

// MARK: - 4. Open Camera Scanner Intent

public struct OpenScannerIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open QR Scanner"
    public static var description = IntentDescription("Launches GlassQR directly into camera scanning mode.")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let url = URL(string: "glassqr://scan") {
            await UIApplication.shared.open(url)
        }
        return .result()
    }
}

// MARK: - Siri Shortcuts Provider

public struct GlassQRShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GenerateQRCodeIntent(),
            phrases: [
                "Generate QR code in \(.applicationName)",
                "Create QR with \(.applicationName)",
                "Make a QR code in \(.applicationName)"
            ],
            shortTitle: "Generate QR",
            systemImageName: "qrcode"
        )

        AppShortcut(
            intent: ScanClipboardIntent(),
            phrases: [
                "Create QR from clipboard in \(.applicationName)",
                "Turn clipboard into QR with \(.applicationName)"
            ],
            shortTitle: "Clipboard to QR",
            systemImageName: "doc.on.clipboard"
        )

        AppShortcut(
            intent: OpenScannerIntent(),
            phrases: [
                "Scan with \(.applicationName)",
                "Open camera scanner in \(.applicationName)",
                "Scan QR with \(.applicationName)"
            ],
            shortTitle: "Open Scanner",
            systemImageName: "qrcode.viewfinder"
        )
    }
}

// MARK: - Error Helper

public enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case message(String)

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .message(let text):
            return LocalizedStringResource(stringLiteral: text)
        }
    }
}
