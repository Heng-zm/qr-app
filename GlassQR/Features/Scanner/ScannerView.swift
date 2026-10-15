//
//  ScannerView.swift
//  GlassQR
//

import SwiftUI

public struct ScannerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var scannerNamespace

    @State private var isTorchOn: Bool = false
    @State private var isPaused: Bool = false
    @State private var activeScanResult: ScanResultItem? = nil
    @State private var scanFeedbackTrigger: Int = 0
    @State private var isSimulatedSession: Bool = false

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack {
            // Live Camera View or Simulator Fallback
            CameraEngineRepresentable(
                isTorchOn: $isTorchOn,
                isPaused: $isPaused,
                isSimulatedSession: $isSimulatedSession,
                onCodeDetected: { code in
                    handleDetectedCode(code)
                }
            )
            .ignoresSafeArea()

            // Viewfinder & Overlay UI
            VStack(spacing: 24) {
                // Top Floating HUD inside GlassEffectContainer
                GlassEffectContainer(spacing: 20) {
                    // Torch / Flashlight Toggle
                    Button {
                        isTorchOn.toggle()
                    } label: {
                        Label(
                            isTorchOn ? "Torch On" : "Torch Off",
                            systemImage: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
                        )
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("torchControl", in: scannerNamespace)

                    // Pause / Resume Toggle
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                            isPaused.toggle()
                        }
                    } label: {
                        Label(
                            isPaused ? "Resume" : "Pause",
                            systemImage: isPaused ? "play.fill" : "pause.fill"
                        )
                    }
                    .buttonStyle(.glass)
                    .glassEffectID("pauseControl", in: scannerNamespace)
                }
                .padding(.top, 16)

                // Floating Guidance Pill
                Text(isPaused ? "Scanner Paused" : "Align QR code inside liquid frame")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .glassEffect()

                Spacer()

                // Central Liquid Glass Viewfinder Overlay
                ZStack {
                    // Frame
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.4), lineWidth: 2)
                        .frame(width: 260, height: 260)
                        .glassEffect(.clear, in: .rect(cornerRadius: 32))

                    // Corner Brackets
                    ScannerReticleView()
                        .frame(width: 260, height: 260)

                    // Scanning Liquid Laser Beam
                    if !isPaused {
                        ScanningLaserView()
                            .frame(width: 240, height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    }
                }

                Spacer()

                // Simulator / Preview Fallback Button
                if isSimulatedSession {
                    VStack(spacing: 10) {
                        Button {
                            handleDetectedCode("https://apple.com/visionos")
                        } label: {
                            Label("Simulate QR Scan (Preview Mode)", systemImage: "sparkle.magnifyingglass")
                        }
                        .buttonStyle(.glassProminent)

                        Text("Xcode Simulator camera bypass active")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle("Liquid Scanner")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: scanFeedbackTrigger)
        .sheet(item: $activeScanResult) { result in
            ScanResultSheetView(result: result)
                .presentationDetents([.medium])
        }
    }

    private func handleDetectedCode(_ code: String) {
        guard activeScanResult == nil else { return }
        scanFeedbackTrigger += 1
        activeScanResult = ScanResultItem(payload: code)
    }
}
