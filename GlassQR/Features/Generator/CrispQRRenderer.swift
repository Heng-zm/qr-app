//
//  CrispQRRenderer.swift
//  GlassQR
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
}

public final class CrispQRRenderer: @unchecked Sendable {
    private let context = CIContext()

    public init() {}

    // MARK: - Raster PNG Rendering

    public func render(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        centerIconName: String? = nil,
        customLogo: UIImage? = nil,
        correctionLevel: QRErrorCorrectionLevel = .high
    ) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")

        // Force High or Quartile error correction if a center badge/logo is present
        let effectiveLevel: String
        if customLogo != nil || (centerIconName != nil && !centerIconName!.isEmpty) {
            effectiveLevel = (correctionLevel == .low || correctionLevel == .medium) ? "H" : correctionLevel.rawValue
        } else {
            effectiveLevel = correctionLevel.rawValue
        }
        filter.setValue(effectiveLevel, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Crisp vector scaling factor to prevent blurring
        let scale = 14.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        // Apply FalseColor filter for customizable color themes
        let falseColorFilter = CIFilter(name: "CIFalseColor")
        falseColorFilter?.setValue(scaledImage, forKey: "inputImage")
        falseColorFilter?.setValue(CIColor(color: foregroundColor), forKey: "inputColor0")
        falseColorFilter?.setValue(CIColor(color: backgroundColor), forKey: "inputColor1")

        let finalCIImage = falseColorFilter?.outputImage ?? scaledImage

        // Use scaledImage.extent to ensure finite render bounds
        guard let cgImage = context.createCGImage(finalCIImage, from: scaledImage.extent) else {
            return nil
        }
        let baseQR = UIImage(cgImage: cgImage)

        // Overlay custom user photo logo if provided
        if let logo = customLogo {
            return overlayCustomLogo(baseImage: baseQR, logo: logo)
        }

        // Overlay SF Symbol if requested
        if let iconName = centerIconName, !iconName.isEmpty {
            return overlayCenterIcon(baseImage: baseQR, iconName: iconName, tintColor: foregroundColor)
        }

        return baseQR
    }

    // MARK: - Custom Center Logo Overlay

    private func overlayCustomLogo(baseImage: UIImage, logo: UIImage) -> UIImage {
        let size = baseImage.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            let badgeSize = size.width * 0.24
            let badgeRect = CGRect(
                x: (size.width - badgeSize) / 2,
                y: (size.height - badgeSize) / 2,
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
    }

    // MARK: - Center SF Symbol Overlay

    private func overlayCenterIcon(baseImage: UIImage, iconName: String, tintColor: UIColor) -> UIImage {
        let size = baseImage.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            let badgeSize = size.width * 0.22
            let badgeRect = CGRect(
                x: (size.width - badgeSize) / 2,
                y: (size.height - badgeSize) / 2,
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
    }

    // MARK: - Pure Vector SVG Generation

    public func renderSVG(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        correctionLevel: QRErrorCorrectionLevel = .high
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

        let fgHex = hexString(from: foregroundColor)
        let bgHex = hexString(from: backgroundColor)

        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 \(width) \(height)" shape-rendering="crispEdges">
        <rect width="\(width)" height="\(height)" fill="\(bgHex)" />
        <g fill="\(fgHex)">
        """

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                let r = dataPtr[pixelIndex]
                if r < 128 {
                    svg.append("\n  <rect x=\"\(x)\" y=\"\(y)\" width=\"1\" height=\"1\" />")
                }
            }
        }

        svg.append("\n</g>\n</svg>")
        return svg
    }

    // MARK: - Infinite Vector PDF Generation

    public func renderPDF(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        correctionLevel: QRErrorCorrectionLevel = .high
    ) -> Data? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }

        let modulesWidth = cgImage.width
        let modulesHeight = cgImage.height

        guard let pixelData = cgImage.dataProvider?.data,
              let dataPtr = CFDataGetBytePtr(pixelData) else { return nil }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        let pageSide: CGFloat = 1000.0
        let pageRect = CGRect(x: 0, y: 0, width: pageSide, height: pageSide)
        let moduleSide = pageSide / CGFloat(modulesWidth)

        let pdfRenderer = UIGraphicsPDFRenderer(bounds: pageRect)

        return pdfRenderer.pdfData { pdfContext in
            pdfContext.beginPage()

            backgroundColor.setFill()
            pdfContext.cgContext.fill(pageRect)

            foregroundColor.setFill()
            for y in 0..<modulesHeight {
                for x in 0..<modulesWidth {
                    let pixelIndex = y * bytesPerRow + x * bytesPerPixel
                    let r = dataPtr[pixelIndex]
                    if r < 128 {
                        let rect = CGRect(
                            x: CGFloat(x) * moduleSide,
                            y: CGFloat(y) * moduleSide,
                            width: moduleSide,
                            height: moduleSide
                        )
                        pdfContext.cgContext.fill(rect)
                    }
                }
            }
        }
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}
