import SwiftUI

public struct TranslationSheetView: View {
    @Binding var isPresented: Bool
    public let originalText: String
    public var onApplyToGenerator: ((String) -> Void)?
    public var onApplyDualLanguageToGenerator: ((String) -> Void)?

    @StateObject private var engine = GlassTranslationEngine.shared
    @State private var selectedTarget: SupportedLanguage = SupportedLanguage.catalog.first(where: { $0.id == "km" }) ?? SupportedLanguage.catalog[1]
    @State private var sourceLanguage: SupportedLanguage = SupportedLanguage.catalog[0]
    @State private var translatedText: String = ""
    @State private var isTranslating: Bool = false
    @State private var copiedNotice: Bool = false

    public init(
        isPresented: Binding<Bool>,
        originalText: String,
        onApplyToGenerator: ((String) -> Void)? = nil,
        onApplyDualLanguageToGenerator: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.originalText = originalText
        self.onApplyToGenerator = onApplyToGenerator
        self.onApplyDualLanguageToGenerator = onApplyDualLanguageToGenerator
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        languagePickerBar
                        originalTextCard
                        translatedTextCard
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Live Translation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                let detected = engine.detectLanguage(of: originalText)
                sourceLanguage = detected
                // If detected is Khmer, default target to English; otherwise default target to Khmer
                if detected.id == "km" {
                    selectedTarget = SupportedLanguage.catalog.first(where: { $0.id == "en" }) ?? SupportedLanguage.catalog[0]
                }
                await performTranslation()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Language Selector Bar

    private var languagePickerBar: some View {
        VStack(spacing: 12) {
            HStack {
                // Detected Source Language Pill
                HStack(spacing: 6) {
                    Text(sourceLanguage.flag)
                    Text(sourceLanguage.name)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Text("(Detected)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .capsule)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                // Target Language Indicator
                HStack(spacing: 6) {
                    Text(selectedTarget.flag)
                    Text(selectedTarget.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            // Horizontal Target Language Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SupportedLanguage.catalog) { lang in
                        let isSelected = lang.id == selectedTarget.id
                        Button {
                            guard lang.id != sourceLanguage.id else { return }
                            selectedTarget = lang
                            Task {
                                await performTranslation()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(lang.flag)
                                Text(lang.name)
                                    .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.8))
                        }
                        .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
                        .overlay(
                            Capsule()
                                .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 1.5)
                        )
                        .opacity(lang.id == sourceLanguage.id ? 0.35 : 1.0)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Original Text Card

    private var originalTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Original Text", systemImage: "text.quote")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    engine.speak(text: originalText, language: sourceLanguage)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                }
            }

            Text(originalText)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Translated Text Card

    private var translatedTextCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Translation (\(selectedTarget.name))", systemImage: "globe")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cyan)

                Spacer()

                if isTranslating {
                    ProgressView()
                        .scaleEffect(0.8)
                }

                Button {
                    engine.speak(text: translatedText, language: selectedTarget)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                }

                Button {
                    UIPasteboard.general.string = translatedText
                    withAnimation { copiedNotice = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        copiedNotice = false
                    }
                } label: {
                    Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(copiedNotice ? Color.green : Color.primary)
                }
            }

            if translatedText.isEmpty {
                Text("Translating...")
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Text(translatedText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Apply Translated Text to Generator
            Button {
                let textToApply = translatedText.isEmpty ? originalText : translatedText
                onApplyToGenerator?(textToApply)
                isPresented = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 16, weight: .bold))
                    Text("Generate Translated QR Code")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.glassProminent)

            // Generate Dual-Language QR Code
            Button {
                let dual = "\(sourceLanguage.flag) \(originalText)\n\n\(selectedTarget.flag) \(translatedText)"
                onApplyDualLanguageToGenerator?(dual)
                isPresented = false
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "character.book.closed.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text("Create Dual-Language QR Code")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.glass)
        }
    }

    private func performTranslation() async {
        isTranslating = true
        let res = await engine.translate(text: originalText, from: sourceLanguage, to: selectedTarget)
        translatedText = res.translatedText
        isTranslating = false
    }
}
