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

    public func render(text: String) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Crisp vector scaling factor to prevent blurring
        let scale = 14.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
