//
//  WalletPassSheetView.swift
//  GlassQR
//
//  Interactive Apple Wallet Pass Studio with Live Pass Card Preview,
//  Color Palette Customization, PassKit .pkpass Packaging, and Photo Export.
//

import SwiftUI
import PassKit

public struct WalletPassSheetView: View {
    @Binding var isPresented: Bool
    public var initialPayload: String

    @State private var passData: WalletPassData
    @State private var renderedCardImage: UIImage? = nil
    @State private var toastMessage: String? = nil
    @State private var hapticTrigger: Int = 0
    @State private var showExportSheet: Bool = false
    @State private var exportPackageURL: URL? = nil

    private let passEngine = GlassPassEngine.shared

    public init(isPresented: Binding<Bool>, initialPayload: String = "https://glassqr.app/pass") {
        self._isPresented = isPresented
        self.initialPayload = initialPayload
        self._passData = State(initialValue: WalletPassData(barcodePayload: initialPayload))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Ambient Liquid Mesh Background
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Pass Type Platter
                        passTypeSelector
                            .padding(.top, 14)
                            .padding(.horizontal, 20)

                        // Live Apple Wallet Pass Card Preview
                        passCardPreview
                            .padding(.horizontal, 24)

                        // Palette Selector
                        paletteSelector
                            .padding(.horizontal, 20)

                        // Information Form Fields Section
                        passFieldsEditor
                            .padding(.horizontal, 20)

                        // Action Buttons Bar
                        actionButtons
                            .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
                .scrollDismissesKeyboard(.interactively)

                // Toast Notification Overlay
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        toastPill(message: toast)
                            .padding(.bottom, 28)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Apple Wallet Studio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                    .foregroundStyle(.white.opacity(0.8))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exportPassPackage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                    }
                }
            }
            .onAppear {
                if !initialPayload.isEmpty {
                    passData.barcodePayload = initialPayload
                }
                updatePreviewImage()
            }
        }
    }

    // MARK: - Pass Type Selector Platter

    private var passTypeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WalletPassType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            passData.type = type
                            applyTypeDefaults(type)
                            updatePreviewImage()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: type.icon)
                                .font(.system(size: 12))
                            Text(type.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(passData.type == type ? Color.black : Color.white.opacity(0.8))
                        .background(
                            Capsule()
                                .fill(passData.type == type ? Color.white : Color.white.opacity(0.08))
                        )
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Live Pass Card Preview

    private var passCardPreview: some View {
        VStack(spacing: 8) {
            ZStack {
                if let img = renderedCardImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 24, x: 0, y: 12)
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 380)
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                }
            }

            Text("Live Wallet Pass Card Rendering")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    // MARK: - Palette Selector

    private var paletteSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CARD THEME")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            HStack(spacing: 12) {
                ForEach(WalletPassPalette.allCases) { pal in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            passData.palette = pal
                            updatePreviewImage()
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: pal.bgColor))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color(uiColor: pal.accentColor), lineWidth: 2)
                                )

                            if passData.palette == pal {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .background(glassPillBackground)
    }

    // MARK: - Pass Fields Editor

    private var passFieldsEditor: some View {
        VStack(spacing: 14) {
            // Organization & Title
            HStack(spacing: 10) {
                formField(label: "Organization", text: $passData.organizationName)
                formField(label: "Pass Title", text: $passData.passTitle)
            }

            // Primary Field
            HStack(spacing: 10) {
                formField(label: "Primary Label", text: $passData.primaryLabel)
                formField(label: "Primary Value", text: $passData.primaryValue)
            }

            // Secondary & Auxiliary
            HStack(spacing: 10) {
                formField(label: "Secondary Field", text: $passData.secondaryValue)
                formField(label: "Auxiliary Field", text: $passData.auxiliaryValue)
            }

            // Barcode Alt Text
            formField(label: "Barcode Code / Alt Text", text: $passData.barcodeAltText)
        }
        .padding(16)
        .background(glassPillBackground)
        .onChange(of: passData.organizationName) { _, _ in updatePreviewImage() }
        .onChange(of: passData.passTitle) { _, _ in updatePreviewImage() }
        .onChange(of: passData.primaryLabel) { _, _ in updatePreviewImage() }
        .onChange(of: passData.primaryValue) { _, _ in updatePreviewImage() }
        .onChange(of: passData.secondaryValue) { _, _ in updatePreviewImage() }
        .onChange(of: passData.auxiliaryValue) { _, _ in updatePreviewImage() }
        .onChange(of: passData.barcodeAltText) { _, _ in updatePreviewImage() }
    }

    private func formField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))

            TextField(label, text: text)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.09), lineWidth: 1)
                        )
                )
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Save Pass Card to Photos
            Button {
                saveCardToPhotos()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.badge.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save Pass Card to Photos")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.glassProminent)

            HStack(spacing: 10) {
                // Export .pkpass
                Button {
                    exportPassPackage()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "archivebox.fill")
                        Text("Share .pkpass")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glass)

                // Copy Barcode Payload
                Button {
                    UIPasteboard.general.string = passData.barcodePayload
                    triggerToast("Payload Copied")
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy Payload")
                    }
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glass)
            }
        }
    }

    // MARK: - Helpers & Operations

    private var glassPillBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func applyTypeDefaults(_ type: WalletPassType) {
        switch type {
        case .eventTicket:
            passData.organizationName = "Worldwide Tech Summit"
            passData.passTitle = "VIP All-Access Pass"
            passData.primaryLabel = "ATTENDEE"
            passData.primaryValue = "Alex Rivera"
            passData.secondaryLabel = "GATE"
            passData.secondaryValue = "North A • Row 4"
            passData.auxiliaryLabel = "DATE"
            passData.auxiliaryValue = "Oct 24, 2026"
            passData.barcodeAltText = "SUMMIT-2026-VIP"

        case .storeCard:
            passData.organizationName = "Obsidian Cafe & Roastery"
            passData.passTitle = "Gold Rewards Card"
            passData.primaryLabel = "MEMBER"
            passData.primaryValue = "Alex Rivera"
            passData.secondaryLabel = "POINTS"
            passData.secondaryValue = "1,420 PTS"
            passData.auxiliaryLabel = "TIER"
            passData.auxiliaryValue = "Level 3 Gold"
            passData.barcodeAltText = "CARD-9820-1120"

        case .coupon:
            passData.organizationName = "App Store Experience"
            passData.passTitle = "Special Invitation Discount"
            passData.primaryLabel = "OFFER"
            passData.primaryValue = "30% OFF ALL PASSES"
            passData.secondaryLabel = "CODE"
            passData.secondaryValue = "LIQUID2026"
            passData.auxiliaryLabel = "VALID UNTIL"
            passData.auxiliaryValue = "Dec 31, 2026"
            passData.barcodeAltText = "COUPON-GLASS-30"

        case .generic:
            passData.organizationName = "GlassQR Pass Studio"
            passData.passTitle = "Digital Membership Pass"
            passData.primaryLabel = "MEMBER"
            passData.primaryValue = "Alex Rivera"
            passData.secondaryLabel = "SECURITY"
            passData.secondaryValue = "Verified Pass"
            passData.auxiliaryLabel = "EXPIRES"
            passData.auxiliaryValue = "Dec 2026"
            passData.barcodeAltText = "GQR-829104"
        }
    }

    private func updatePreviewImage() {
        renderedCardImage = passEngine.renderPassCardImage(for: passData)
    }

    private func saveCardToPhotos() {
        guard let img = renderedCardImage else { return }
        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
        triggerToast("Saved Pass Card to Photos")
    }

    private func exportPassPackage() {
        guard let url = passEngine.exportPKPassPackage(for: passData) else {
            triggerToast("Failed to package pass")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let rootVC = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
    }

    private func toastPill(message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color(red: 0.14, green: 0.14, blue: 0.16))
                .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        )
    }

    private func triggerToast(_ msg: String) {
        hapticTrigger += 1
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            toastMessage = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if toastMessage == msg {
                    toastMessage = nil
                }
            }
        }
    }
}
