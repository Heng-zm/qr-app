//
//  ScannerView.swift
//  GlassQR
//
//  Optimized Scanner Interface with Batch Mode, History Search, Categorization & CSV Export
//

import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage
import AudioToolbox
import Vision

public struct ScannerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var scannerNamespace

    // Preferences
    @AppStorage("glassqr_auto_copy") private var autoCopyOnScan: Bool = false
    @AppStorage("glassqr_haptics_enabled") private var hapticsEnabled: Bool = true
    @AppStorage("glassqr_sound_enabled") private var soundEnabled: Bool = true

    // Scan Mode: Single (pops sheet) vs Batch (saves and keeps scanning)
    @State private var isBatchMode: Bool = false
    @State private var batchScanCount: Int = 0
    @State private var lastScannedPayload: String = ""
    @State private var lastScannedTimestamp: Date = .distantPast

    // Camera State
    @State private var isTorchOn: Bool = false
    @State private var isPaused: Bool = false
    @State private var zoomFactor: CGFloat = 1.0
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    @State private var isSimulatedSession: Bool = false

    // Tap to focus state
    @State private var focusPoint: CGPoint? = nil
    @State private var showFocusRing: Bool = false

    // Scan Results & History
    @State private var activeScanResult: ScanResultItem? = nil
    @State private var scanFeedbackTrigger: Int = 0
    @State private var showBatchHUD: Bool = false
    @State private var batchHUDMessage: String = ""
    @State private var showHistorySheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    @AppStorage("glassqr_scan_history") private var scanHistoryData: String = "[]"

    // Photo Library Picker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzingPhoto: Bool = false

    // Live Camera Text OCR (VisionKit)
    @State private var showTextOCRSheet: Bool = false
    @State private var initialOCRText: String = ""

    private let zoomPresets: [CGFloat] = [1.0, 2.0, 3.0]
    private let cutoutSize: CGFloat = 260

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack {
            // Live Camera View Layer
            CameraEngineRepresentable(
                isTorchOn: $isTorchOn,
                isPaused: $isPaused,
                zoomFactor: $zoomFactor,
                cameraPosition: $cameraPosition,
                isSimulatedSession: $isSimulatedSession,
                onCodeDetected: { code, symbology in
                    handleDetectedCode(code, symbology: symbology)
                },
                onFocusPointTapped: { point in
                    triggerFocusAnimation(at: point)
                }
            )
            .ignoresSafeArea()

            // Clean Dark Frosted Vignette Cutout
            GeometryReader { proxy in
                let size = proxy.size
                let rect = CGRect(
                    x: (size.width - cutoutSize) / 2,
                    y: (size.height - cutoutSize) / 2 - 24,
                    width: cutoutSize,
                    height: cutoutSize
                )

                ZStack {
                    Color.black.opacity(0.48)
                        .mask {
                            Rectangle()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .blendMode(.destinationOut)
                                }
                        }
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()

            // Tap-to-focus Pulsing Ring
            if showFocusRing, let point = focusPoint {
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: 56, height: 56)
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
            }

            // Controls Overlay
            VStack(spacing: 0) {
                // Top Command Bar
                topHUD
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                Spacer()

                // Center Clean Viewfinder Frame
                centralViewfinder
                    .padding(.bottom, 20)

                Spacer()

                // Batch Mode Active Floating Chip
                if isBatchMode && batchScanCount > 0 {
                    batchReviewChip
                        .padding(.bottom, 8)
                }

                // Transient Batch Scan Toast
                if showBatchHUD {
                    batchToast
                        .padding(.bottom, 10)
                }

                // Simulator Test Chip (Preview mode)
                if isSimulatedSession {
                    simulatorTestChip
                        .padding(.bottom, 6)
                }

                // Bottom Minimalist Controls: Zoom & Photo Picker
                bottomControls
                    .padding(.bottom, 76)
                    .padding(.horizontal, 24)
            }
        }
        .navigationTitle("Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: scanFeedbackTrigger)
        .sheet(item: $activeScanResult) { result in
            ScanResultSheetView(result: result)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showHistorySheet) {
            ScanHistoryView(
                historyData: $scanHistoryData,
                onSelectResult: { item in
                    activeScanResult = item
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheet
        }
        .sheet(isPresented: $showTextOCRSheet) {
            TextOCRSheetView(
                isPresented: $showTextOCRSheet,
                initialText: initialOCRText,
                onApplyToGenerator: { text in
                    handleDetectedCode(text, symbology: "Vision OCR")
                }
            )
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                await analyzePickedPhoto(newItem)
            }
        }
    }

    // MARK: - UI Subviews

    private var topHUD: some View {
        VStack(spacing: 10) {
            // Minimalist Floating Platter
            GlassEffectContainer(spacing: 12) {
                // Torch Button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isTorchOn.toggle()
                    }
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isTorchOn ? Color.yellow : Color.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("torchControl", in: scannerNamespace)

                // Batch Mode Toggle Button
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isBatchMode.toggle()
                        if !isBatchMode {
                            batchScanCount = 0
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isBatchMode ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                            .font(.system(size: 14))
                        Text(isBatchMode ? "Batch" : "Single")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(isBatchMode ? Color.cyan : Color.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("batchControl", in: scannerNamespace)

                // Quick Settings Button
                Button {
                    showSettingsSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("settingsControl", in: scannerNamespace)

                // Camera Flip Button
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        cameraPosition = (cameraPosition == .back) ? .front : .back
                    }
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("flipControl", in: scannerNamespace)

                // Scan History Drawer Button with Counter Badge
                Button {
                    showHistorySheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "clock")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)

                        if historyCount > 0 {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .offset(x: 3, y: -3)
                        }
                    }
                }
                .buttonStyle(.glass)
                .glassEffectID("historyControl", in: scannerNamespace)

                // Pause / Resume Button
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        isPaused.toggle()
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isPaused ? Color.orange : Color.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("pauseControl", in: scannerNamespace)
            }

            // Minimalist Status Indicator Pill
            HStack(spacing: 7) {
                Circle()
                    .fill(isPaused ? Color.orange : (isBatchMode ? Color.cyan : Color.green))
                    .frame(width: 6, height: 6)

                Text(statusText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .glassEffect()
        }
    }

    private var statusText: String {
        if isPaused { return "Scanner Paused" }
        if isBatchMode { return "Batch Mode (\(batchScanCount) Scanned)" }
        return "Point at QR Code"
    }

    private var settingsSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                    .ignoresSafeArea()

                List {
                    Section {
                        Toggle("Auto-Copy on Scan", isOn: $autoCopyOnScan)
                        Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                        Toggle("Sound Chime", isOn: $soundEnabled)
                    } header: {
                        Text("Preferences")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                    } footer: {
                        Text("Plays an instant chime and haptic confirmation when any QR or barcode is recognized.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .listRowBackground(Color.white.opacity(0.06))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showSettingsSheet = false
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.fraction(0.35), .medium])
    }

    private var centralViewfinder: some View {
        ZStack {
            // Clean Reticle Brackets
            ScannerReticleView()
                .frame(width: cutoutSize, height: cutoutSize)

            // Sleek Scan Laser Line
            if !isPaused {
                ScanningLaserView()
                    .frame(width: cutoutSize - 16, height: cutoutSize)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }
        .frame(width: cutoutSize, height: cutoutSize)
    }

    private var batchReviewChip: some View {
        Button {
            showHistorySheet = true
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 7, height: 7)

                Text("Batch: \(batchScanCount) captured")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(Color.black.opacity(0.7)))
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var batchToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(batchHUDMessage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
                .shadow(color: Color.black.opacity(0.35), radius: 8)
        )
        .transition(.scale.combined(with: .opacity))
    }

    private var bottomControls: some View {
        HStack(spacing: 14) {
            // Sleek Segmented Zoom Pill
            HStack(spacing: 2) {
                ForEach(zoomPresets, id: \.self) { preset in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            zoomFactor = preset
                        }
                    } label: {
                        Text("\(Int(preset))x")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(zoomFactor == preset ? Color.black : Color.white.opacity(0.75))
                            .frame(width: 38, height: 28)
                            .background {
                                if zoomFactor == preset {
                                    Capsule().fill(Color.white)
                                }
                            }
                    }
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)

            // Live Camera Text OCR Button
            Button {
                initialOCRText = ""
                showTextOCRSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cyan)
                    Text("Live OCR")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.glass)

            // Photo Library QR Scanner Pill
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .medium))
                    Text("Photos")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.glass)
        }
    }

    private var simulatorTestChip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("URL") {
                    handleDetectedCode("https://apple.com/visionos")
                }
                .buttonStyle(.glass)

                Button("Wi-Fi") {
                    handleDetectedCode("WIFI:S:ApplePark_Guest;T:WPA;P:LiquidGlass2026;;")
                }
                .buttonStyle(.glass)

                Button("Contact") {
                    handleDetectedCode("BEGIN:VCARD\nVERSION:3.0\nFN:Craig Federighi\nTEL:+15551234567\nEMAIL:craig@apple.com\nORG:Apple Inc.\nEND:VCARD")
                }
                .buttonStyle(.glass)

                Button("SMS") {
                    handleDetectedCode("SMSTO:+15551234567:Let us meet at Infinite Loop!")
                }
                .buttonStyle(.glass)

                Button("Email") {
                    handleDetectedCode("mailto:developer@apple.com")
                }
                .buttonStyle(.glass)

                Button("Note") {
                    handleDetectedCode("GlassQR: Ultra-clean minimal interface")
                }
                .buttonStyle(.glass)

                Button("EAN-13") {
                    handleDetectedCode("4006381333931", symbology: "EAN-13")
                }
                .buttonStyle(.glass)

                Button("Code 128") {
                    handleDetectedCode("PKG-99281-US", symbology: "Code 128")
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, 10)
        }
        .controlSize(.small)
        .padding(.vertical, 6)
        .glassEffect()
    }

    // MARK: - Logic & Scanning Methods

    private var historyCount: Int {
        loadHistory().count
    }

    private func handleDetectedCode(_ code: String, symbology: String = "QR Code") {
        // Throttling: Ignore identical duplicate scans within 1.5 seconds
        let now = Date()
        if code == lastScannedPayload && now.timeIntervalSince(lastScannedTimestamp) < 1.5 {
            return
        }

        lastScannedPayload = code
        lastScannedTimestamp = now

        if hapticsEnabled {
            scanFeedbackTrigger += 1
        }

        if soundEnabled {
            AudioServicesPlaySystemSound(1057)
        }

        if autoCopyOnScan {
            UIPasteboard.general.string = code
        }

        let item = ScanResultItem(payload: code, symbology: symbology)
        saveToHistory(item)

        if isBatchMode {
            // Batch Mode: Keep scanning and show lightweight toast
            batchScanCount += 1
            let prefix = autoCopyOnScan ? "Copied: " : "Saved: "
            batchHUDMessage = "\(prefix)\(code.prefix(22))..."
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showBatchHUD = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showBatchHUD = false
                }
            }
        } else {
            // Single Mode: Pop sheet
            guard activeScanResult == nil else { return }
            activeScanResult = item
        }
    }

    private func triggerFocusAnimation(at point: CGPoint) {
        focusPoint = point
        withAnimation(.easeOut(duration: 0.15)) {
            showFocusRing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.easeIn(duration: 0.2)) {
                showFocusRing = false
            }
        }
    }

    private func saveToHistory(_ item: ScanResultItem) {
        var items = loadHistory()
        items.insert(item, at: 0)
        if items.count > 100 {
            items = Array(items.prefix(100))
        }
        if let encoded = try? JSONEncoder().encode(items),
           let str = String(data: encoded, encoding: .utf8) {
            scanHistoryData = str
        }
    }

    private func loadHistory() -> [ScanResultItem] {
        guard let data = scanHistoryData.data(using: .utf8),
              let list = try? JSONDecoder().decode([ScanResultItem].self, from: data) else {
            return []
        }
        return list
    }

    private func analyzePickedPhoto(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        isAnalyzingPhoto = true
        defer {
            isAnalyzingPhoto = false
            selectedPhotoItem = nil
        }

        guard let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data),
              let ciImage = CIImage(image: uiImage) else { return }

        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        let features = detector?.features(in: ciImage) ?? []

        for feature in features {
            if let qrFeature = feature as? CIQRCodeFeature, let message = qrFeature.messageString {
                await MainActor.run {
                    handleDetectedCode(message)
                }
                return
            }
        }

        // Vision OCR fallback if no barcode/QR is found in the photo
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        if (try? handler.perform([request])) != nil,
           let observations = request.results,
           !observations.isEmpty {
            let extracted = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            let trimmed = extracted.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                await MainActor.run {
                    initialOCRText = trimmed
                    showTextOCRSheet = true
                }
            }
        }
    }
}

// MARK: - Searchable & Categorized Scan History Sheet with CSV Export

private struct ScanHistoryView: View {
    @Binding var historyData: String
    let onSelectResult: (ScanResultItem) -> Void
    @Environment(\.dismiss) private var dismiss

    private enum HistoryCategoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case links = "Links"
        case wifi = "Wi-Fi"
        case barcodes = "Barcodes"
        case contacts = "Contacts"
        case sms = "SMS"
        case text = "Text"

        var id: String { rawValue }
    }

    @State private var selectedFilter: HistoryCategoryFilter = .all
    @State private var searchText: String = ""

    var allItems: [ScanResultItem] {
        guard let data = historyData.data(using: .utf8),
              let list = try? JSONDecoder().decode([ScanResultItem].self, from: data) else {
            return []
        }
        return list
    }

    var filteredItems: [ScanResultItem] {
        var items = allItems

        // Apply category filter
        switch selectedFilter {
        case .all: break
        case .links:
            items = items.filter { if case .webURL = $0.category { return true }; return false }
        case .wifi:
            items = items.filter { if case .wifi = $0.category { return true }; return false }
        case .barcodes:
            items = items.filter { if case .productBarcode = $0.category { return true }; return false }
        case .contacts:
            items = items.filter { if case .contact = $0.category { return true }; return false }
        case .sms:
            items = items.filter { if case .sms = $0.category { return true }; return false }
        case .text:
            items = items.filter { if case .text = $0.category { return true }; return false }
        }

        // Apply search query
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            items = items.filter { $0.payload.localizedCaseInsensitiveContains(query) }
        }

        return items
    }

    var exportedCSV: String {
        var csv = "Timestamp,Payload\n"
        for item in allItems {
            let clean = item.payload.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\"\(item.timestamp.ISO8601Format())\",\"\(clean)\"\n"
        }
        return csv
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.08)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Category Filter Pills
                    if !allItems.isEmpty {
                        categoryFilterBar
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }

                    if allItems.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "tray")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.white.opacity(0.25))

                            Text("No Scan History")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                    } else if filteredItems.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32, weight: .light))
                                .foregroundStyle(.white.opacity(0.25))

                            Text("No matching items found")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredItems) { item in
                                Button {
                                    dismiss()
                                    onSelectResult(item)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: iconFor(item))
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.85))
                                            .frame(width: 28)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.payload)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)

                                            Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.45))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(.white.opacity(0.25))
                                    }
                                    .padding(.vertical, 3)
                                }
                                .listRowBackground(Color.white.opacity(0.05))
                            }
                            .onDelete(perform: deleteItem)
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
                .searchable(text: $searchText, prompt: "Search scanned codes...")
            }
            .navigationTitle("History (\(allItems.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !allItems.isEmpty {
                        Menu {
                            ShareLink(
                                item: exportedCSV,
                                preview: SharePreview("ScanHistory.csv")
                            ) {
                                Label("Export CSV", systemImage: "arrow.up.doc")
                            }

                            Button(role: .destructive) {
                                historyData = "[]"
                            } label: {
                                Label("Clear All History", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                }
            }
        }
    }

    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(HistoryCategoryFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .foregroundStyle(selectedFilter == filter ? Color.black : Color.white.opacity(0.75))
                            .background {
                                if selectedFilter == filter {
                                    Capsule().fill(Color.white)
                                } else {
                                    Capsule().fill(Color.white.opacity(0.08))
                                }
                            }
                    }
                }
            }
        }
    }

    private func deleteItem(at offsets: IndexSet) {
        let itemsToDelete = offsets.map { filteredItems[$0] }
        var list = allItems
        list.removeAll { item in itemsToDelete.contains { $0.id == item.id } }
        if let encoded = try? JSONEncoder().encode(list),
           let str = String(data: encoded, encoding: .utf8) {
            historyData = str
        }
    }

    private func iconFor(_ item: ScanResultItem) -> String {
        switch item.category {
        case .webURL: return "link"
        case .wifi: return "wifi"
        case .email: return "envelope"
        case .phone: return "phone"
        case .sms: return "message.fill"
        case .contact: return "person.crop.circle"
        case .geo: return "map.fill"
        case .productBarcode: return "barcode.viewfinder"
        case .text: return "doc.text"
        }
    }
}
