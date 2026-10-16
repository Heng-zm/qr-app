//
//  CrispQRRenderer.swift
//  GlassQR
//
//  Vector QR Rendering Engine with Liquid Dot Modules, Specular Caustics,
//  Custom Finder Eyes, Multi-Color Gradients, and Infinite Vector SVG/PDF Exports.
//

import UIKit
@preconcurrency import CoreImage
import CoreImage.CIFilterBuiltins

// MARK: - QR Error Correction Level

public enum QRErrorCorrectionLevel: String, CaseIterable, Identifiable, Sendable {
    case low = "L"
    case medium = "M"
    case quartile = "Q"
    case high = "H"

    public var id: String { rawValue }

    public var recoveryPercentage: String {
        switch self {
        case .low: return "7%"
        case .medium: return "15%"
        case .quartile: return "25%"
        case .high: return "30%"
        }
    }

    public var title: String {
        switch self {
        case .low: return "Low (7%)"
        case .medium: return "Medium (15%)"
        case .quartile: return "Quartile (25%)"
        case .high: return "High (30%)"
        }
    }

    public var label: String {
        rawValue
    }
}

// MARK: - Liquid Dot Module Shapes

public enum QRDotShape: String, CaseIterable, Identifiable, Sendable {
    case square = "Classic"
    case dots = "Circles"
    case squircle = "Squircle"
    case liquid = "Liquid"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .square: return "square.fill"
        case .dots: return "circle.fill"
        case .squircle: return "app.fill"
        case .liquid: return "drop.fill"
        }
    }
}

// MARK: - Finder Pattern Eye Frame Shapes

public enum QREyeFrameStyle: String, CaseIterable, Identifiable, Sendable {
    case square = "Square"
    case rounded = "Rounded"
    case circle = "Circle"
    case squircle = "Squircle"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .square: return "square"
        case .rounded: return "rectangle.roundedtop"
        case .circle: return "circle"
        case .squircle: return "app"
        }
    }
}

// MARK: - Finder Pattern Eye Eyeball Shapes

public enum QREyePupilStyle: String, CaseIterable, Identifiable, Sendable {
    case square = "Square"
    case circle = "Dot"
    case squircle = "Squircle"
    case diamond = "Diamond"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .square: return "square.fill"
        case .circle: return "circle.fill"
        case .squircle: return "app.fill"
        case .diamond: return "rhombus.fill"
        }
    }
}

// MARK: - Multi-Color Chromatic Gradients

public enum QRColorGradient: String, CaseIterable, Identifiable, Sendable {
    case none = "Solid"
    case electricIndigo = "Electric"
    case oceanCyan = "Ocean"
    case sunsetAmber = "Sunset"
    case emeraldMint = "Emerald"
    case liquidMagenta = "Magenta"

    public var id: String { rawValue }

    public var colors: [UIColor] {
        switch self {
        case .none:
            return []
        case .electricIndigo:
            return [
                UIColor(red: 0.31, green: 0.27, blue: 0.90, alpha: 1.0),
                UIColor(red: 0.58, green: 0.20, blue: 0.92, alpha: 1.0)
            ]
        case .oceanCyan:
            return [
                UIColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1.0),
                UIColor(red: 0.23, green: 0.51, blue: 0.96, alpha: 1.0)
            ]
        case .sunsetAmber:
            return [
                UIColor(red: 0.96, green: 0.25, blue: 0.37, alpha: 1.0),
                UIColor(red: 0.98, green: 0.57, blue: 0.24, alpha: 1.0)
            ]
        case .emeraldMint:
            return [
                UIColor(red: 0.06, green: 0.73, blue: 0.51, alpha: 1.0),
                UIColor(red: 0.02, green: 0.71, blue: 0.83, alpha: 1.0)
            ]
        case .liquidMagenta:
            return [
                UIColor(red: 0.93, green: 0.28, blue: 0.60, alpha: 1.0),
                UIColor(red: 0.55, green: 0.36, blue: 0.96, alpha: 1.0)
            ]
        }
    }
}

// MARK: - "Scan Me" Card Frame Styles

public enum QRCardFrameStyle: String, CaseIterable, Identifiable, Sendable {
    case none = "None"
    case scanMe = "Scan Me"
    case connectWifi = "Join Wi-Fi"
    case payNow = "Pay"
    case glassCard = "Glass Card"

    public var id: String { rawValue }

    public var bannerText: String? {
        switch self {
        case .none: return nil
        case .scanMe: return "SCAN ME"
        case .connectWifi: return "JOIN WI-FI"
        case .payNow: return "SCAN TO PAY"
        case .glassCard: return "SCAN WITH CAMERA"
        }
    }
}

// MARK: - Main Vector QR Renderer Engine

public final class CrispQRRenderer: @unchecked Sendable {
    private let context = CIContext()

    public init() {}

    // MARK: - High-Resolution Raster Rendering with Liquid Dot & Eye Styling

    public func render(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        centerIconName: String? = nil,
        customLogo: UIImage? = nil,
        correctionLevel: QRErrorCorrectionLevel = .high,
        dotShape: QRDotShape = .square,
        eyeFrame: QREyeFrameStyle = .square,
        eyePupil: QREyePupilStyle = .square,
        gradient: QRColorGradient = .none,
        cardFrame: QRCardFrameStyle = .none
    ) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        // Force High or Quartile recovery if a center logo or badge is requested
        let effectiveLevel: String
        if customLogo != nil || (centerIconName != nil && !centerIconName!.isEmpty) {
            effectiveLevel = (correctionLevel == .low || correctionLevel == .medium) ? "H" : correctionLevel.rawValue
        } else {
            effectiveLevel = correctionLevel.rawValue
        }
        filter.setValue(effectiveLevel, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        let matrixWidth = cgImage.width
        let matrixHeight = cgImage.height

        guard let pixelData = cgImage.dataProvider?.data,
              let dataPtr = CFDataGetBytePtr(pixelData) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // Bitmatrix closure
        func isDark(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < matrixWidth, y >= 0, y < matrixHeight else { return false }
            let offset = y * bytesPerRow + x * bytesPerPixel
            return dataPtr[offset] < 128
        }

        // Helpers to detect finder patterns
        func isEyeArea(_ x: Int, _ y: Int) -> Bool {
            (x < 7 && y < 7) ||
            (x >= matrixWidth - 7 && y < 7) ||
            (x < 7 && y >= matrixHeight - 7)
        }

        // Detect center logo exclusion zone
        let hasCenterLogo = (customLogo != nil) || (centerIconName != nil && !centerIconName!.isEmpty)
        let centerMinX = (matrixWidth - 7) / 2
        let centerMaxX = centerMinX + 7
        let centerMinY = (matrixHeight - 7) / 2
        let centerMaxY = centerMinY + 7

        func isCenterExclusion(_ x: Int, _ y: Int) -> Bool {
            guard hasCenterLogo else { return false }
            return x >= centerMinX && x < centerMaxX && y >= centerMinY && y < centerMaxY
        }

        // Canvas sizing
        let qrSide: CGFloat = 800.0
        let moduleSide = qrSide / CGFloat(matrixWidth)

        let extraBottomMargin: CGFloat = cardFrame.bannerText != nil ? 110.0 : 0.0
        let framePadding: CGFloat = cardFrame != .none ? 44.0 : 20.0
        let canvasWidth = qrSide + (framePadding * 2)
        let canvasHeight = qrSide + (framePadding * 2) + extraBottomMargin
        let canvasSize = CGSize(width: canvasWidth, height: canvasHeight)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { ctx in
            let cgCtx = ctx.cgContext

            // 1. Draw Canvas Background
            backgroundColor.setFill()
            cgCtx.fill(CGRect(origin: .zero, size: canvasSize))

            // 2. If Card Frame is active, draw subtle card perimeter
            let qrOrigin = CGPoint(x: framePadding, y: framePadding)
            let qrRect = CGRect(origin: qrOrigin, size: CGSize(width: qrSide, height: qrSide))

            if cardFrame != .none {
                let cardRect = CGRect(x: 14, y: 14, width: canvasWidth - 28, height: canvasHeight - 28)
                let cardPath = UIBezierPath(roundedRect: cardRect, cornerRadius: 28)
                UIColor.black.withAlphaComponent(0.04).setStroke()
                cardPath.lineWidth = 2.0
                cardPath.stroke()
            }

            // 3. Assemble all vector paths (Data modules + Finder Eyes)
            let compoundPath = UIBezierPath()

            // A. Draw Data Modules
            for y in 0..<matrixHeight {
                for x in 0..<matrixWidth {
                    if isEyeArea(x, y) || isCenterExclusion(x, y) { continue }
                    if isDark(x, y) {
                        let modRect = CGRect(
                            x: qrOrigin.x + (CGFloat(x) * moduleSide),
                            y: qrOrigin.y + (CGFloat(y) * moduleSide),
                            width: moduleSide,
                            height: moduleSide
                        )
                        appendDot(to: compoundPath, rect: modRect, shape: dotShape, moduleSide: moduleSide)
                    }
                }
            }

            // B. Draw Finder Pattern Eyes (Top-Left, Top-Right, Bottom-Left)
            let eyeOrigins = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: matrixWidth - 7, y: 0),
                CGPoint(x: 0, y: matrixHeight - 7)
            ]

            for eye in eyeOrigins {
                let eyeRect = CGRect(
                    x: qrOrigin.x + (eye.x * moduleSide),
                    y: qrOrigin.y + (eye.y * moduleSide),
                    width: 7 * moduleSide,
                    height: 7 * moduleSide
                )
                appendFinderEye(
                    to: compoundPath,
                    bounds: eyeRect,
                    frameStyle: eyeFrame,
                    pupilStyle: eyePupil,
                    moduleSide: moduleSide
                )
            }

            // 4. Fill with Solid Color or Chromatic Gradient
            cgCtx.saveGState()
            if gradient != .none && !gradient.colors.isEmpty {
                cgCtx.addPath(compoundPath.cgPath)
                cgCtx.clip()

                let cgColors = gradient.colors.map { $0.cgColor } as CFArray
                if let cgGrad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: cgColors,
                    locations: [0.0, 1.0]
                ) {
                    cgCtx.drawLinearGradient(
                        cgGrad,
                        start: CGPoint(x: qrRect.minX, y: qrRect.minY),
                        end: CGPoint(x: qrRect.maxX, y: qrRect.maxY),
                        options: []
                    )
                }
            } else {
                foregroundColor.setFill()
                compoundPath.fill()
            }
            cgCtx.restoreGState()

            // 5. Draw "Scan Me" Banner if requested
            if let banner = cardFrame.bannerText {
                let bannerWidth = qrSide * 0.72
                let bannerHeight: CGFloat = 46.0
                let bannerRect = CGRect(
                    x: (canvasWidth - bannerWidth) / 2,
                    y: qrRect.maxY + 24.0,
                    width: bannerWidth,
                    height: bannerHeight
                )

                let pillPath = UIBezierPath(roundedRect: bannerRect, cornerRadius: bannerHeight / 2)
                let bannerColor = gradient != .none && !gradient.colors.isEmpty ? gradient.colors.first! : foregroundColor
                bannerColor.setFill()
                pillPath.fill()

                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]

                let textRect = CGRect(
                    x: bannerRect.minX,
                    y: bannerRect.minY + 12.0,
                    width: bannerRect.width,
                    height: bannerHeight
                )
                (banner as NSString).draw(in: textRect, withAttributes: attrs)
            }

            // 6. Draw Center Logo or Badge on top
            if let logo = customLogo {
                drawCenterLogo(in: qrRect, logo: logo)
            } else if let icon = centerIconName, !icon.isEmpty {
                let badgeColor = gradient != .none && !gradient.colors.isEmpty ? gradient.colors.first! : foregroundColor
                drawCenterBadge(in: qrRect, iconName: icon, tintColor: badgeColor)
            }
        }
    }

    // MARK: - Helper Module Shape Path Appenders

    private func appendDot(to path: UIBezierPath, rect: CGRect, shape: QRDotShape, moduleSide: CGFloat) {
        switch shape {
        case .square:
            path.append(UIBezierPath(rect: rect))

        case .dots:
            let inset = moduleSide * 0.08
            path.append(UIBezierPath(ovalIn: rect.insetBy(dx: inset, dy: inset)))

        case .squircle:
            let inset = moduleSide * 0.04
            let radius = moduleSide * 0.32
            path.append(UIBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset), cornerRadius: radius))

        case .liquid:
            let inset = moduleSide * 0.06
            let r = rect.insetBy(dx: inset, dy: inset)
            let radius = r.width * 0.44
            path.append(UIBezierPath(roundedRect: r, cornerRadius: radius))
        }
    }

    // MARK: - Helper Finder Eye Path Appender

    private func appendFinderEye(
        to path: UIBezierPath,
        bounds: CGRect,
        frameStyle: QREyeFrameStyle,
        pupilStyle: QREyePupilStyle,
        moduleSide: CGFloat
    ) {
        // Outer 7x7 Frame
        let outerRect = bounds
        let innerRect = bounds.insetBy(dx: moduleSide, dy: moduleSide)

        let outerPath: UIBezierPath
        let innerPath: UIBezierPath

        switch frameStyle {
        case .square:
            outerPath = UIBezierPath(rect: outerRect)
            innerPath = UIBezierPath(rect: innerRect)

        case .rounded:
            let r1 = moduleSide * 1.6
            let r2 = moduleSide * 0.9
            outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: r1)
            innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: r2)

        case .circle:
            outerPath = UIBezierPath(ovalIn: outerRect)
            innerPath = UIBezierPath(ovalIn: innerRect)

        case .squircle:
            let r1 = moduleSide * 2.3
            let r2 = moduleSide * 1.3
            outerPath = UIBezierPath(roundedRect: outerRect, cornerRadius: r1)
            innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: r2)
        }

        // Ring cutout (outer minus inner)
        outerPath.append(innerPath)
        outerPath.usesEvenOddFillRule = true
        path.append(outerPath)

        // Center 3x3 Eyeball (Pupil)
        let pupilRect = bounds.insetBy(dx: 2 * moduleSide, dy: 2 * moduleSide)
        switch pupilStyle {
        case .square:
            path.append(UIBezierPath(rect: pupilRect))

        case .circle:
            path.append(UIBezierPath(ovalIn: pupilRect))

        case .squircle:
            let radius = moduleSide * 0.95
            path.append(UIBezierPath(roundedRect: pupilRect, cornerRadius: radius))

        case .diamond:
            let diamond = UIBezierPath()
            diamond.move(to: CGPoint(x: pupilRect.midX, y: pupilRect.minY))
            diamond.addLine(to: CGPoint(x: pupilRect.maxX, y: pupilRect.midY))
            diamond.addLine(to: CGPoint(x: pupilRect.midX, y: pupilRect.maxY))
            diamond.addLine(to: CGPoint(x: pupilRect.minX, y: pupilRect.midY))
            diamond.close()
            path.append(diamond)
        }
    }

    // MARK: - Center Badges

    private func drawCenterLogo(in qrRect: CGRect, logo: UIImage) {
        let badgeSize = qrRect.width * 0.23
        let badgeRect = CGRect(
            x: qrRect.midX - (badgeSize / 2),
            y: qrRect.midY - (badgeSize / 2),
            width: badgeSize,
            height: badgeSize
        )

        let cornerRadius = badgeSize * 0.26
        let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)
        UIColor.white.setFill()
        path.fill()

        UIColor.black.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 2.0
        path.stroke()

        let inset: CGFloat = 3.5
        let imageRect = badgeRect.insetBy(dx: inset, dy: inset)
        let imageClipPath = UIBezierPath(roundedRect: imageRect, cornerRadius: cornerRadius - 2.0)

        let ctx = UIGraphicsGetCurrentContext()
        ctx?.saveGState()
        imageClipPath.addClip()
        logo.draw(in: imageRect)
        ctx?.restoreGState()
    }

    private func drawCenterBadge(in qrRect: CGRect, iconName: String, tintColor: UIColor) {
        let badgeSize = qrRect.width * 0.22
        let badgeRect = CGRect(
            x: qrRect.midX - (badgeSize / 2),
            y: qrRect.midY - (badgeSize / 2),
            width: badgeSize,
            height: badgeSize
        )

        let cornerRadius = badgeSize * 0.28
        let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)
        UIColor.white.setFill()
        path.fill()

        UIColor.black.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 2.0
        path.stroke()

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: badgeSize * 0.48, weight: .semibold)
        if let symbol = UIImage(systemName: iconName, withConfiguration: symbolConfig)?
            .withTintColor(tintColor, renderingMode: .alwaysOriginal) {
            let symbolSize = symbol.size
            let symbolRect = CGRect(
                x: badgeRect.midX - symbolSize.width / 2,
                y: badgeRect.midY - symbolSize.height / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol.draw(in: symbolRect)
        }
    }

    // MARK: - Pure Vector SVG Generation with Shapes & Gradients

    public func renderSVG(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        correctionLevel: QRErrorCorrectionLevel = .high,
        dotShape: QRDotShape = .square,
        eyeFrame: QREyeFrameStyle = .square,
        eyePupil: QREyePupilStyle = .square,
        gradient: QRColorGradient = .none
    ) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        guard let pixelData = cgImage.dataProvider?.data,
              let dataPtr = CFDataGetBytePtr(pixelData) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        func isDark(_ x: Int, _ y: Int) -> Bool {
            let offset = y * bytesPerRow + x * bytesPerPixel
            return dataPtr[offset] < 128
        }

        func isEyeArea(_ x: Int, _ y: Int) -> Bool {
            (x < 7 && y < 7) || (x >= width - 7 && y < 7) || (x < 7 && y >= height - 7)
        }

        let bgHex = hexString(from: backgroundColor)
        let fgHex = hexString(from: foregroundColor)

        var gradientDef = ""
        var fillRef = fgHex

        if gradient != .none && !gradient.colors.isEmpty {
            let startHex = hexString(from: gradient.colors.first ?? foregroundColor)
            let endHex = hexString(from: gradient.colors.last ?? foregroundColor)
            gradientDef = """
            <defs>
              <linearGradient id="qrGrad" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" stop-color="\(startHex)" />
                <stop offset="100%" stop-color="\(endHex)" />
              </linearGradient>
            </defs>
            """
            fillRef = "url(#qrGrad)"
        }

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" shape-rendering="geometricPrecision">
        \(gradientDef)
        <rect width="\(width)" height="\(height)" fill="\(bgHex)" />
        <g fill="\(fillRef)">
        """

        // Draw Data Modules
        for y in 0..<height {
            for x in 0..<width {
                if isEyeArea(x, y) { continue }
                if isDark(x, y) {
                    switch dotShape {
                    case .square:
                        svg.append("\n  <rect x=\"\(x)\" y=\"\(y)\" width=\"1\" height=\"1\" />")
                    case .dots:
                        svg.append("\n  <circle cx=\"\(Double(x) + 0.5)\" cy=\"\(Double(y) + 0.5)\" r=\"0.42\" />")
                    case .squircle, .liquid:
                        svg.append("\n  <rect x=\"\(Double(x) + 0.05)\" y=\"\(Double(y) + 0.05)\" width=\"0.9\" height=\"0.9\" rx=\"0.28\" />")
                    }
                }
            }
        }

        // Draw Finder Eyes in SVG
        let eyeOrigins = [(0, 0), (width - 7, 0), (0, height - 7)]
        for eye in eyeOrigins {
            let ex = eye.0
            let ey = eye.1

            // Outer frame & inner pupil
            switch eyeFrame {
            case .square:
                svg.append("""
                \n  <path fill-rule="evenodd" d="M\(ex),\(ey) h7 v7 h-7 z M\(ex+1),\(ey+1) v5 h5 v-5 z" />
                """)
            case .rounded, .squircle:
                svg.append("""
                \n  <rect x=\"\(ex)\" y=\"\(ey)\" width=\"7\" height=\"7\" rx=\"1.8\" fill=\"\(fillRef)\" />
                <rect x=\"\(ex+1)\" y=\"\(ey+1)\" width=\"5\" height=\"5\" rx=\"1.0\" fill=\"\(bgHex)\" />
                """)
            case .circle:
                svg.append("""
                \n  <circle cx=\"\(Double(ex) + 3.5)\" cy=\"\(Double(ey) + 3.5)\" r=\"3.5\" fill=\"\(fillRef)\" />
                <circle cx=\"\(Double(ex) + 3.5)\" cy=\"\(Double(ey) + 3.5)\" r=\"2.5\" fill=\"\(bgHex)\" />
                """)
            }

            // Eyeball
            switch eyePupil {
            case .square:
                svg.append("\n  <rect x=\"\(ex+2)\" y=\"\(ey+2)\" width=\"3\" height=\"3\" fill=\"\(fillRef)\" />")
            case .circle:
                svg.append("\n  <circle cx=\"\(Double(ex) + 3.5)\" cy=\"\(Double(ey) + 3.5)\" r=\"1.5\" fill=\"\(fillRef)\" />")
            case .squircle:
                svg.append("\n  <rect x=\"\(ex+2)\" y=\"\(ey+2)\" width=\"3\" height=\"3\" rx=\"0.8\" fill=\"\(fillRef)\" />")
            case .diamond:
                svg.append("""
                \n  <polygon points=\"\(Double(ex)+3.5),\(ey+2) \(ex+5),\(Double(ey)+3.5) \(Double(ex)+3.5),\(ey+5) \(ex+2),\(Double(ey)+3.5)\" fill=\"\(fillRef)\" />
                """)
            }
        }

        svg.append("\n</g>\n</svg>")
        return svg
    }

    // MARK: - Infinite Vector PDF Generation with Shapes & Gradients

    public func renderPDF(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        correctionLevel: QRErrorCorrectionLevel = .high,
        dotShape: QRDotShape = .square,
        eyeFrame: QREyeFrameStyle = .square,
        eyePupil: QREyePupilStyle = .square,
        gradient: QRColorGradient = .none
    ) -> Data? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        let matrixWidth = cgImage.width
        let matrixHeight = cgImage.height

        guard let pixelData = cgImage.dataProvider?.data,
              let dataPtr = CFDataGetBytePtr(pixelData) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        func isDark(_ x: Int, _ y: Int) -> Bool {
            let offset = y * bytesPerRow + x * bytesPerPixel
            return dataPtr[offset] < 128
        }

        func isEyeArea(_ x: Int, _ y: Int) -> Bool {
            (x < 7 && y < 7) || (x >= matrixWidth - 7 && y < 7) || (x < 7 && y >= matrixHeight - 7)
        }

        let pageSide: CGFloat = 1000.0
        let pageRect = CGRect(x: 0, y: 0, width: pageSide, height: pageSide)
        let moduleSide = pageSide / CGFloat(matrixWidth)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return pdfRenderer.pdfData { pdfContext in
            pdfContext.beginPage()
            let cgCtx = pdfContext.cgContext

            backgroundColor.setFill()
            cgCtx.fill(pageRect)

            let compoundPath = UIBezierPath()

            for y in 0..<matrixHeight {
                for x in 0..<matrixWidth {
                    if isEyeArea(x, y) { continue }
                    if isDark(x, y) {
                        let modRect = CGRect(
                            x: CGFloat(x) * moduleSide,
                            y: CGFloat(y) * moduleSide,
                            width: moduleSide,
                            height: moduleSide
                        )
                        appendDot(to: compoundPath, rect: modRect, shape: dotShape, moduleSide: moduleSide)
                    }
                }
            }

            let eyeOrigins = [
                CGPoint(x: 0, y: 0),
                CGPoint(x: matrixWidth - 7, y: 0),
                CGPoint(x: 0, y: matrixHeight - 7)
            ]

            for eye in eyeOrigins {
                let eyeRect = CGRect(
                    x: eye.x * moduleSide,
                    y: eye.y * moduleSide,
                    width: 7 * moduleSide,
                    height: 7 * moduleSide
                )
                appendFinderEye(
                    to: compoundPath,
                    bounds: eyeRect,
                    frameStyle: eyeFrame,
                    pupilStyle: eyePupil,
                    moduleSide: moduleSide
                )
            }

            cgCtx.saveGState()
            if gradient != .none && !gradient.colors.isEmpty {
                cgCtx.addPath(compoundPath.cgPath)
                cgCtx.clip()

                let cgColors = gradient.colors.map { $0.cgColor } as CFArray
                if let cgGrad = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: cgColors,
                    locations: [0.0, 1.0]
                ) {
                    cgCtx.drawLinearGradient(
                        cgGrad,
                        start: CGPoint(x: 0, y: 0),
                        end: CGPoint(x: pageSide, y: pageSide),
                        options: []
                    )
                }
            } else {
                foregroundColor.setFill()
                compoundPath.fill()
            }
            cgCtx.restoreGState()
        }
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
            let rInt = max(0, min(255, lroundf(Float(r * 255))))
            let gInt = max(0, min(255, lroundf(Float(g * 255))))
            let bInt = max(0, min(255, lroundf(Float(b * 255))))
            return String(format: "#%02X%02X%02X", rInt, gInt, bInt)
        }
        var white: CGFloat = 0
        if color.getWhite(&white, alpha: &a) {
            let wInt = max(0, min(255, lroundf(Float(white * 255))))
            return String(format: "#%02X%02X%02X", wInt, wInt, wInt)
        }
        return "#000000"
    }
}
