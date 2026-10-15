//
//  FeatureHighlight.swift
//  GlassQR
//

import Foundation

public struct FeatureHighlight: Identifiable, Sendable {
    public let id: String
    public let icon: String
    public let title: String
    public let subtitle: String

    public init(id: String, icon: String, title: String, subtitle: String) {
        self.id = id
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
    }
}
