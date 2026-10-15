//
//  ScannerView.swift
//  GlassQR
//

import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage

public struct ScannerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var scannerNamespace

    // Camera Controls
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
    @State private var showHistorySheet: Bool = false
    @AppStorage("glassqr_scan_history") private var scanHistoryData: String = "[]"

    // Photo Library Picker
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzingPhoto: Bool = false
    @State private var photoScanAlertMessage: String? = nil

    private let zoomPresets: [CGFloat] = [1.0, 2.0, 3.0]

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack {
            // Live Camera View with Tap-to-Focus & Zoom
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

            // Tap-to-focus Pulsing Ring Overlay
            if showFocusRing, let point = focusPoint {
                Circle()
                    .stroke(Color.cyan, lineWidth: 2)
                    .frame(width: 68, height: 68)
                    .shadow(color: .cyan, radius: 8)
                    .position(point)
                    .transition(.scale.combined(with: .opacity))
            }

            // Scanner Interface Overlays
            VStack(spacing: 16) {
                // Top Floating HUD inside GlassEffectContainer
                topHUD
                    .padding(.top, 16)

                // Floating Guidance Pill
                guidancePill

                Spacer()

                // Central Liquid Glass Viewfinder Overlay
                centralViewfinder

                Spacer()

                // Bottom Controls: Zoom Platter & Photo Picker
                bottomControls
                    .padding(.bottom, 20)

                // Simulator / Preview Fallback Multi-Tool
                if isSimulatedSession {
                    simulatorTestConsole
                        .padding(.bottom, 12)
                }
            }
        }
        .navigationTitle("Liquid Scanner")
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

    // MARK: - Subviews

    private var topHUD: some View {
        GlassEffectContainer(spacing: 14) {
            // Torch / Flashlight Toggle
            Button {
                isTorchOn.toggle()
            } label: {
                Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isTorchOn ? .yellow : .white)
            }
            .buttonStyle(.glass)
            .glassEffectID("torchControl", in: scannerNamespace)

            // Camera Flip (Front / Back)
            Button {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                    cameraPosition = (cameraPosition == .back) ? .front : .back
                }
            } label: {
                Image(systemName: "camera.rotate.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .glassEffectID("flipControl", in: scannerNamespace)

            // Scan History Drawer
            Button {
                showHistorySheet = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .glassEffectID("historyControl", in: scannerNamespace)

            // Pause / Resume Toggle
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    isPaused.toggle()
                }
            } label: {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.glass)
            .glassEffectID("pauseControl", in: scannerNamespace)
        }
    }

    private var guidancePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isPaused ? Color.orange : Color.green)
                .frame(width: 8, height: 8)

            Text(isPaused ? "Scanner Paused" : "Align QR Code Inside Glass Frame")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 8)
        .glassEffect()
    }

    private var centralViewfinder: some View {
        ZStack {
            // Floating Viewfinder Frame
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                .frame(width: 270, height: 270)
                .glassEffect(.clear, in: .rect(cornerRadius: 32))

            // Specular Reticle Brackets
            ScannerReticleView()
                .frame(width: 270, height: 270)

            // Animated Refractive Laser
            if !isPaused {
                ScanningLaserView()
                    .frame(width: 250, height: 270)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
    }

    private var bottomControls: some View {
        HStack(spacing: 16) {
            // Zoom Selector Platter
            HStack(spacing: 8) {
                ForEach(zoomPresets, id: \.self) { preset in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            zoomFactor = preset
                        }
                    } label: {
                        Text("\(Int(preset))x")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(zoomFactor == preset ? .cyan : .white.opacity(0.7))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background {
                                if zoomFactor == preset {
                                    Capsule().fill(Color.white.opacity(0.2))
                                }
                            }
                    }
                }
            }
            .padding(6)
            .glassEffect(.regular.interactive(), in: .capsule)

            // Photo Library QR Scanner Button
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("Photos", systemImage: "photo.on.rectangle.angled")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.glass)
        }
    }

    private var simulatorTestConsole: some View {
        VStack(spacing: 8) {
            Text("Preview Simulation Presets")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))

            HStack(spacing: 10) {
                Button("Web URL") {
                    handleDetectedCode("https://apple.com/visionos")
                }
                .buttonStyle(.glass)

                Button("Wi-Fi") {
                    handleDetectedCode("WIFI:S:ApplePark_Liquid;T:WPA;P:SwiftUI2026;;")
                }
                .buttonStyle(.glass)

                Button("Email") {
                    handleDetectedCode("mailto:developer@apple.com")
                }
                .buttonStyle(.glass)

                Button("Text") {
                    handleDetectedCode("Liquid Glass iOS 26 Design System Active")
                }
                .buttonStyle(.glass)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
    }

    // MARK: - Logic & Scanning Methods

    private func handleDetectedCode(_ code: String) {
        guard activeScanResult == nil else { return }
        scanFeedbackTrigger += 1
        let item = ScanResultItem(payload: code)
        activeScanResult = item
        saveToHistory(item)
    }

    private func triggerFocusAnimation(at point: CGPoint) {
        focusPoint = point
        withAnimation(.easeOut(duration: 0.2)) {
            showFocusRing = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.25)) {
                showFocusRing = false
            }
        }
    }

    private func saveToHistory(_ item: ScanResultItem) {
        var items = loadHistory()
        items.insert(item, at: 0)
        if items.count > 50 {
            items = Array(items.prefix(50))
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

// MARK: - Scan History Sheet View

private struct ScanHistoryView: View {
    @Binding var historyData: String
    let onSelectResult: (ScanResultItem) -> Void
    @Environment(\.dismiss) private var dismiss

    var items: [ScanResultItem] {
        guard let data = historyData.data(using: .utf8),
              let list = try? JSONDecoder().decode([ScanResultItem].self, from: data) else {
            return []
        }
        return list
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No Scan History")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                } else {
                    List {
                        ForEach(items) { item in
                            Button {
                                dismiss()
                                onSelectResult(item)
                            } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: iconFor(item))
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.cyan)
                                        .frame(width: 32)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.payload)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        Text(item.timestamp.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 11, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.white.opacity(0.08))
                        }
                        .onDelete(perform: deleteItem)
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !items.isEmpty {
                        Button("Clear All") {
                            historyData = "[]"
                        }
                        .foregroundStyle(.red.opacity(0.8))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func deleteItem(at offsets: IndexSet) {
        var list = items
        list.remove(atOffsets: offsets)
        if let encoded = try? JSONEncoder().encode(list),
           let str = String(data: encoded, encoding: .utf8) {
            historyData = str
        }
    }

    private func iconFor(_ item: ScanResultItem) -> String {
        switch item.category {
        case .webURL: return "globe"
        case .wifi: return "wifi"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .text: return "text.viewfinder"
        }
    }
}
