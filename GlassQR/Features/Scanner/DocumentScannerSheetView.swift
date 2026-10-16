//
//  DocumentScannerSheetView.swift
//  GlassQR
//
//  Native Apple VisionKit Multi-Page Document Scanner & Studio
//  Automatic perspective correction, multi-page scanning, CoreImage filters,
//  vector PDFKit compilation, Neural OCR text extraction, and QR/AI actions.
//

import SwiftUI
import PDFKit
@preconcurrency import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

public enum DocumentImageFilter: String, CaseIterable, Identifiable {
    case original = "Color"
    case enhanced = "Crisp Doc"
    case blackAndWhite = "B&W"
    case grayscale = "Grayscale"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .original: return "paintpalette.fill"
        case .enhanced: return "wand.and.stars"
        case .blackAndWhite: return "circle.righthalf.filled"
        case .grayscale: return "circle.fill"
        }
    }
}

public struct DocumentScannerSheetView: View {
    @Binding var isPresented: Bool
    public var onApplyToGenerator: ((String) -> Void)?

    @State private var scannedPages: [UIImage] = []
    @State private var selectedPageIndex: Int = 0
    @State private var selectedFilter: DocumentImageFilter = .original
    @State private var isScanningCamera: Bool = true

    // OCR & PDF State
    @State private var isPerformingOCR: Bool = false
    @State private var recognizedText: String = ""
    @State private var pdfURL: URL? = nil
    @State private var pdfByteSize: Int = 0

    // UX Feedback & Sheets
    @State private var toastMessage: String? = nil
    @State private var hapticTrigger: Int = 0
    @State private var showAIAssistant: Bool = false
    @State private var isTextExpanded: Bool = false

    private static let sharedCIContext = CIContext(options: nil)

    public init(
        isPresented: Binding<Bool>,
        onApplyToGenerator: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.onApplyToGenerator = onApplyToGenerator
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Dark Obsidian Glass Backdrop
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                if scannedPages.isEmpty || isScanningCamera {
                    // Full-Screen Live Document Scanner (Native VisionKit or Simulator Studio)
                    DocumentCameraRepresentable(
                        onScannedPages: { newPages in
                            if !newPages.isEmpty {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
                                    scannedPages.append(contentsOf: newPages)
                                    selectedPageIndex = 0
                                    isScanningCamera = false
                                }
                                compilePDFAndRunOCR()
                            }
                        },
                        onCancel: {
                            if scannedPages.isEmpty {
                                isPresented = false
                            } else {
                                isScanningCamera = false
                            }
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    // Document Studio: Multi-Page Gallery, PDF & OCR
                    documentStudioView
                }
            }
            .navigationTitle(navigationBarTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(scannedPages.isEmpty ? "Cancel" : "Add Page") {
                        if scannedPages.isEmpty {
                            isPresented = false
                        } else {
                            isScanningCamera = true
                        }
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                }

                if !scannedPages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                    }
                }
            }
            .overlay(alignment: .top) {
                if let msg = toastMessage {
                    toastBanner(message: msg)
                }
            }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticTrigger)
            .sheet(isPresented: $showAIAssistant) {
                NavigationStack {
                    AIAssistantView(
                        hasCompletedOnboarding: .constant(true),
                        initialScanItem: ScanResultItem(payload: recognizedText.isEmpty ? "Scanned Document" : recognizedText),
                        isEmbeddedInTab: false
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showAIAssistant = false
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private var navigationBarTitle: String {
        if scannedPages.isEmpty || isScanningCamera {
            return "Scan Document"
        }
        return "Document Studio"
    }

    // MARK: - Document Studio View

    private var documentStudioView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header Metadata Badge
                documentMetadataBar
                    .padding(.top, 10)
                    .padding(.horizontal, 20)

                // Large Main Page Preview
                mainPagePreviewCard
                    .padding(.horizontal, 20)

                // Filter Segmented Controls
                filterSelectorPill
                    .padding(.horizontal, 20)

                // Horizontal Pages Filmstrip
                pagesFilmstrip
                    .padding(.horizontal, 20)

                // Primary Actions Platter (Share PDF, Copy OCR, To QR, Ask AI)
                primaryActionPlatter
                    .padding(.horizontal, 20)

                // OCR Recognized Text Accordion
                ocrTranscriptionCard
                    .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Metadata Bar

    private var documentMetadataBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.orange)

                Text("Page \(selectedPageIndex + 1) of \(scannedPages.count)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            if pdfByteSize > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cyan)

                    Text(formattedFileSize(pdfByteSize))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            if isPerformingOCR {
                HStack(spacing: 5) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.65)
                    Text("OCR...")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            } else if !recognizedText.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("Text Ready")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
        }
    }

    // MARK: - Main Page Preview Card

    private var mainPagePreviewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            if selectedPageIndex < scannedPages.count {
                let baseImage = scannedPages[selectedPageIndex]
                let filteredImage = applyFilter(selectedFilter, to: baseImage)

                Image(uiImage: filteredImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
                    .padding(10)
            }
        }
        .frame(minHeight: 320)
    }

    // MARK: - Filter Selector Pill

    private var filterSelectorPill: some View {
        HStack(spacing: 6) {
            ForEach(DocumentImageFilter.allCases) { filter in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.75)) {
                        selectedFilter = filter
                    }
                    triggerHaptic()
                    compilePDFAsync()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: filter.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(selectedFilter == filter ? Color.black : Color.white.opacity(0.8))
                    .background {
                        if selectedFilter == filter {
                            Capsule().fill(Color.white)
                        } else {
                            Capsule().fill(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.black.opacity(0.45)))
        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: - Pages Filmstrip

    private var pagesFilmstrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCANNED PAGES (\(scannedPages.count))")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<scannedPages.count, id: \.self) { idx in
                        let isSelected = selectedPageIndex == idx
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedPageIndex = idx
                            }
                            triggerHaptic()
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: scannedPages[idx])
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 60, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(isSelected ? Color.cyan : Color.white.opacity(0.18), lineWidth: isSelected ? 2.5 : 1)
                                    )

                                // Page Number Pill
                                Text("\(idx + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.black.opacity(0.75)))
                                    .offset(x: -4, y: 4)

                                // Delete page button (if more than 1 page)
                                if scannedPages.count > 1 {
                                    Button {
                                        deletePage(at: idx)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.red)
                                            .background(Circle().fill(Color.white))
                                    }
                                    .offset(x: 6, y: -6)
                                }
                            }
                        }
                    }

                    // Add Page Button Tile
                    Button {
                        isScanningCamera = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.cyan)
                            Text("Add Page")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .frame(width: 60, height: 80)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Primary Action Platter

    private var primaryActionPlatter: some View {
        VStack(spacing: 10) {
            // Row 1: Share PDF & Copy OCR Text
            HStack(spacing: 10) {
                if let url = pdfURL {
                    ShareLink(item: url, preview: SharePreview("Scanned Document (\(scannedPages.count) Pages).pdf")) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 14, weight: .bold))
                            Text("Share PDF")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .foregroundStyle(.black)
                        .background(Capsule().fill(Color.white))
                        .shadow(color: Color.white.opacity(0.2), radius: 6)
                    }
                }

                Button {
                    UIPasteboard.general.string = recognizedText.isEmpty ? "Scanned Document (\(scannedPages.count) pages)" : recognizedText
                    triggerToast("OCR Text Copied!")
                    triggerHaptic()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.cyan)
                        Text("Copy Text")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                }
            }

            // Row 2: Turn into QR Code & Ask AI Agent
            HStack(spacing: 10) {
                if let apply = onApplyToGenerator {
                    Button {
                        apply(recognizedText.isEmpty ? "Scanned Document (\(scannedPages.count) pages)" : recognizedText)
                        isPresented = false
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.orange)
                            Text("Generate QR")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                }

                Button {
                    showAIAssistant = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.purple)
                        Text("Ask AI Copilot")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                }
            }
        }
    }

    // MARK: - OCR Transcription Accordion

    private var ocrTranscriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    isTextExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.cyan)

                    Text("Extracted Document Text")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: isTextExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }

            if isTextExpanded {
                if recognizedText.isEmpty {
                    Text("No text detected yet or processing...")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.vertical, 8)
                } else {
                    Text(recognizedText)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(4)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.5))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Toast Banner

    private func toastBanner(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.4), radius: 8)
        )
        .padding(.top, 10)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Actions & Compilation Logic

    private func deletePage(at index: Int) {
        guard index < scannedPages.count else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
            scannedPages.remove(at: index)
            if selectedPageIndex >= scannedPages.count {
                selectedPageIndex = max(0, scannedPages.count - 1)
            }
        }
        triggerHaptic()
        compilePDFAndRunOCR()
    }

    private func compilePDFAndRunOCR() {
        compilePDFAsync()
        runOCRAsync()
    }

    private func compilePDFAsync() {
        Task {
            let processedPages = scannedPages.map { applyFilter(selectedFilter, to: $0) }
            let pdfDoc = PDFDocument()
            for (idx, page) in processedPages.enumerated() {
                if let pdfPage = PDFPage(image: page) {
                    pdfDoc.insert(pdfPage, at: idx)
                }
            }

            guard let data = pdfDoc.dataRepresentation() else { return }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Scanned_Document_\(Date().timeIntervalSince1970).pdf")
            try? data.write(to: tempURL)

            await MainActor.run {
                self.pdfURL = tempURL
                self.pdfByteSize = data.count
            }
        }
    }

    private func runOCRAsync() {
        guard !scannedPages.isEmpty else { return }
        isPerformingOCR = true

        Task {
            var fullTranscript: [String] = []
            for (pageIdx, page) in scannedPages.enumerated() {
                let pageText = await recognizeTextFromImage(page)
                if !pageText.isEmpty {
                    fullTranscript.append("--- PAGE \(pageIdx + 1) ---\n\(pageText)")
                }
            }

            let combined = fullTranscript.joined(separator: "\n\n")
            await MainActor.run {
                self.recognizedText = combined
                self.isPerformingOCR = false
            }
        }
    }

    private func recognizeTextFromImage(_ image: UIImage) async -> String {
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler: VNImageRequestHandler
        if let cgImage = image.cgImage {
            handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        } else if let ciImage = image.ciImage ?? CIImage(image: image) {
            handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation, options: [:])
        } else {
            return ""
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                guard error == nil, let results = req.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                let recognizedLines = results.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: recognizedLines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }

    private func applyFilter(_ filter: DocumentImageFilter, to image: UIImage) -> UIImage {
        guard filter != .original, let ciImage = CIImage(image: image) else { return image }
        let context = Self.sharedCIContext

        switch filter {
        case .original:
            return image

        case .enhanced:
            // High clarity, boosted contrast and exposure
            let filter = CIFilter.colorControls()
            filter.inputImage = ciImage
            filter.contrast = 1.2
            filter.brightness = 0.05
            filter.saturation = 0.95
            if let output = filter.outputImage, let cg = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
            }

        case .blackAndWhite:
            let mono = CIFilter.photoEffectMono()
            mono.inputImage = ciImage
            if let monoOut = mono.outputImage {
                let contrast = CIFilter.colorControls()
                contrast.inputImage = monoOut
                contrast.contrast = 1.45
                if let output = contrast.outputImage, let cg = context.createCGImage(output, from: output.extent) {
                    return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
                }
            }

        case .grayscale:
            let noir = CIFilter.photoEffectNoir()
            noir.inputImage = ciImage
            if let output = noir.outputImage, let cg = context.createCGImage(output, from: output.extent) {
                return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
            }
        }
        return image
    }

    private func formattedFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if toastMessage == msg {
                    withAnimation(.easeOut(duration: 0.3)) {
                        toastMessage = nil
                    }
                }
            }
        }
    }

    private func triggerHaptic() {
        hapticTrigger += 1
    }
}

// MARK: - CGImagePropertyOrientation Helper
extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
