//
//  DocumentCameraRepresentable.swift
//  GlassQR
//
//  Native Apple VisionKit Document Scanner Representable
//  (VNDocumentCameraViewController) with multi-page automatic perspective correction,
//  shutter, edge detection, and interactive Simulator fallback studio.
//

import SwiftUI
import UIKit
#if canImport(VisionKit)
import VisionKit
#endif
import PhotosUI

/// UIViewControllerRepresentable wrapping Apple's native VNDocumentCameraViewController
public struct DocumentCameraRepresentable: UIViewControllerRepresentable {
    public let onScannedPages: ([UIImage]) -> Void
    public let onCancel: () -> Void

    public init(
        onScannedPages: @escaping ([UIImage]) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onScannedPages = onScannedPages
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIViewController {
        #if canImport(VisionKit) && !targetEnvironment(simulator)
        if VNDocumentCameraViewController.isSupported {
            let docController = VNDocumentCameraViewController()
            docController.delegate = context.coordinator
            return docController
        }
        #endif

        // Simulator & Fallback Interactive Studio
        let fallback = SimulatedDocumentScannerViewController()
        fallback.onPagesCaptured = onScannedPages
        fallback.onCancel = onCancel
        return fallback
    }

    public func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    public final class Coordinator: NSObject {
        var parent: DocumentCameraRepresentable

        init(parent: DocumentCameraRepresentable) {
            self.parent = parent
        }
    }
}

// MARK: - Native VisionKit Delegate
#if canImport(VisionKit) && !targetEnvironment(simulator)
extension DocumentCameraRepresentable.Coordinator: VNDocumentCameraViewControllerDelegate {
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var pages: [UIImage] = []
        for i in 0..<scan.pageCount {
            pages.append(scan.imageOfPage(at: i))
        }
        controller.dismiss(animated: true) {
            self.parent.onScannedPages(pages)
        }
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) {
            self.parent.onCancel()
        }
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.parent.onCancel()
        }
    }
}
#endif

// MARK: - Simulator & Offline Document Scanner Studio

final class SimulatedDocumentScannerViewController: UIViewController, PHPickerViewControllerDelegate {
    var onPagesCaptured: (([UIImage]) -> Void)?
    var onCancel: (() -> Void)?

    private var capturedPages: [UIImage] = []
    private let sampleDocs: [(title: String, subtitle: String, icon: String, text: String)] = [
        ("Business Invoice & Receipt", "Total $4,850.00 • INV-2026-9041", "doc.text.fill", "INVOICE #INV-2026-9041\nDate: October 16, 2026\nClient: Apex Tech Solutions\nItem 1: Liquid Glass UI Architecture ($3,200.00)\nItem 2: VisionKit Neural OCR Pipeline ($1,650.00)\nTOTAL: $4,850.00\nPayment Terms: Net 30"),
        ("Non-Disclosure Agreement (NDA)", "Confidentiality & Intellectual Property", "signature", "MUTUAL NON-DISCLOSURE AGREEMENT\nEffective Date: October 2026\nParties: GlassQR Inc. & Strategic Partner\n1. Confidential Information shall remain protected under strict encryption standards.\n2. Inventions and source algorithms remain exclusive property.\nSigned & Executed electronically."),
        ("Medical & Health Summary", "Annual Wellness Panel & Vitals", "heart.text.square.fill", "ANNUAL WELLNESS EXAMINATION REPORT\nPatient ID: PT-9921-X\nBlood Pressure: 118/76 mmHg\nResting Heart Rate: 62 bpm\nCholesterol: Normal Range\nPhysician Recommendation: Maintain healthy activity regimen."),
        ("Technical API Blueprint", "QR Protocol & Encryption Specs", "network", "GLASSQR SPECIFICATION V3.2\nAlgorithm: AES-256-GCM + Base64 UTF-8\nMax Payload: 2,953 bytes\nError Correction: Level H (30% redundancy)\nVerification Checksum: SHA-256 valid.")
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.09, alpha: 1.0)
        setupUI()
    }

    private func setupUI() {
        let titleLabel = UILabel()
        titleLabel.text = "Document Scanner Studio"
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitleLabel = UILabel()
        subtitleLabel.text = "Running in Simulator • Choose a sample document preset or import photos from library"
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (idx, doc) in sampleDocs.enumerated() {
            let btn = UIButton(type: .system)
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.08)
            btn.layer.cornerRadius = 14
            btn.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
            btn.layer.borderWidth = 1
            btn.tag = idx
            btn.addTarget(self, action: #selector(didSelectSample(_:)), for: .touchUpInside)

            let hStack = UIStackView()
            hStack.axis = .horizontal
            hStack.spacing = 12
            hStack.isUserInteractionEnabled = false
            hStack.translatesAutoresizingMaskIntoConstraints = false

            let iconView = UIImageView(image: UIImage(systemName: doc.icon))
            iconView.tintColor = .systemCyan
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 24),
                iconView.heightAnchor.constraint(equalToConstant: 24)
            ])

            let textStack = UIStackView()
            textStack.axis = .vertical
            textStack.spacing = 2

            let docTitle = UILabel()
            docTitle.text = doc.title
            docTitle.font = .systemFont(ofSize: 14, weight: .semibold)
            docTitle.textColor = .white

            let docSub = UILabel()
            docSub.text = doc.subtitle
            docSub.font = .systemFont(ofSize: 11)
            docSub.textColor = UIColor.white.withAlphaComponent(0.5)

            textStack.addArrangedSubview(docTitle)
            textStack.addArrangedSubview(docSub)

            hStack.addArrangedSubview(iconView)
            hStack.addArrangedSubview(textStack)

            btn.addSubview(hStack)
            NSLayoutConstraint.activate([
                hStack.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 14),
                hStack.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -14),
                hStack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
                btn.heightAnchor.constraint(equalToConstant: 58)
            ])

            stack.addArrangedSubview(btn)
        }

        // Photo Library Import Button
        let libraryBtn = UIButton(type: .system)
        libraryBtn.setTitle("Import from Photos Library", for: .normal)
        libraryBtn.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        libraryBtn.tintColor = .white
        libraryBtn.backgroundColor = UIColor.systemCyan.withAlphaComponent(0.2)
        libraryBtn.layer.cornerRadius = 14
        libraryBtn.layer.borderColor = UIColor.systemCyan.withAlphaComponent(0.4).cgColor
        libraryBtn.layer.borderWidth = 1
        libraryBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        libraryBtn.heightAnchor.constraint(equalToConstant: 46).isActive = true
        libraryBtn.addTarget(self, action: #selector(didTapPhotosPicker), for: .touchUpInside)
        stack.addArrangedSubview(libraryBtn)

        // Cancel Button
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("Cancel", for: .normal)
        cancelBtn.tintColor = UIColor.white.withAlphaComponent(0.7)
        cancelBtn.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        cancelBtn.addTarget(self, action: #selector(didCancel), for: .touchUpInside)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(stack)
        view.addSubview(cancelBtn)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            cancelBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func didSelectSample(_ sender: UIButton) {
        let index = sender.tag
        let doc = sampleDocs[index]
        let generatedImage = renderDocumentImage(title: doc.title, subtitle: doc.subtitle, bodyText: doc.text)
        onPagesCaptured?([generatedImage])
    }

    @objc private func didTapPhotosPicker() {
        var config = PHPickerConfiguration()
        config.selectionLimit = 5
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }

        let dispatchGroup = DispatchGroup()
        var loadedImages: [UIImage] = []

        for result in results {
            dispatchGroup.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
                defer { dispatchGroup.leave() }
                if let image = object as? UIImage {
                    loadedImages.append(image)
                }
            }
        }

        dispatchGroup.notify(queue: .main) { [weak self] in
            if !loadedImages.isEmpty {
                self?.onPagesCaptured?(loadedImages)
            }
        }
    }

    @objc private func didCancel() {
        onCancel?()
    }

    private func renderDocumentImage(title: String, subtitle: String, bodyText: String) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 800, height: 1100))
        return renderer.image { ctx in
            // White clean page backdrop
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 1100))

            // Subtle paper border
            UIColor(white: 0.88, alpha: 1.0).setStroke()
            ctx.stroke(CGRect(x: 20, y: 20, width: 760, height: 1060))

            // Header bar
            UIColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 40, y: 40, width: 720, height: 80))

            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            title.draw(at: CGPoint(x: 60, y: 65), withAttributes: titleAttrs)

            // Subtitle
            let subAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                .foregroundColor: UIColor(white: 0.45, alpha: 1.0)
            ]
            subtitle.draw(at: CGPoint(x: 50, y: 140), withAttributes: subAttrs)

            // Dividing Rule
            UIColor(white: 0.82, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 50, y: 170, width: 700, height: 1.5))

            // Body Paragraphs
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .regular),
                .foregroundColor: UIColor(white: 0.15, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
            let rect = CGRect(x: 50, y: 200, width: 700, height: 800)
            bodyText.draw(in: rect, withAttributes: bodyAttrs)

            // Bottom Footer Watermark
            let footerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: UIColor(white: 0.6, alpha: 1.0)
            ]
            "Scanned with GlassQR Document Engine • Neural VisionKit Pipeline".draw(at: CGPoint(x: 50, y: 1030), withAttributes: footerAttrs)
        }
    }
}
