//
//  AIAgentMessage.swift
//  GlassQR
//
//  Data models for Glass AI Agent conversational interactions,
//  multi-modal visual inspection, threat assessments, personas, and smart actions.
//

import Foundation
import SwiftUI

// MARK: - AI Persona Modes

public enum AIPersona: String, CaseIterable, Identifiable, Codable {
    case general = "Copilot"
    case security = "Security Guard"
    case designer = "QR Architect"
    case privacy = "Vault & Privacy"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "sparkles"
        case .security: return "shield.lefthalf.filled"
        case .designer: return "paintpalette.fill"
        case .privacy: return "lock.shield.fill"
        }
    }

    public var tint: Color {
        switch self {
        case .general: return .cyan
        case .security: return .green
        case .designer: return .purple
        case .privacy: return .orange
        }
    }

    public var subtitle: String {
        switch self {
        case .general: return "General Assistant & Generator"
        case .security: return "Link Safety & Phishing Auditor"
        case .designer: return "Aesthetics & Error Correction"
        case .privacy: return "AES Vaults & Steganography"
        }
    }

    public var systemPromptSnippet: String {
        switch self {
        case .general:
            return "You are GlassQR Copilot, an expert in QR codes, barcodes, security, and payload design."
        case .security:
            return "You are GlassQR Security Guard. Prioritize detecting phishing, zero-day links, tracking parameters, malicious file extensions, and insecure connections. Provide strict safety verdicts."
        case .designer:
            return "You are GlassQR QR Architect. Advise on error correction, vector scalability, branding, color contrast, and optimal QR layouts for print and digital media."
        case .privacy:
            return "You are GlassQR Vault & Privacy Guard. Focus on zero-knowledge encryption, steganography, ephemeral payloads, Wi-Fi security, and private cryptographic seed preservation."
        }
    }
}

// MARK: - AI Cloud & On-Device Providers

public enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case onDevice = "On-Device Neural Engine"
    case openAI = "OpenAI (GPT-4o)"
    case gemini = "Google Gemini"
    case claude = "Anthropic Claude"
    case custom = "Custom / Ollama / Local"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .onDevice: return "Glass-Neural-v2"
        case .openAI: return "gpt-4o-mini"
        case .gemini: return "gemini-1.5-flash"
        case .claude: return "claude-3-5-sonnet-20241022"
        case .custom: return "llama3"
        }
    }

    public var icon: String {
        switch self {
        case .onDevice: return "cpu"
        case .openAI: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .claude: return "wand.and.stars"
        case .custom: return "server.rack"
        }
    }
}

// MARK: - One-Tap Quick Actions

public enum AIQuickAction: Equatable {
    case writeNFC(payload: String)
    case openAppleMaps(lat: Double, lon: Double, label: String)
    case unlockVault(ciphertext: String)
    case saveContact(vcard: String)
    case sharePayload(text: String)

    public var label: String {
        switch self {
        case .writeNFC: return "Program to NFC Tag"
        case .openAppleMaps: return "Open in Apple Maps"
        case .unlockVault: return "Unlock in Vault Studio"
        case .saveContact: return "Save to Apple Contacts"
        case .sharePayload: return "Share Payload"
        }
    }

    public var icon: String {
        switch self {
        case .writeNFC: return "wave.3.forward"
        case .openAppleMaps: return "map.fill"
        case .unlockVault: return "lock.open.fill"
        case .saveContact: return "person.crop.circle.badge.plus"
        case .sharePayload: return "square.and.arrow.up"
        }
    }
}

// MARK: - Core AI Message Models

public struct AIAgentMessage: Identifiable, Equatable {
    public let id: UUID
    public let isUser: Bool
    public var text: String
    public let timestamp: Date
    public var suggestedQR: AISuggestedQR?
    public var securityBadge: AISecurityBadge?
    public var quickPrompts: [String]?
    public var attachedImageData: Data?
    public var suggestedAction: AIQuickAction?

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        suggestedQR: AISuggestedQR? = nil,
        securityBadge: AISecurityBadge? = nil,
        quickPrompts: [String]? = nil,
        attachedImageData: Data? = nil,
        suggestedAction: AIQuickAction? = nil
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.suggestedQR = suggestedQR
        self.securityBadge = securityBadge
        self.quickPrompts = quickPrompts
        self.attachedImageData = attachedImageData
        self.suggestedAction = suggestedAction
    }
}

public struct AISuggestedQR: Equatable {
    public let title: String
    public let payload: String
    public let formatLabel: String
    public let iconName: String
    public var action: AIQuickAction?

    public init(
        title: String,
        payload: String,
        formatLabel: String,
        iconName: String,
        action: AIQuickAction? = nil
    ) {
        self.title = title
        self.payload = payload
        self.formatLabel = formatLabel
        self.iconName = iconName
        self.action = action
    }
}

public struct AISecurityBadge: Equatable {
    public enum Level: String, Equatable {
        case safe = "Safe & Verified"
        case caution = "Caution Recommended"
        case danger = "Potential Threat"
        case info = "Informational Analysis"

        public var icon: String {
            switch self {
            case .safe: return "checkmark.shield.fill"
            case .caution: return "exclamationmark.shield.fill"
            case .danger: return "xmark.shield.fill"
            case .info: return "info.circle.fill"
            }
        }

        public var color: Color {
            switch self {
            case .safe: return .green
            case .caution: return .orange
            case .danger: return .red
            case .info: return .cyan
            }
        }
    }

    public let level: Level
    public let title: String
    public let details: String

    public init(level: Level, title: String, details: String) {
        self.level = level
        self.title = title
        self.details = details
    }
}
