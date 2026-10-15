//
//  GlassQRApp.swift
//  GlassQR
//
//  Targeting iOS 26.0+ & Xcode 26
//  Native Liquid Glass Design System Architecture
//

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AVFoundation

// MARK: - App Main Entry Point

@main
struct GlassQRApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            RootContentView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root Content Coordinator

struct RootContentView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var rootTransitionNamespace

    var body: some View {
        ZStack {
            // Persistent fluid background layer refracting through all Liquid Glass platters
            LiquidMeshGradientView()
                .ignoresSafeArea()

            if !hasCompletedOnboarding {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .glassEffectTransition(.materialize)
            } else {
                MainGlassTabView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .glassEffectTransition(.materialize)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: hasCompletedOnboarding)
    }
}

// MARK: - Screen 1: Welcome & Onboarding Screen

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var welcomeNamespace
    @State private var cardsAppeared: Bool = false
    @State private var emblemBounce: Int = 0
    @State private var buttonHapticTrigger: Int = 0

    private let features: [FeatureHighlight] = [
        FeatureHighlight(
            id: "vector",
            icon: "qrcode",
            title: "Instant Vector QR",
            subtitle: "Generate ultra-crisp vector QR codes in real time as you type."
        ),
        FeatureHighlight(
            id: "viewfinder",
            icon: "qrcode.viewfinder",
            title: "Live Glass Viewfinder",
            subtitle: "Hardware-accelerated live recognition with native Liquid Glass lensing."
        ),
        FeatureHighlight(
            id: "liquidShare",
            icon: "square.and.arrow.up.fill",
            title: "One-Tap Liquid Share",
            subtitle: "Fluidly export and share high-res codes with native glass sheets."
        )
    ]

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 20)

            // Floating Hero Emblem
            VStack(spacing: 16) {
                ZStack {
                    Image(systemName: "qrcode")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.breathe, options: .repeating)
                        .symbolEffect(.bounce, value: emblemBounce)
                }
                .frame(width: 110, height: 110)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 36))
                .onTapGesture {
                    emblemBounce += 1
                }

                VStack(spacing: 6) {
                    Text("GlassQR")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("The Future of Optical Data Interaction")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, 16)

            // Staggered Liquid Glass Feature Cards
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 14) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeatureCardView(feature: feature)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                            .offset(y: cardsAppeared ? 0 : 40)
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.76).delay(Double(index) * 0.12),
                                value: cardsAppeared
                            )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Morphing Bottom Call-to-Action Bar
            GlassEffectContainer(spacing: 16) {
                Button {
                    buttonHapticTrigger += 1
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .symbolEffect(.bounce, value: buttonHapticTrigger)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .glassEffectID("welcomeCTA", in: welcomeNamespace)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: buttonHapticTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: emblemBounce)
        .onAppear {
            cardsAppeared = true
        }
    }
}

private struct FeatureHighlight: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
}

private struct FeatureCardView: View {
    let feature: FeatureHighlight
    @State private var iconBounce: Int = 0

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Image(systemName: feature.icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .symbolEffect(.bounce, value: iconBounce)
            }
            .frame(width: 48, height: 48)
            .background(Circle().fill(Color.white.opacity(0.1)))

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(feature.subtitle)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .contentShape(Rectangle())
        .onTapGesture {
            iconBounce += 1
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: iconBounce)
    }
}

// MARK: - Main Application TabView (Native iOS 26 Liquid Platter)

struct MainGlassTabView: View {
    @Binding var hasCompletedOnboarding: Bool

    var body: some View {
        TabView {
            Tab("Generate", systemImage: "qrcode") {
                NavigationStack {
                    GeneratorView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
            }

            Tab("Scan", systemImage: "qrcode.viewfinder") {
                NavigationStack {
                    ScannerView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
            }
        }
    }
}

// Quick Test Toolbar Button to replay the Welcome Screen
private struct ReplayOnboardingButton: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var hapticCount: Int = 0

    var body: some View {
        Button {
            hapticCount += 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                hasCompletedOnboarding = false
            }
        } label: {
            Label("Replay Welcome", systemImage: "sparkles")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticCount)
        .help("Replay Liquid Glass Welcome Screen")
    }
}

// MARK: - Screen 2: QR Code Generator Tab ("Generate")

struct GeneratorView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var generatorNamespace

    @State private var inputText: String = "https://apple.com"
    @State private var qrImage: UIImage? = nil
    @State private var copyHapticTrigger: Int = 0
    @State private var showCopiedHUD: Bool = false

    private let generatorEngine = CrispQRRenderer()

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Interactive Glass Input Bar
                GlassEffectContainer(spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "link")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.cyan)

                        TextField("Enter URL, Wi-Fi or Plain Text...", text: $inputText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)

                        if !inputText.isEmpty {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    inputText = ""
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            .buttonStyle(.glass)
                            .glassEffectID("clearButton", in: generatorNamespace)
                            .glassEffectTransition(.materialize)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("inputFieldCapsule", in: generatorNamespace)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Crisp QR Vector Rendering Card
                VStack(spacing: 18) {
                    if let image = qrImage {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 8)

                            Image(uiImage: image)
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .padding(22)
                        }
                        .frame(width: 260, height: 260)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32))
                        .glassEffectTransition(.materialize)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.08))

                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 54))
                                    .foregroundStyle(.white.opacity(0.35))
                                    .symbolEffect(.breathe, options: .repeating)

                                Text("Type to generate Liquid QR")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .frame(width: 260, height: 260)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 32))
                    }
                }
                .padding(.vertical, 8)

                // Morphing Action Bar (Expands dynamically from droplet)
                if !inputText.isEmpty, let image = qrImage {
                    GlassEffectContainer(spacing: 20) {
                        // Copy Button
                        Button {
                            UIPasteboard.general.image = image
                            copyHapticTrigger += 1
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                showCopiedHUD = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showCopiedHUD = false
                                }
                            }
                        } label: {
                            Label("Copy Image", systemImage: "doc.on.doc.fill")
                        }
                        .buttonStyle(.glass)
                        .glassEffectID("copyActionButton", in: generatorNamespace)

                        // Native ShareLink Button
                        ShareLink(
                            item: Image(uiImage: image),
                            preview: SharePreview("Liquid QR Code", image: Image(uiImage: image))
                        ) {
                            Label("Share Code", systemImage: "square.and.arrow.up.fill")
                        }
                        .buttonStyle(.glassProminent)
                        .glassEffectID("shareActionButton", in: generatorNamespace)
                    }
                    .glassEffectTransition(.materialize)
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
                }

                // Transient Copy HUD Pill
                if showCopiedHUD {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("QR Image Copied to Clipboard")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassEffect()
                    .glassEffectTransition(.materialize)
                }

                Spacer(minLength: 40)
            }
        }
        .navigationTitle("Liquid Generator")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            renderQR(for: inputText)
        }
        .onChange(of: inputText) { _, newValue in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                renderQR(for: newValue)
            }
        }
    }

    private func renderQR(for text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            qrImage = nil
            return
        }
        qrImage = generatorEngine.render(text: text)
    }
}

// High-performance CoreImage QR Generator Engine
private final class CrispQRRenderer: Sendable {
    private let context = CIContext()

    func render(text: String) -> UIImage? {
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

// MARK: - Screen 3: QR Code Scanner Tab ("Scan")

struct ScannerView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var scannerNamespace

    @State private var isTorchOn: Bool = false
    @State private var isPaused: Bool = false
    @State private var activeScanResult: ScanResultItem? = nil
    @State private var scanFeedbackTrigger: Int = 0
    @State private var isSimulatedSession: Bool = false

    var body: some View {
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

// Scanning Reticle Corners
private struct ScannerReticleView: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let length: CGFloat = 28
            let thickness: CGFloat = 4

            Path { path in
                // Top Left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))

                // Top Right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))

                // Bottom Left
                path.move(to: CGPoint(x: 0, y: h - length))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: length, y: h))

                // Bottom Right
                path.move(to: CGPoint(x: w - length, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(Color.cyan, style: StrokeStyle(lineWidth: thickness, lineCap: .round, lineJoin: .round))
        }
    }
}

// Animated Scanning Laser Bar
private struct ScanningLaserView: View {
    @State private var scanOffset: CGFloat = -110

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .cyan.opacity(0.0),
                        .cyan.opacity(0.85),
                        .white,
                        .cyan.opacity(0.85),
                        .cyan.opacity(0.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 3)
            .shadow(color: .cyan, radius: 8, x: 0, y: 0)
            .offset(y: scanOffset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 1.8)
                    .repeatForever(autoreverses: true)
                ) {
                    scanOffset = 110
                }
            }
    }
}

// Scan Result Model for Native Glass Sheet Presentation
struct ScanResultItem: Identifiable, Equatable {
    let id = UUID()
    let payload: String
    let timestamp: Date = Date()

    var isWebURL: Bool {
        guard let url = URL(string: payload),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

// Native Glass Sheet Presentation for Detected QR Codes
struct ScanResultSheetView: View {
    let result: ScanResultItem
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var copied: Bool = false
    @State private var copyHapticTrigger: Int = 0

    var body: some View {
        ZStack {
            // Refracting Mesh Gradient Sheet Backdrop
            LiquidMeshGradientView()
                .ignoresSafeArea()

            VStack(spacing: 22) {
                // Drag Indicator Cap
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                // Header
                HStack(spacing: 12) {
                    Image(systemName: result.isWebURL ? "globe" : "text.viewfinder")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.isWebURL ? "Web Link Detected" : "Text Payload Detected")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(result.timestamp.formatted(date: .abbreviated, time: .standard))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                // Decoded Content Display Box
                VStack(alignment: .leading, spacing: 8) {
                    Text("PAYLOAD")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))

                    ScrollView {
                        Text(result.payload)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 100)
                }
                .padding(18)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
                .padding(.horizontal, 24)

                // Interactive Glass Buttons
                HStack(spacing: 16) {
                    Button {
                        UIPasteboard.general.string = result.payload
                        copyHapticTrigger += 1
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            copied = true
                        }
                    } label: {
                        Label(copied ? "Copied!" : "Copy Payload", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    if result.isWebURL, let url = URL(string: result.payload) {
                        Button {
                            openURL(url)
                            dismiss()
                        } label: {
                            Label("Open in Safari", systemImage: "arrow.up.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent)
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 10)
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: copyHapticTrigger)
    }
}

// MARK: - AVCaptureSession Camera Engine & Simulator Fallback

private struct CameraEngineRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var isPaused: Bool
    @Binding var isSimulatedSession: Bool
    let onCodeDetected: (String) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
        uiViewController.setPaused(isPaused)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraEngineRepresentable

        init(parent: CameraEngineRepresentable) {
            self.parent = parent
        }

        func cameraViewController(_ controller: CameraViewController, didOutputCode code: String) {
            DispatchQueue.main.async {
                self.parent.onCodeDetected(code)
            }
        }

        func cameraViewControllerDidFallbackToSimulation(_ controller: CameraViewController) {
            DispatchQueue.main.async {
                self.parent.isSimulatedSession = true
            }
        }
    }
}

private protocol CameraViewControllerDelegate: AnyObject {
    func cameraViewController(_ controller: CameraViewController, didOutputCode code: String)
    func cameraViewControllerDidFallbackToSimulation(_ controller: CameraViewController)
}

private final class CameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: CameraViewControllerDelegate?

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isPausedInternal = false
    private let sessionQueue = DispatchQueue(label: "com.glassqr.camera.queue")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        #if targetEnvironment(simulator)
        delegate?.cameraViewControllerDidFallbackToSimulation(self)
        return
        #else
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.captureSession.canAddInput(videoInput) else {
                DispatchQueue.main.async {
                    self.delegate?.cameraViewControllerDidFallbackToSimulation(self)
                }
                return
            }

            self.captureSession.beginConfiguration()
            self.captureSession.addInput(videoInput)

            let metadataOutput = AVCaptureMetadataOutput()
            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [.qr]
            }
            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                layer.videoGravity = .resizeAspectFill
                layer.frame = self.view.bounds
                self.view.layer.addSublayer(layer)
                self.previewLayer = layer
            }

            self.captureSession.startRunning()
        }
        #endif
    }

    func setTorch(on: Bool) {
        #if !targetEnvironment(simulator)
        sessionQueue.async {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  device.hasTorch else { return }
            try? device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        }
        #endif
    }

    func setPaused(_ paused: Bool) {
        isPausedInternal = paused
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if paused {
                if self.captureSession.isRunning {
                    self.captureSession.stopRunning()
                }
            } else {
                if !self.captureSession.isRunning {
                    self.captureSession.startRunning()
                }
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !isPausedInternal,
              let metadataObj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObj.type == .qr,
              let stringVal = metadataObj.stringValue else { return }

        delegate?.cameraViewController(self, didOutputCode: stringVal)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [weak self] in
            if self?.captureSession.isRunning == true {
                self?.captureSession.stopRunning()
            }
        }
    }
}

// MARK: - Animated Real-Time MeshGradient Background

struct LiquidMeshGradientView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let date = timeline.date.timeIntervalSinceReferenceDate
            let t = Float(date * 0.75)

            // Dynamic oscillation points creating fluid liquid surface
            let p1x = 0.5 + 0.16 * cos(t * 0.6)
            let p1y = 0.5 + 0.16 * sin(t * 0.8)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [p1x, p1y], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: [
                    Color(red: 0.07, green: 0.03, blue: 0.20), // Midnight Indigo
                    Color(red: 0.18, green: 0.05, blue: 0.38), // Electric Violet
                    Color(red: 0.03, green: 0.30, blue: 0.52), // Deep Cyan
                    Color(red: 0.12, green: 0.08, blue: 0.30), // Royal Indigo
                    Color(red: 0.55, green: 0.10, blue: 0.50), // Liquid Magenta
                    Color(red: 0.00, green: 0.58, blue: 0.80), // Electric Cyan
                    Color(red: 0.04, green: 0.01, blue: 0.15), // Deep Midnight
                    Color(red: 0.30, green: 0.06, blue: 0.42), // Indigo Violet
                    Color(red: 0.06, green: 0.40, blue: 0.60)  // Glowing Cyan
                ]
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Native iOS 26 Liquid Glass Architecture & Interface Protocols

public struct GlassEffectStyle: Sendable, Equatable {
    public enum Variant: Sendable, Equatable {
        case regular
        case clear
    }

    public var variant: Variant
    public var isInteractive: Bool

    public static var regular: GlassEffectStyle {
        GlassEffectStyle(variant: .regular, isInteractive: false)
    }

    public static var clear: GlassEffectStyle {
        GlassEffectStyle(variant: .clear, isInteractive: false)
    }

    public func interactive(_ active: Bool = true) -> GlassEffectStyle {
        var copy = self
        copy.isInteractive = active
        return copy
    }
}

public enum GlassEffectTransition: Sendable, Equatable {
    case materialize
    case matchedGeometry
}

public struct GlassShapeToken: Sendable {
    public enum ShapeKind {
        case capsule
        case rect(cornerRadius: CGFloat)
    }
    public var kind: ShapeKind

    public static var capsule: GlassShapeToken {
        GlassShapeToken(kind: .capsule)
    }

    public static func rect(cornerRadius: CGFloat) -> GlassShapeToken {
        GlassShapeToken(kind: .rect(cornerRadius: cornerRadius))
    }
}

public extension View {
    /// Native iOS 26 `.glassEffect()` modifier
    func glassEffect(
        _ style: GlassEffectStyle = .regular,
        in shape: GlassShapeToken = .capsule
    ) -> some View {
        modifier(NativeLiquidGlassModifier(style: style, shape: shape))
    }

    /// Native iOS 26 geometry matching for liquid droplet morphing
    func glassEffectID(_ id: AnyHashable, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }

    /// Native iOS 26 liquid appearance transition
    @ViewBuilder
    func glassEffectTransition(_ transition: GlassEffectTransition) -> some View {
        switch transition {
        case .materialize:
            self.transition(
                .asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .scale(scale: 0.88).combined(with: .opacity)
                )
            )
        case .matchedGeometry:
            self.transition(.identity)
        }
    }
}

/// Liquid Morphing Glass Effect Container
public struct GlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    public let content: Content

    public init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}

/// Native Liquid Glass Button Styles
public struct GlassButtonStyle: ButtonStyle {
    public let isProminent: Bool

    public init(isProminent: Bool = false) {
        self.isProminent = isProminent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .background {
                if isProminent {
                    Capsule()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.82 : 0.96))
                        .shadow(color: Color.white.opacity(0.35), radius: 14, x: 0, y: 0)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.14))
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle(isProminent: false) }
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

/// Clean native rendering engine for Liquid Glass surfaces
private struct NativeLiquidGlassModifier: ViewModifier {
    let style: GlassEffectStyle
    let shape: GlassShapeToken
    @State private var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                glassBackdrop
            }
            .clipShape(shapeView)
            .scaleEffect(style.isInteractive && isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPressed)
            .simultaneousGesture(
                style.isInteractive ?
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
                : nil
            )
    }

    @ViewBuilder
    private var glassBackdrop: some View {
        switch style.variant {
        case .regular:
            shapeView
                .fill(Color.white.opacity(0.12))
                .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 8)
                .shadow(color: Color.white.opacity(0.09), radius: 1, x: 0, y: -1)
        case .clear:
            shapeView
                .fill(Color.white.opacity(0.04))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
    }

    private var shapeView: AnyShape {
        switch shape.kind {
        case .capsule:
            return AnyShape(Capsule())
        case .rect(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}

// MARK: - Xcode 26 Previews

#Preview("Main App - Liquid Glass") {
    RootContentView(hasCompletedOnboarding: .constant(true))
        .preferredColorScheme(.dark)
}

#Preview("Welcome & Onboarding") {
    RootContentView(hasCompletedOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
