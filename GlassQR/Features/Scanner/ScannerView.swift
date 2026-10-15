//
//  ScannerView.swift
//  GlassQR
//
//  iOS 26 Liquid Glass Optical Scanner Interface
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
    @State private var showSimulatorDrawer: Bool = false

    private let zoomPresets: [CGFloat] = [0.5, 1.0, 2.0, 3.0]
    private let viewfinderSize: CGFloat = 270

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack {
            // Live Camera Feed Layer
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

            // Cinematic Frosted Vignette with Viewfinder Cutout
            GeometryReader { proxy in
                let size = proxy.size
                let rect = CGRect(
                    x: (size.width - viewfinderSize) / 2,
                    y: (size.height - viewfinderSize) / 2 - 20,
                    width: viewfinderSize,
                    height: viewfinderSize
                )

                ZStack {
                    // Dark ambient frosted glass mask outside cutout
                    Color.black.opacity(0.42)
                        .mask {
                            Rectangle()
                                .overlay {
                                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                                        .frame(width: rect.width, height: rect.height)
                                        .position(x: rect.midX, y: rect.midY)
                                        .blendMode(.destinationOut)
                                }
                        }
                        .allowsHitTesting(false)
                }
            }
            .ignoresSafeArea()

            // Tap-to-focus Pulsing Liquid Glass Ring
            if showFocusRing, let point = focusPoint {
                ZStack {
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 64, height: 64)
                        .shadow(color: .cyan, radius: 10)

                    Circle()
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                        .frame(width: 48, height: 48)

                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 4, height: 4)
                }
                .position(point)
                .transition(.scale.combined(with: .opacity))
            }

            // Foreground UI Controls Overlay
            VStack(spacing: 0) {
                // Top Floating Command Platter
                topCommandBar
                    .padding(.top, 14)
                    .padding(.horizontal, 20)

                Spacer()

                // Center Holographic Viewfinder Region
                centralViewfinderFrame
                    .padding(.bottom, 20)

                Spacer()

                // Bottom Liquid Glass Controls (Zoom + Photos)
                bottomControlsBar
                    .padding(.bottom, 24)
                    .padding(.horizontal, 24)

                // Expandable Simulator Testing Platter
                if isSimulatedSession {
                    simulatorTestingConsole
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

    // MARK: - UI Components

    private var topCommandBar: some View {
        VStack(spacing: 12) {
            // Primary Control Platter
            GlassEffectContainer(spacing: 14) {
                // Torch Button with Glowing Active State
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isTorchOn.toggle()
                    }
                } label: {
                    Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isTorchOn ? Color.yellow : Color.white)
                        .symbolEffect(.bounce, value: isTorchOn)
                }
                .buttonStyle(.glass)
                .background {
                    if isTorchOn {
                        Circle()
                            .fill(Color.yellow.opacity(0.25))
                            .blur(radius: 10)
                    }
                }
                .glassEffectID("torchControl", in: scannerNamespace)

                // Camera Flip (Rear / Front)
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        cameraPosition = (cameraPosition == .back) ? .front : .back
                    }
                } label: {
                    Image(systemName: "camera.rotate.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("flipControl", in: scannerNamespace)

                // Scan History Drawer Button with Counter Badge
                Button {
                    showHistorySheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        let count = historyCount
                        if count > 0 {
                            Circle()
                                .fill(Color.cyan)
                                .frame(width: 8, height: 8)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.glass)
                .glassEffectID("historyControl", in: scannerNamespace)

                // Scanner Pause / Resume Toggle
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                        isPaused.toggle()
                    }
                } label: {
                    Image(systemName: isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isPaused ? Color.orange : Color.white)
                }
                .buttonStyle(.glass)
                .glassEffectID("pauseControl", in: scannerNamespace)
            }

            // Status Lensing Pill
            HStack(spacing: 8) {
                Circle()
                    .fill(isPaused ? Color.orange : Color.green)
                    .frame(width: 7, height: 7)
                    .shadow(color: isPaused ? .orange : .green, radius: 4)

                Text(isPaused ? "SCANNER PAUSED" : "OPTICAL ENGINE READY")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .tracking(1.2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .glassEffect()
        }
    }

    private var centralViewfinderFrame: some View {
        ZStack {
            // Specular Glass Border Frame
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.cyan.opacity(0.3),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: viewfinderSize, height: viewfinderSize)
                .glassEffect(.clear, in: .rect(cornerRadius: 32))

            // Holographic Optical Reticle with Radar Sweep
            ScannerReticleView()
                .frame(width: viewfinderSize, height: viewfinderSize)

            // Radiant Dual-Core Scanning Laser
            if !isPaused {
                ScanningLaserView()
                    .frame(width: viewfinderSize - 20, height: viewfinderSize)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
        }
        .frame(width: viewfinderSize, height: viewfinderSize)
    }

    private var bottomControlsBar: some View {
        HStack(spacing: 16) {
            // Segmented Liquid Glass Zoom Capsule
            HStack(spacing: 4) {
                ForEach(zoomPresets, id: \.self) { preset in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            zoomFactor = preset
                        }
                    } label: {
                        Text(preset == 0.5 ? ".5x" : "\(Int(preset))x")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(zoomFactor == preset ? .cyan : .white.opacity(0.72))
                            .frame(minWidth: 38, minHeight: 32)
                            .background {
                                if zoomFactor == preset {
                                    Capsule()
                                        .fill(Color.white.opacity(0.18))
                                        .shadow(color: Color.black.opacity(0.2), radius: 4)
                                }
                            }
                    }
                }
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)

            // Photo Library QR Scanner Pill
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Photos")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
            }
            .buttonStyle(.glass)
        }
    }

    private var simulatorTestingConsole: some View {
        VStack(spacing: 8) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    showSimulatorDrawer.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.cyan)
                    Text("Simulator Test Payloads")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                    Image(systemName: showSimulatorDrawer ? "chevron.down" : "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
            .buttonStyle(.glass)

            if showSimulatorDrawer {
                HStack(spacing: 8) {
                    Button("URL") {
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

                    Button("Note") {
                        handleDetectedCode("Liquid Glass iOS 26 Scanner Active")
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.small)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    // MARK: - Helper Methods

    private var historyCount: Int {
        guard let data = scanHistoryData.data(using: .utf8),
              let list = try? JSONDecoder().decode([ScanResultItem].self, from: data) else {
            return 0
        }
        return list.count
    }

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
