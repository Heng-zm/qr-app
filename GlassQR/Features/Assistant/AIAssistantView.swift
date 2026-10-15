//
//  AIAssistantView.swift
//  GlassQR
//
//  Liquid Glass AI Agent Assistant View
//  Natural language QR generation, multi-modal photo OCR inspection,
//  threat analysis, persona modes, speech synthesis, and 1-tap smart actions.
//

import SwiftUI
import PhotosUI
import AVFoundation

public struct AIAssistantView: View {
    @Binding var hasCompletedOnboarding: Bool
    var initialScanItem: ScanResultItem?

    @StateObject private var engine = GlassAIEngine.shared
    @State private var messages: [AIAgentMessage] = []
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var showSettings: Bool = false
    @State private var toastMessage: String?
    @State private var hapticFeedbackTrigger: Int = 0

    // Multi-Modal Photo Attachment State
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var attachedImage: UIImage? = nil

    // Smart Actions Sheet State
    @State private var showNFCStudioSheet: Bool = false
    @State private var nfcWritePayload: String = ""
    @State private var showSecretVaultUnlockSheet: Bool = false
    @State private var vaultUnlockPayload: String = ""

    var isEmbeddedInTab: Bool
    @FocusState private var isInputFocused: Bool
    @Environment(\.openURL) private var openURL

    // QR Renderer instance for inline suggestions
    private let renderer = CrispQRRenderer()

    public init(
        hasCompletedOnboarding: Binding<Bool>,
        initialScanItem: ScanResultItem? = nil,
        isEmbeddedInTab: Bool = true
    ) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
        self.initialScanItem = initialScanItem
        self.isEmbeddedInTab = isEmbeddedInTab
    }

    public var body: some View {
        ZStack {
            // Ambient Liquid Mesh Background
            LiquidMeshGradientView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Persona Mode Selector Bar
                personaModeBar

                // Chat Messages Scroll
                chatScrollView

                // Bottom Floating Input Bar with Multi-Modal Vision Attachment
                inputPlatter
            }
        }
        .navigationTitle("Glass AI Copilot")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                engineStatusBadge
            }

            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    if !messages.isEmpty {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                messages.removeAll()
                                engine.stopSpeaking()
                            }
                            triggerToast("Conversation Cleared")
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button {
                    isInputFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            AISettingsSheet()
        }
        .sheet(isPresented: $showNFCStudioSheet) {
            NFCStudioSheetView(
                isPresented: $showNFCStudioSheet,
                initialMode: .write,
                initialWritePayload: nfcWritePayload
            )
        }
        .sheet(isPresented: $showSecretVaultUnlockSheet) {
            SecretVaultUnlockSheetView(
                isPresented: $showSecretVaultUnlockSheet,
                encryptedPayload: vaultUnlockPayload
            )
        }
        .overlay(alignment: .top) {
            toastBanner
        }
        .onAppear {
            setupInitialState()
        }
        .onDisappear {
            engine.stopSpeaking()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        attachedImage = uiImage
                    }
                }
            }
        }
    }

    // MARK: - Persona Mode Selector Bar

    private var personaModeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AIPersona.allCases) { persona in
                    let isSelected = engine.persona == persona
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            engine.persona = persona
                        }
                        triggerToast("\(persona.rawValue) Active")
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: persona.icon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(isSelected ? .black : persona.tint)
                            Text(persona.rawValue)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(
                            Capsule().fill(isSelected ? persona.tint : Color.white.opacity(0.07))
                        )
                        .overlay(
                            Capsule().stroke(isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.15))
    }

    // MARK: - Engine Status Badge

    private var engineStatusBadge: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(engine.provider == .onDevice ? Color.green : Color.cyan)
                    .frame(width: 6, height: 6)

                Text(engine.provider.rawValue)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.white.opacity(0.08)))
        }
    }

    // MARK: - Chat Messages Scroll

    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if messages.isEmpty {
                        emptyWelcomeHero
                    } else {
                        ForEach(messages) { msg in
                            messageBubble(for: msg)
                                .id(msg.id)
                        }
                    }

                    if isThinking {
                        thinkingIndicatorBubble
                            .id("thinking_indicator")
                    }

                    // Spacer for bottom input and nav clearance
                    Spacer()
                        .frame(height: isEmbeddedInTab ? 140 : 80)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(
                TapGesture().onEnded {
                    if isInputFocused {
                        isInputFocused = false
                    }
                }
            )
            .onChange(of: messages.count) { _, _ in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if let last = messages.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: isThinking) { _, thinking in
                if thinking {
                    withAnimation {
                        proxy.scrollTo("thinking_indicator", anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Empty Welcome Hero

    private var emptyWelcomeHero: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 10)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [engine.persona.tint.opacity(0.35), Color.purple.opacity(0.05), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 130, height: 130)

                Image(systemName: engine.persona.icon)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [engine.persona.tint, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 6) {
                Text(engine.persona.rawValue)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(engine.persona.subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Quick Starter Chips
            VStack(spacing: 9) {
                starterChip(title: "📍 Drop Pin at Tokyo Tower", prompt: "Drop pin on Apple Map for Tokyo Tower, Japan")
                starterChip(title: "🔐 Encrypt Vault with Passcode", prompt: "Create an encrypted secret vault QR for seed phrase 'apple banana cherry' with passcode 8888")
                starterChip(title: "⚡ Generate Wi-Fi for 'GuestNet'", prompt: "Generate a Wi-Fi QR code for network 'GuestNet' with password 'Welcome2026!'")
                starterChip(title: "📇 Create vCard for Alex Chen", prompt: "Create a vCard QR for Alex Chen, VP Engineering, email alex@example.com")
            }
            .padding(.top, 4)
        }
    }

    private func starterChip(title: String, prompt: String) -> some View {
        Button {
            inputText = prompt
            sendMessage()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Message Bubble

    @ViewBuilder
    private func messageBubble(for msg: AIAgentMessage) -> some View {
        if msg.isUser {
            userMessageBubble(msg)
        } else {
            aiMessageBubble(msg)
        }
    }

    private func userMessageBubble(_ msg: AIAgentMessage) -> some View {
        HStack {
            Spacer(minLength: 44)

            VStack(alignment: .trailing, spacing: 8) {
                // Attached image thumbnail
                if let imgData = msg.attachedImageData, let uiImg = UIImage(data: imgData) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.3), lineWidth: 1))
                }

                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.45)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
            }
        }
    }

    private func aiMessageBubble(_ msg: AIAgentMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: engine.persona.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(engine.persona.tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(engine.persona.tint.opacity(0.15)))
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(engine.persona.rawValue)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(engine.persona.tint)
                    Spacer()

                    // Voice Read-Aloud Button
                    Button {
                        if engine.isSpeaking {
                            engine.stopSpeaking()
                        } else {
                            engine.speakText(msg.text)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: engine.isSpeaking ? "waveform" : "speaker.wave.2")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(engine.isSpeaking ? Color.cyan : Color.white.opacity(0.6))
                            if engine.isSpeaking {
                                Text("Speaking")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.cyan)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                    }
                }

                // Main Text Payload
                Text(parseMarkdownText(msg.text))
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineSpacing(4)

                // Optional Security Shield Badge
                if let badge = msg.securityBadge {
                    securityBadgeCard(badge)
                }

                // Optional Suggested QR Code Widget
                if let qr = msg.suggestedQR {
                    suggestedQRWidget(qr)
                }

                // Quick Follow-up Prompts
                if let prompts = msg.quickPrompts, !prompts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(prompts, id: \.self) { prompt in
                                Button {
                                    inputText = prompt
                                    sendMessage()
                                } label: {
                                    Text(prompt)
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.cyan.opacity(0.9))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color.cyan.opacity(0.12)))
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.09), lineWidth: 1)
                    )
            )

            Spacer(minLength: 20)
        }
    }

    // MARK: - Security Badge Card

    private func securityBadgeCard(_ badge: AISecurityBadge) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: badge.level.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(badge.level.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(badge.level.color)

                Text(badge.details)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(badge.level.color.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(badge.level.color.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Suggested QR Widget & Smart Actions

    private func suggestedQRWidget(_ qr: AISuggestedQR) -> some View {
        let qrImage = renderer.render(
            text: qr.payload,
            foregroundColor: .black,
            backgroundColor: .white,
            correctionLevel: .high
        )

        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: qr.iconName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.cyan)
                Text(qr.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(qr.formatLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }

            if let img = qrImage {
                Image(uiImage: img)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .shadow(color: Color.black.opacity(0.2), radius: 6)
            }

            // Smart Action Triggers (NFC, Maps, Vault)
            if let action = qr.action {
                smartActionButton(action: action)
            }

            HStack(spacing: 8) {
                Button {
                    UIPasteboard.general.string = qr.payload
                    triggerToast("Payload Copied")
                } label: {
                    Label("Copy Data", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)

                if let img = qrImage {
                    Button {
                        UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                        triggerToast("Saved to Photos")
                    } label: {
                        Label("Save Photo", systemImage: "arrow.down.to.line")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func smartActionButton(action: AIQuickAction) -> some View {
        Button {
            executeSmartAction(action)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: action.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(action.label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34)
        }
        .buttonStyle(.glassProminent)
    }

    private func executeSmartAction(_ action: AIQuickAction) {
        switch action {
        case .writeNFC(let payload):
            nfcWritePayload = payload
            showNFCStudioSheet = true
        case .openAppleMaps(let lat, let lon, let label):
            let encoded = label.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let mapURL = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)&q=\(encoded)") {
                openURL(mapURL)
            }
        case .unlockVault(let ciphertext):
            vaultUnlockPayload = ciphertext
            showSecretVaultUnlockSheet = true
        case .saveContact(let vcard):
            UIPasteboard.general.string = vcard
            triggerToast("vCard Copied to Clipboard")
        case .sharePayload(let text):
            UIPasteboard.general.string = text
            triggerToast("Copied for Sharing")
        }
    }

    // MARK: - Thinking Bubble

    private var thinkingIndicatorBubble: some View {
        HStack(spacing: 10) {
            Image(systemName: engine.persona.icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(engine.persona.tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(engine.persona.tint.opacity(0.15)))

            HStack(spacing: 5) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(engine.persona.tint)
                        .frame(width: 7, height: 7)
                        .scaleEffect(isThinking ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(idx) * 0.2),
                            value: isThinking
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )

            Spacer()
        }
    }

    // MARK: - Bottom Floating Input Platter

    private var inputPlatter: some View {
        VStack(spacing: 6) {
            // Attached Image Preview Tag
            if let img = attachedImage {
                HStack(spacing: 8) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    Text("Photo attached for OCR & Vision")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    Button {
                        attachedImage = nil
                        selectedPhotoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.09)))
                .padding(.horizontal, 8)
            }

            HStack(spacing: 8) {
                // Multi-Modal Vision PhotosPicker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(attachedImage != nil ? Color.cyan : Color.white.opacity(0.75))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }

                TextField("Ask AI to generate, analyze, or inspect...", text: $inputText, axis: .vertical)
                    .focused($isInputFocused)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle().fill(
                                (inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil)
                                    ? Color.white.opacity(0.3)
                                    : Color.white
                            )
                        )
                }
                .disabled((inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachedImage == nil) || isThinking)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 14, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, isEmbeddedInTab ? (isInputFocused ? 8 : 76) : 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isInputFocused)
    }

    // MARK: - Actions & Helpers

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageToAnalyze = attachedImage

        guard !text.isEmpty || imageToAnalyze != nil else { return }

        inputText = ""
        attachedImage = nil
        selectedPhotoItem = nil

        let userMsg = AIAgentMessage(
            isUser: true,
            text: text,
            attachedImageData: imageToAnalyze?.jpegData(compressionQuality: 0.8)
        )
        messages.append(userMsg)
        isThinking = true

        Task {
            let reply: AIAgentMessage
            if let img = imageToAnalyze {
                reply = await engine.analyzeImage(img, prompt: text.isEmpty ? nil : text)
            } else {
                reply = await engine.processPrompt(text)
            }

            await MainActor.run {
                isThinking = false
                messages.append(reply)
            }
        }
    }

    private func setupInitialState() {
        if let item = initialScanItem, messages.isEmpty {
            let userPrompt = AIAgentMessage(isUser: true, text: "Analyze scanned content: \(item.payload)")
            messages.append(userPrompt)
            let analysis = engine.analyzeScannedItem(item)
            messages.append(analysis)
        }
    }

    private func triggerToast(_ msg: String) {
        toastMessage = msg
        hapticFeedbackTrigger += 1
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

    private func parseMarkdownText(_ raw: String) -> AttributedString {
        (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
    }
}

// MARK: - AI Settings Sheet

private struct AISettingsSheet: View {
    @ObservedObject private var engine = GlassAIEngine.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Overview Card
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "cpu.fill")
                                    .foregroundStyle(Color.cyan)
                                Text("Dual Engine Architecture")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }

                            Text("By default, GlassQR operates a 100% on-device neural engine. No internet or API keys are required for natural language QR creation, Wi-Fi decoding, or safety analysis.\n\nOptionally switch to cloud providers (OpenAI, Gemini, Claude) for extended multi-modal vision and reasoning.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                                .lineSpacing(3)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
                        )

                        // Provider Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Engine Provider")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            Picker("Provider", selection: $engine.providerRaw) {
                                ForEach(AIProvider.allCases) { prov in
                                    Label(prov.rawValue, systemImage: prov.icon).tag(prov.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
                        )

                        // Cloud API Configuration Platter
                        if engine.provider != .onDevice {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(engine.provider.rawValue) Credentials")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))

                                SecureField("API Key (e.g. sk-..., AIzaSy..., claude-...)", text: $engine.apiKey)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 13, design: .monospaced))
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))

                                TextField("Model Override (Default: \(engine.provider.defaultModel))", text: $engine.customModel)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .font(.system(size: 12, design: .monospaced))
                                    .padding(12)
                                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))

                                if engine.provider == .custom || engine.provider == .openAI {
                                    TextField("Custom Endpoint (e.g. http://localhost:11434/v1/chat/completions)", text: $engine.customEndpoint)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .font(.system(size: 12, design: .monospaced))
                                        .padding(12)
                                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
                            )
                        }

                        // Voice Synthesizer Test Card
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Speech Synthesizer")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            Button {
                                engine.speakText("Hello! GlassQR Intelligent Copilot is fully configured and ready.")
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "speaker.wave.2.fill")
                                    Text("Test Siri-Grade Audio Pronunciation")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                            }
                            .buttonStyle(.glass)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.06))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.09), lineWidth: 1))
                        )

                        Spacer()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("AI Agent Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
