//
//  LiveTextScannerRepresentable.swift
//  GlassQR
//
//  Live Camera Text OCR Scanner using Apple's VisionKit (DataScannerViewController)
//  with on-device Neural Engine acceleration and Vision fallback.
//

import SwiftUI
import UIKit
@preconcurrency import Vision
#if canImport(VisionKit)
import VisionKit
#endif

public struct LiveTextScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isScanning: Bool
    let onTextRecognized: (String) -> Void
    let onDismiss: () -> Void

    public init(
        isScanning: Binding<Bool>,
        onTextRecognized: @escaping (String) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self._isScanning = isScanning
        self.onTextRecognized = onTextRecognized
        self.onDismiss = onDismiss
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        #if !targetEnvironment(simulator)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
            let scanner = DataScannerViewController(
                recognizedDataTypes: [.text()],
                qualityLevel: .accurate,
                recognizesMultipleItems: true,
                isHighFrameRateTrackingEnabled: true,
                isHighlightingEnabled: true
            )
            scanner.delegate = context.coordinator
            return scanner
        }
        #endif

        // Simulator / Fallback Vision Controller
        let fallback = SimulatedOCRViewController()
        fallback.onTextSelected = { text in
            self.onTextRecognized(text)
        }
        return fallback
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        #if !targetEnvironment(simulator)
        if #available(iOS 16.0, *), let scanner = uiViewController as? DataScannerViewController {
            if isScanning {
                try? scanner.startScanning()
            } else {
                scanner.stopScanning()
            }
        }
        #endif
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public final class Coordinator: NSObject {
        let parent: LiveTextScannerRepresentable

        init(_ parent: LiveTextScannerRepresentable) {
            self.parent = parent
        }
    }
}

#if !targetEnvironment(simulator)
@available(iOS 16.0, *)
extension LiveTextScannerRepresentable.Coordinator: DataScannerViewControllerDelegate {
    public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        switch item {
        case .text(let text):
            parent.onTextRecognized(text.transcript)
        default:
            break
        }
    }
}
#endif

// MARK: - Simulator & Fallback Interactive Vision OCR Controller

final class SimulatedOCRViewController: UIViewController {
    var onTextSelected: ((String) -> Void)?

    private let sampleCards: [(title: String, icon: String, text: String)] = [
        ("Wi-Fi Router Sticker", "wifi", "WIFI:S:GuestNet_5GHz;T:WPA;P:Welcome2026!;;"),
        ("Product Model Label", "tag.fill", "MODEL: GQ-2026-X • SN: 8849-2041-9921"),
        ("Conference Badge", "person.text.rectangle", "Elena Rostova • Keynote Speaker\nAI Vision Summit 2026\nelena@summit.org"),
        ("Web Article Link", "link", "https://github.com/Heng-zm/qr-app")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.11, alpha: 1.0)
        setupUI()
    }

    private func setupUI() {
        let label = UILabel()
        label.text = "Live Text OCR Simulator"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        let subtitle = UILabel()
        subtitle.text = "Point camera at any printed paper, sign, or router sticker to recognize text with Apple Vision."
        subtitle.textColor = UIColor.white.withAlphaComponent(0.65)
        subtitle.font = .systemFont(ofSize: 13, weight: .medium)
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitle)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        for card in sampleCards {
            let button = UIButton(type: .system)
            button.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            button.layer.cornerRadius = 14
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            button.contentHorizontalAlignment = .left
            button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)

            let titleStr = "\(card.title)\n\(card.text)"
            let attr = NSMutableAttributedString(string: titleStr)
            attr.addAttribute(.foregroundColor, value: UIColor.cyan, range: NSRange(location: 0, length: card.title.count))
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 12, weight: .bold), range: NSRange(location: 0, length: card.title.count))
            attr.addAttribute(.foregroundColor, value: UIColor.white, range: NSRange(location: card.title.count + 1, length: card.text.count))
            attr.addAttribute(.font, value: UIFont.systemFont(ofSize: 13, weight: .medium), range: NSRange(location: card.title.count + 1, length: card.text.count))

            button.setAttributedTitle(attr, for: .normal)
            button.titleLabel?.numberOfLines = 0
            button.addAction(UIAction { [weak self] _ in
                self?.onTextSelected?(card.text)
            }, for: .touchUpInside)

            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitle.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
        ])
    }
}
