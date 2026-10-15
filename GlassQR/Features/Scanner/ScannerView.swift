//
//  ScannerView.swift
//  GlassQR
//
//  Optimized Scanner Interface with Batch Mode, History Search, & CSV Export
//

import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage

public struct ScannerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var scannerNamespace

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
    @AppStorage("glassqr_scan_history") private var scanHistoryData: String = "[]"

    // Photo Library Picker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzingPhoto: Bool = false

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
                onCodeDetected: { code in
                    handleDetectedCode(code)
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

                // Transient Batch Scan Toast
                if showBatchHUD {
                    batchToast
                        .padding(.bottom, 10)
                }

                // Bottom Minimalist Controls: Zoom & Photo Picker
                bottomControls
                    .padding(.bottom, 22)
                    .padding(.horizontal, 24)

                // Simulator Test Chip (Preview mode)
                if isSimulatedSession {
                    simulatorTestChip
                        .padding(.bottom, 10)
                }
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
        HStack(spacing: 8) {
            Button("URL") {
                handleDetectedCode("https://apple.com/visionos")
            }
            .buttonStyle(.glass)

            Button("Wi-Fi") {
                handleDetectedCode("WIFI:S:ApplePark_Guest;T:WPA;P:LiquidGlass2026;;")
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
        }
        .controlSize(.small)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassEffect()
    }

    // MARK: - Logic & Scanning Methods

    private var historyCount: Int {
        loadHistory().count
    }

    private func handleDetectedCode(_ code: String) {
        // Throttling: Ignore identical duplicate scans within 1.5 seconds
        let now = Date()
        if code == lastScannedPayload && now.timeIntervalSince(lastScannedTimestamp) < 1.5 {
            return
        }

        lastScannedPayload = code
        lastScannedTimestamp = now
        scanFeedbackTrigger += 1
        let item = ScanResultItem(payload: code)
        saveToHistory(item)

        if isBatchMode {
            // Batch Mode: Keep scanning and show lightweight toast
            batchScanCount += 1
            batchHUDMessage = "Saved: \(code.prefix(24))..."
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
    }
}

// MARK: - Searchable Scan History Sheet with CSV Export

private struct ScanHistoryView: View {
    @Binding var historyData: String
    let onSelectResult: (ScanResultItem) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchText: String = ""

    var allItems: [ScanResultItem] {
        guard let data = historyData.data(using: .utf8),
              let list = try? JSONDecoder().decode([ScanResultItem].self, from: data) else {
            return []
        }
        return list
    }

    var filteredItems: [ScanResultItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allItems
        }
        return allItems.filter {
            $0.payload.localizedCaseInsensitiveContains(searchText)
        }
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

                if allItems.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "tray")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.white.opacity(0.25))

                        Text("No Scan History")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
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
                    .searchable(text: $searchText, prompt: "Search scanned codes...")
                }
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

    private func deleteItem(at offsets: IndexSet) {
        var list = allItems
        list.remove(atOffsets: offsets)
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
        case .text: return "doc.text"
        }
    }
}
