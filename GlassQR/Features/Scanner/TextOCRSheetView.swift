//
//  TextOCRSheetView.swift
//  GlassQR
//
//  Live Camera Text OCR to QR Converter Sheet
//  Extracts real-world text from printed documents, signs, or router stickers,
//  identifies payload types, and turns them into styled QR codes in real time.
//

import SwiftUI
import PhotosUI

public struct TextOCRSheetView: View {
    @Binding var isPresented: Bool
    var onApplyToGenerator: ((String) -> Void)?

    @State private var isCameraScanning: Bool = true
    @State private var recognizedText: String = ""
    @State private var toastMessage: String?
    @State private var copyHapticTrigger: Int = 0
    @State private var showAIInspector: Bool = false
    @State private var showTranslationSheet: Bool = false
    @State private var showNFCStudioSheet: Bool = false

    private let renderer = CrispQRRenderer()

    public init(
        isPresented: Binding<Bool>,
        initialText: String = "",
        onApplyToGenerator: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._recognizedText = State(initialValue: initialText)
        self.onApplyToGenerator = onApplyToGenerator
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    if recognizedText.isEmpty {
                        liveScannerContainer
                    } else {
                        recognizedResultScrollView
                    }
                }
            }
            .navigationTitle(recognizedText.isEmpty ? "Live Text OCR" : "Text to QR Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(recognizedText.isEmpty ? "Cancel" : "Rescan") {
                        if recognizedText.isEmpty {
                            isPresented = false
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                recognizedText = ""
                                isCameraScanning = true
                            }
                        }
                    }
                    .foregroundStyle(.white)
                }

                if !recognizedText.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                        .foregroundStyle(.white)
                    }
                }
            }
            .overlay(alignment: .top) {
                toastBanner
            }
            .sheet(isPresented: $showAIInspector) {
                NavigationStack {
                    AIAssistantView(
                        hasCompletedOnboarding: .constant(true),
                        initialScanItem: ScanResultItem(payload: recognizedText),
                        isEmbeddedInTab: false
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") {
                                showAIInspector = false
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showTranslationSheet) {
                TranslationSheetView(
                    isPresented: $showTranslationSheet,
                    originalText: recognizedText,
                    onApplyToGenerator: { translated in
                        recognizedText = translated
                        triggerToast("Applied Translated Text")
                    },
                    onApplyDualLanguageToGenerator: { dual in
                        recognizedText = dual
                        triggerToast("Applied Dual-Language Text")
                    }
                )
            }
            .sheet(isPresented: $showNFCStudioSheet) {
                NFCStudioSheetView(
                    isPresented: $showNFCStudioSheet,
                    initialWritePayload: recognizedText
                )
            }
        }
    }

    // MARK: - Live Scanner Container

    private var liveScannerContainer: some View {
        ZStack(alignment: .bottom) {
            LiveTextScannerRepresentable(
                isScanning: $isCameraScanning,
                onTextRecognized: { text in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        recognizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                },
                onDismiss: {
                    isPresented = false
                }
            )
            .ignoresSafeArea()

            // Targeting Instructions
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.cyan)

                    Text("Tap any highlighted text to convert into QR")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }
            .padding(.bottom, 36)
        }
    }

    // MARK: - Recognized Result Scroll View

    private var recognizedResultScrollView: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header Category Badge
                categoryHeaderBadge
                    .padding(.top, 14)

                // Editable Text Card
                editableTextCard
                    .padding(.horizontal, 18)

                // Generated QR Code Preview Card
                generatedQRPreviewCard
                    .padding(.horizontal, 18)

                // Action Buttons
                actionsSection
                    .padding(.horizontal, 18)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Category Header Badge

    private var categoryHeaderBadge: some View {
        let (icon, label, color) = detectedTypeInfo
        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)

            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Editable Text Card

    private var editableTextCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("RECOGNIZED TEXT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))

                Spacer()

                Button {
                    UIPasteboard.general.string = recognizedText
                    triggerToast("Text Copied")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                }
            }

            TextEditor(text: $recognizedText)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 80, maxHeight: 140)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.04)))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    // MARK: - Generated QR Preview Card

    private var generatedQRPreviewCard: some View {
        let qrImage = renderer.render(
            text: recognizedText,
            foregroundColor: .black,
            backgroundColor: .white,
            correctionLevel: .high
        )

        return VStack(spacing: 12) {
            HStack {
                Text("LIVE VECTOR QR PREVIEW")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Text("Error Correction H (30%)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
            }

            if let img = qrImage {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 170, height: 170)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                    .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 170, height: 170)
                    .overlay(Text("Generating...").font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)))
            }

            HStack(spacing: 8) {
                if let img = qrImage {
                    Button {
                        UIPasteboard.general.image = img
                        triggerToast("QR Image Copied")
                    } label: {
                        Label("Copy Image", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)

                    Button {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        triggerToast("Saved to Photos")
                    } label: {
                        Label("Save Photo", systemImage: "arrow.down.to.line")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
        )
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Apply to Generator
            if let onApply = onApplyToGenerator {
                Button {
                    onApply(recognizedText)
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 15, weight: .bold))
                        Text("Customize in Generator Tab")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
            }

            // Dual Feature Buttons: Translation & NFC Tag Write
            HStack(spacing: 10) {
                Button {
                    showTranslationSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.cyan)
                        Text("Translate")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glass)

                Button {
                    showNFCStudioSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wave.3.forward.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color.green)
                        Text("Write NFC")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glass)
            }

            // Ask AI Copilot to analyze
            Button {
                showAIInspector = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Audit Content with AI Assistant")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Detectors & Helpers

    private var detectedTypeInfo: (icon: String, label: String, color: Color) {
        let lower = recognizedText.lowercased()
        if lower.contains("wifi:") || (lower.contains("ssid") && lower.contains("pass")) {
            return ("wifi", "Wi-Fi Configuration Detected", .green)
        } else if lower.hasPrefix("http://") || lower.hasPrefix("https://") || lower.contains(".com") || lower.contains(".org") {
            return ("link", "Web Destination Link", .cyan)
        } else if lower.contains("begin:vcard") || (lower.contains("fn:") && lower.contains("tel:")) {
            return ("person.crop.circle", "vCard Contact Card", .purple)
        } else {
            return ("doc.text.fill", "Plain Text Payload", .white)
        }
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        copyHapticTrigger += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }

    private var toastBanner: some View {
        Group {
            if let msg = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.black.opacity(0.85)))
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(.top, 60)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
