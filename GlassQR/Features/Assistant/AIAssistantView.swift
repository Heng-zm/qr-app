//
//  AIAssistantView.swift
//  GlassQR
//
//  Liquid Glass AI Agent Assistant View
//  Natural language QR generation, link threat inspection, barcode decoding, and smart advice.
//

import SwiftUI
import PhotosUI

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

    var isEmbeddedInTab: Bool
    @FocusState private var isInputFocused: Bool

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
                // Chat Messages Scroll
                chatScrollView

                // Bottom Floating Input Bar
                inputPlatter
            }
        }
        .navigationTitle("Glass AI Agent")
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
        .overlay(alignment: .top) {
            toastBanner
        }
        .onAppear {
            setupInitialState()
        }
    }

    // MARK: - Engine Status Badge

    private var engineStatusBadge: some View {
        Button {
            showSettings = true
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)

                Text(engine.apiKey.isEmpty ? "On-Device" : "Cloud LLM")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 9)
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
                        .frame(height: isEmbeddedInTab ? 130 : 70)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
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
        VStack(spacing: 20) {
            Spacer().frame(height: 20)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.cyan.opacity(0.35), Color.purple.opacity(0.05), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 70
                        )
                    )
                    .frame(width: 140, height: 140)

                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .purple, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("How can I assist you?")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Generate styled QR codes from natural prompts, verify link safety, or explain barcode standards.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Quick Starter Chips
            VStack(spacing: 10) {
                starterChip(title: "⚡ Generate Wi-Fi QR for 'GuestNet'", prompt: "Generate a Wi-Fi QR code for network 'GuestNet' with password 'Welcome2026!'")
                starterChip(title: "🛡️ Check if a link is safe to open", prompt: "How can I tell if a scanned URL is a phishing link?")
                starterChip(title: "📇 Create vCard for Alex Chen", prompt: "Create a vCard QR for Alex Chen, VP Engineering, email alex@example.com")
                starterChip(title: "📊 What is Reed-Solomon error correction?", prompt: "Explain QR error correction levels L, M, Q, H and when to use them.")
            }
            .padding(.top, 8)
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
            .padding(.vertical, 12)
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
            Spacer(minLength: 48)

            Text(msg.text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
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

    private func aiMessageBubble(_ msg: AIAgentMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.cyan)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.cyan.opacity(0.15)))
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 10) {
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

            Spacer(minLength: 24)
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

    // MARK: - Suggested QR Widget

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

    // MARK: - Thinking Bubble

    private var thinkingIndicatorBubble: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.cyan)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.cyan.opacity(0.15)))

            HStack(spacing: 5) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(Color.cyan)
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
        HStack(spacing: 8) {
            TextField("Ask AI to generate or analyze...", text: $inputText, axis: .vertical)
                .focused($isInputFocused)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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
                            inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.white.opacity(0.3)
                                : Color.white
                        )
                    )
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.92))
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
        guard !text.isEmpty else { return }

        inputText = ""
        let userMsg = AIAgentMessage(isUser: true, text: text)
        messages.append(userMsg)
        isThinking = true

        Task {
            let reply = await engine.processPrompt(text)
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

                            Text("By default, GlassQR operates a 100% on-device intelligent engine. No internet or API keys are required for natural language QR creation, Wi-Fi decoding, or safety analysis.\n\nOptionally connect an OpenAI or Gemini compatible API key below for extended reasoning.")
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

                        // Cloud API Configuration Platter
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cloud LLM Integration (Optional)")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))

                            SecureField("API Key (e.g. sk-...)", text: $engine.apiKey)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 13, design: .monospaced))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))

                            TextField("Custom Endpoint (Leave blank for OpenAI default)", text: $engine.customEndpoint)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .font(.system(size: 12, design: .monospaced))
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.07)))
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
            .navigationTitle("AI Agent Engine")
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
