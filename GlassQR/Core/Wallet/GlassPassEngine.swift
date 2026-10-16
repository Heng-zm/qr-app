//
//  GlassPassEngine.swift
//  GlassQR
//
//  Native Apple Wallet Pass Generator Engine & PassKit Package Architecture.
//  Builds Apple Wallet Passes (.pkpass), compiles standard pass.json schemas,
//  and renders high-fidelity digital pass cards for Apple Wallet.
//

import Foundation
import UIKit
import PassKit
import SwiftUI

// MARK: - Pass Styles

public enum WalletPassType: String, CaseIterable, Identifiable, Sendable {
    case eventTicket = "Event Ticket"
    case storeCard = "Loyalty Card"
    case coupon = "Coupon"
    case generic = "Digital Pass"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .eventTicket: return "ticket.fill"
        case .storeCard: return "creditcard.fill"
        case .coupon: return "tag.fill"
        case .generic: return "person.crop.rectangle.fill"
        }
    }

    public var passStyleKey: String {
        switch self {
        case .eventTicket: return "eventTicket"
        case .storeCard: return "storeCard"
        case .coupon: return "coupon"
        case .generic: return "generic"
        }
    }
}

// MARK: - Supported Barcode Formats

public enum WalletBarcodeType: String, CaseIterable, Identifiable, Sendable {
    case qr = "QR Code"
    case code128 = "Code 128"
    case pdf417 = "PDF417"

    public var id: String { rawValue }

    public var pkFormatName: String {
        switch self {
        case .qr: return "PKBarcodeFormatQR"
        case .code128: return "PKBarcodeFormatCode128"
        case .pdf417: return "PKBarcodeFormatPDF417"
        }
    }
}

// MARK: - Pass Color Palettes

public enum WalletPassPalette: String, CaseIterable, Identifiable, Sendable {
    case obsidian = "Obsidian Dark"
    case oceanIndigo = "Ocean Indigo"
    case emeraldVIP = "Emerald VIP"
    case velvetRose = "Velvet Rose"
    case midnightGold = "Midnight Gold"

    public var id: String { rawValue }

    public var bgColor: UIColor {
        switch self {
        case .obsidian: return UIColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        case .oceanIndigo: return UIColor(red: 0.09, green: 0.15, blue: 0.32, alpha: 1.0)
        case .emeraldVIP: return UIColor(red: 0.05, green: 0.22, blue: 0.16, alpha: 1.0)
        case .velvetRose: return UIColor(red: 0.28, green: 0.07, blue: 0.18, alpha: 1.0)
        case .midnightGold: return UIColor(red: 0.18, green: 0.14, blue: 0.06, alpha: 1.0)
        }
    }

    public var accentColor: UIColor {
        switch self {
        case .obsidian: return UIColor(red: 0.35, green: 0.65, blue: 1.0, alpha: 1.0)
        case .oceanIndigo: return UIColor(red: 0.25, green: 0.78, blue: 0.98, alpha: 1.0)
        case .emeraldVIP: return UIColor(red: 0.20, green: 0.88, blue: 0.55, alpha: 1.0)
        case .velvetRose: return UIColor(red: 0.98, green: 0.40, blue: 0.65, alpha: 1.0)
        case .midnightGold: return UIColor(red: 0.98, green: 0.82, blue: 0.35, alpha: 1.0)
        }
    }
}

// MARK: - Pass Configuration Model

public struct WalletPassData: Identifiable, Sendable {
    public var id: UUID = UUID()
    public var type: WalletPassType
    public var organizationName: String
    public var passTitle: String
    public var primaryLabel: String
    public var primaryValue: String
    public var secondaryLabel: String
    public var secondaryValue: String
    public var auxiliaryLabel: String
    public var auxiliaryValue: String
    public var barcodePayload: String
    public var barcodeType: WalletBarcodeType
    public var barcodeAltText: String
    public var palette: WalletPassPalette

    public init(
        type: WalletPassType = .generic,
        organizationName: String = "GlassQR Pass Studio",
        passTitle: String = "Digital Membership",
        primaryLabel: String = "MEMBER",
        primaryValue: String = "Alex Rivera",
        secondaryLabel: String = "TIER",
        secondaryValue: String = "VIP ACCESS",
        auxiliaryLabel: String = "EXPIRES",
        auxiliaryValue: String = "Dec 2026",
        barcodePayload: String = "https://glassqr.app/pass",
        barcodeType: WalletBarcodeType = .qr,
        barcodeAltText: String = "GQR-829104",
        palette: WalletPassPalette = .obsidian
    ) {
        self.type = type
        self.organizationName = organizationName
        self.passTitle = passTitle
        self.primaryLabel = primaryLabel
        self.primaryValue = primaryValue
        self.secondaryLabel = secondaryLabel
        self.secondaryValue = secondaryValue
        self.auxiliaryLabel = auxiliaryLabel
        self.auxiliaryValue = auxiliaryValue
        self.barcodePayload = barcodePayload
        self.barcodeType = barcodeType
        self.barcodeAltText = barcodeAltText
        self.palette = palette
    }
}

// MARK: - PassKit Engine & Exporter

public final class GlassPassEngine: @unchecked Sendable {
    public static let shared = GlassPassEngine()
    private let qrRenderer = CrispQRRenderer()

    public init() {}

    // MARK: - Build pass.json Schema

    public func generatePassJSON(for pass: WalletPassData) -> Data? {
        let bgRgb = rgbString(from: pass.palette.bgColor)
        let fgRgb = "rgb(255, 255, 255)"
        let labelRgb = "rgb(180, 185, 200)"

        let passStructure: [String: Any] = [
            "primaryFields": [
                [
                    "key": "primary",
                    "label": pass.primaryLabel,
                    "value": pass.primaryValue
                ]
            ],
            "secondaryFields": [
                [
                    "key": "secondary",
                    "label": pass.secondaryLabel,
                    "value": pass.secondaryValue
                ]
            ],
            "auxiliaryFields": [
                [
                    "key": "auxiliary",
                    "label": pass.auxiliaryLabel,
                    "value": pass.auxiliaryValue
                ]
            ]
        ]

        let dict: [String: Any] = [
            "formatVersion": 1,
            "passTypeIdentifier": "pass.com.antigravity.glassqr",
            "serialNumber": pass.id.uuidString,
            "teamIdentifier": "GLASSQR2026",
            "organizationName": pass.organizationName,
            "description": pass.passTitle,
            "backgroundColor": bgRgb,
            "foregroundColor": fgRgb,
            "labelColor": labelRgb,
            "barcodes": [
                [
                    "format": pass.barcodeType.pkFormatName,
                    "message": pass.barcodePayload,
                    "messageEncoding": "iso-8859-1",
                    "altText": pass.barcodeAltText
                ]
            ],
            pass.type.passStyleKey: passStructure
        ]

        return try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Package .pkpass Archive

    public func exportPKPassPackage(for pass: WalletPassData) -> URL? {
        guard let jsonData = generatePassJSON(for: pass) else { return nil }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("PassExport_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let passJsonURL = tempDir.appendingPathComponent("pass.json")
        try? jsonData.write(to: passJsonURL)

        // Generate tiny 1x1 icon PNG
        let iconData = createMinimalPNG()
        let iconURL = tempDir.appendingPathComponent("icon.png")
        try? iconData.write(to: iconURL)
        let icon2xURL = tempDir.appendingPathComponent("icon@2x.png")
        try? iconData.write(to: icon2xURL)

        // Zip to .pkpass
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("GlassQR_Pass.pkpass")
        try? FileManager.default.removeItem(at: zipURL)

        if zipDirectory(sourceURL: tempDir, destinationURL: zipURL) {
            try? FileManager.default.removeItem(at: tempDir)
            return zipURL
        }

        return passJsonURL
    }

    // MARK: - High-Resolution Visual Pass Card Renderer (Apple Wallet Card Style)

    public func renderPassCardImage(for pass: WalletPassData) -> UIImage {
        let cardWidth: CGFloat = 750.0
        let cardHeight: CGFloat = 1100.0
        let cardSize = CGSize(width: cardWidth, height: cardHeight)

        let renderer = UIGraphicsImageRenderer(size: cardSize)

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // 1. Draw Pass Background with subtle top-to-bottom shading
            let cardRect = CGRect(origin: .zero, size: cardSize)
            let cornerRadius: CGFloat = 36.0
            let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: cornerRadius)

            cgCtx.saveGState()
            cardPath.addClip()

            let topColor = pass.palette.bgColor
            let bottomColor = pass.palette.bgColor.withAlphaComponent(0.85)

            let cgColors = [topColor.cgColor, bottomColor.cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: [0.0, 1.0]) {
                cgCtx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: cardHeight), options: [])
            }

            // Top specular rim reflection
            let rimPath = UIBezierPath()
            rimPath.move(to: CGPoint(x: cornerRadius, y: 1.5))
            rimPath.addLine(to: CGPoint(x: cardWidth - cornerRadius, y: 1.5))
            UIColor.white.withAlphaComponent(0.25).setStroke()
            rimPath.lineWidth = 2.0
            rimPath.stroke()

            cgCtx.restoreGState()

            // 2. Organization Header
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let orgText = pass.organizationName.uppercased()
            (orgText as NSString).draw(at: CGPoint(x: 44, y: 44), withAttributes: headerAttrs)

            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor.white.withAlphaComponent(0.65)
            ]
            (pass.passTitle as NSString).draw(at: CGPoint(x: 44, y: 76), withAttributes: titleAttrs)

            // Decorative Wallet Icon Badge on Header Right
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
            if let badge = UIImage(systemName: pass.type.icon, withConfiguration: iconConfig)?
                .withTintColor(pass.palette.accentColor, renderingMode: .alwaysOriginal) {
                badge.draw(at: CGPoint(x: cardWidth - 84, y: 44))
            }

            // Divider Line
            let dividerPath = UIBezierPath()
            dividerPath.move(to: CGPoint(x: 44, y: 130))
            dividerPath.addLine(to: CGPoint(x: cardWidth - 44, y: 130))
            UIColor.white.withAlphaComponent(0.12).setStroke()
            dividerPath.lineWidth = 1.0
            dividerPath.stroke()

            // 3. Primary Big Field (e.g., MEMBER NAME / EVENT TITLE)
            let primaryLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: pass.palette.accentColor
            ]
            (pass.primaryLabel.uppercased() as NSString).draw(at: CGPoint(x: 44, y: 160), withAttributes: primaryLabelAttrs)

            let primaryValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 38, weight: .heavy),
                .foregroundColor: UIColor.white
            ]
            (pass.primaryValue as NSString).draw(at: CGPoint(x: 44, y: 185), withAttributes: primaryValueAttrs)

            // 4. Secondary & Auxiliary Fields Row
            let fieldLabelAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.55)
            ]
            let fieldValueAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white
            ]

            // Secondary Field (Left)
            (pass.secondaryLabel.uppercased() as NSString).draw(at: CGPoint(x: 44, y: 260), withAttributes: fieldLabelAttrs)
            (pass.secondaryValue as NSString).draw(at: CGPoint(x: 44, y: 285), withAttributes: fieldValueAttrs)

            // Auxiliary Field (Right)
            let auxRightX: CGFloat = cardWidth - 260
            (pass.auxiliaryLabel.uppercased() as NSString).draw(at: CGPoint(x: auxRightX, y: 260), withAttributes: fieldLabelAttrs)
            (pass.auxiliaryValue as NSString).draw(at: CGPoint(x: auxRightX, y: 285), withAttributes: fieldValueAttrs)

            // 5. White Barcode Container Cutout
            let barcodeCardRect = CGRect(x: 44, y: 350, width: cardWidth - 88, height: 690)
            let barcodeCardPath = UIBezierPath(roundedRect: barcodeCardRect, cornerRadius: 24)
            UIColor.white.setFill()
            barcodeCardPath.fill()

            // Render Barcode / QR inside cutout
            let qrSide: CGFloat = 460.0
            let qrX = barcodeCardRect.midX - (qrSide / 2)
            let qrY = barcodeCardRect.minY + 60.0
            let qrDisplayRect = CGRect(x: qrX, y: qrY, width: qrSide, height: qrSide)

            if let qrImg = qrRenderer.render(
                text: pass.barcodePayload,
                foregroundColor: UIColor.black,
                backgroundColor: UIColor.white,
                correctionLevel: .high,
                dotShape: .squircle,
                eyeFrame: .rounded,
                eyePupil: .squircle
            ) {
                qrImg.draw(in: qrDisplayRect)
            }

            // Barcode Alt Text
            let altTextAttrs: [NSAttributedString.Key: Any] = {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return [
                    .font: UIFont.monospacedSystemFont(ofSize: 20, weight: .bold),
                    .foregroundColor: UIColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0),
                    .paragraphStyle: p
                ]
            }()

            let altRect = CGRect(x: 60, y: qrDisplayRect.maxY + 32, width: cardWidth - 120, height: 34)
            (pass.barcodeAltText as NSString).draw(in: altRect, withAttributes: altTextAttrs)

            // Apple Wallet Brand Indicator
            let walletNoticeAttrs: [NSAttributedString.Key: Any] = {
                let p = NSMutableParagraphStyle()
                p.alignment = .center
                return [
                    .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: UIColor.gray,
                    .paragraphStyle: p
                ]
            }()
            let noticeRect = CGRect(x: 60, y: altRect.maxY + 10, width: cardWidth - 120, height: 24)
            ("Add to Apple Wallet • PassKit Enabled" as NSString).draw(in: noticeRect, withAttributes: walletNoticeAttrs)
        }
    }

    // MARK: - Utilities

    private func rgbString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = Int(r * 255)
        let gi = Int(g * 255)
        let bi = Int(b * 255)
        return "rgb(\(ri), \(gi), \(bi))"
    }

    private func createMinimalPNG() -> Data {
        let size = CGSize(width: 29, height: 29)
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return img.pngData() ?? Data()
    }

    private func zipDirectory(sourceURL: URL, destinationURL: URL) -> Bool {
        var error: NSError?
        let coordinator = NSFileCoordinator()
        var success = false

        coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &error) { zipResultURL in
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: zipResultURL, to: destinationURL)
                success = true
            } catch {
                success = false
            }
        }
        return success
    }
}
