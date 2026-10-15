//
//  CrispQRRenderer.swift
//  GlassQR
//

import UIKit
@preconcurrency import CoreImage
import CoreImage.CIFilterBuiltins

public final class CrispQRRenderer: @unchecked Sendable {
    private let context = CIContext()

    public init() {}

    public func render(
        text: String,
        foregroundColor: UIColor = .black,
        backgroundColor: UIColor = .white,
        centerIconName: String? = nil
    ) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

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

        guard let cgImage = context.createCGImage(finalCIImage, from: finalCIImage.extent) else {
            return nil
        }
        let baseQR = UIImage(cgImage: cgImage)

        // If no center icon is requested, return base crisp QR directly
        guard let iconName = centerIconName, !iconName.isEmpty else {
            return baseQR
        }

        // Overlay a refined center badge
        return overlayCenterIcon(baseImage: baseQR, iconName: iconName, tintColor: foregroundColor)
    }

    private func overlayCenterIcon(baseImage: UIImage, iconName: String, tintColor: UIColor) -> UIImage {
        let size = baseImage.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            // Draw QR base
            baseImage.draw(in: CGRect(origin: .zero, size: size))

            // Center Badge dimensions (approx 22% of QR size - safe for Error Correction H)
            let badgeSize = size.width * 0.22
            let badgeRect = CGRect(
                x: (size.width - badgeSize) / 2,
                y: (size.height - badgeSize) / 2,
                width: badgeSize,
                height: badgeSize
            )

            // Clean rounded badge background
            let cornerRadius = badgeSize * 0.28
            let path = UIBezierPath(roundedRect: badgeRect, cornerRadius: cornerRadius)
            UIColor.white.setFill()
            path.fill()

            // Subtle border around badge
            UIColor.black.withAlphaComponent(0.08).setStroke()
            path.lineWidth = 2.0
            path.stroke()

            // Draw SF Symbol in center of badge
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
}
