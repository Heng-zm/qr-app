//
//  AIAgentMessage.swift
//  GlassQR
//
//  Data models for Glass AI Agent conversational interactions,
//  threat assessments, and natural language QR suggestions.
//

import Foundation
import SwiftUI

public struct AIAgentMessage: Identifiable, Equatable {
    public let id: UUID
    public let isUser: Bool
    public var text: String
    public let timestamp: Date
    public var suggestedQR: AISuggestedQR?
    public var securityBadge: AISecurityBadge?
    public var quickPrompts: [String]?

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        timestamp: Date = Date(),
        suggestedQR: AISuggestedQR? = nil,
        securityBadge: AISecurityBadge? = nil,
        quickPrompts: [String]? = nil
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.timestamp = timestamp
        self.suggestedQR = suggestedQR
        self.securityBadge = securityBadge
        self.quickPrompts = quickPrompts
    }
}

public struct AISuggestedQR: Equatable {
    public let title: String
    public let payload: String
    public let formatLabel: String
    public let iconName: String

    public init(title: String, payload: String, formatLabel: String, iconName: String) {
        self.title = title
        self.payload = payload
        self.formatLabel = formatLabel
        self.iconName = iconName
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
