//
//  ScanResultItem.swift
//  GlassQR
//

import Foundation

public struct ScanResultItem: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let payload: String
    public let timestamp: Date

    public init(id: UUID = UUID(), payload: String, timestamp: Date = Date()) {
        self.id = id
        self.payload = payload
        self.timestamp = timestamp
    }

    public var isWebURL: Bool {
        guard let url = URL(string: payload),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
