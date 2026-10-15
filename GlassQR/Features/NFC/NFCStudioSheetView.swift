import SwiftUI

public enum NFCStudioTab: String, CaseIterable, Identifiable {
    case read = "Read Tag"
    case write = "Write Tag"

    public var id: String { rawValue }
    public var icon: String {
        switch self {
        case .read: return "wave.3.forward.circle.fill"
        case .write: return "pencil.and.outline"
        }
    }
}

public struct NFCStudioSheetView: View {
    @Binding var isPresented: Bool
    public var initialWritePayload: String = ""
    public var onApplyToGenerator: ((String) -> Void)?

    @StateObject private var nfcManager = NFCManager.shared
    @State private var selectedTab: NFCStudioTab = .read
    @State private var writePayloadText: String = ""
    @State private var isPulsing: Bool = false
    @State private var showCopiedNotice: Bool = false

    public init(
        isPresented: Binding<Bool>,
        initialWritePayload: String = "",
        onApplyToGenerator: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.initialWritePayload = initialWritePayload
        self.onApplyToGenerator = onApplyToGenerator
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        tabSelector
                        if selectedTab == .read {
                            readModeSection
                        } else {
                            writeModeSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("NFC Smart Studio")
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
            .onAppear {
                if !initialWritePayload.isEmpty {
                    writePayloadText = initialWritePayload
                    selectedTab = .write
                }
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Tab Selector

    private var tabSelector: some View {
        HStack(spacing: 8) {
            ForEach(NFCStudioTab.allCases) { tab in
                let isSelected = tab == selectedTab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .foregroundStyle(isSelected ? Color.white : Color.primary.opacity(0.75))
                }
                .glassEffect(isSelected ? .clear : .regular.interactive(), in: .capsule)
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 1.5)
                )
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Read Mode

    private var readModeSection: some View {
        VStack(spacing: 20) {
            // Radar Animation Card
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(Color.cyan.opacity(0.15), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(isPulsing ? 1.25 : 0.9)
                        .opacity(isPulsing ? 0.3 : 0.8)

                    Circle()
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 3)
                        .frame(width: 100, height: 100)
                        .scaleEffect(isPulsing ? 1.15 : 0.95)

                    Circle()
                        .fill(LinearGradient(colors: [Color.cyan.opacity(0.4), Color.blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 76, height: 76)
                        .glassEffect(.regular.interactive(), in: .circle)

                    Image(systemName: "wave.3.forward.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.cyan)
                }
                .padding(.top, 12)

                Text(nfcManager.statusMessage)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                // Start NFC Scan Button
                Button {
                    nfcManager.startReading()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 15, weight: .bold))
                        Text("Scan Physical NFC Tag")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(20)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))

            // Last Read Tag Result Card
            if let tag = nfcManager.lastReadTag {
                readResultCard(tag: tag)
            }

            // Simulator Testing Chips (if hardware unavailable or for quick testing)
            simulatorReadSection
        }
    }

    private func readResultCard(tag: NFCTagInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Tag Scanned (\(tag.recordType))")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                }

                Spacer()

                if tag.isSimulated {
                    Text("SIMULATED")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.2))
                        .foregroundStyle(Color.orange)
                        .clipShape(Capsule())
                }
            }

            Text(tag.payloadText)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.black.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                // Generate QR Code from Tag
                Button {
                    onApplyToGenerator?(tag.payloadText)
                    isPresented = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "qrcode")
                        Text("Create QR")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.glassProminent)

                // Copy Data Button
                Button {
                    UIPasteboard.general.string = tag.payloadText
                    withAnimation { showCopiedNotice = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        showCopiedNotice = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showCopiedNotice ? "checkmark" : "doc.on.doc")
                        Text(showCopiedNotice ? "Copied" : "Copy")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    private var simulatorReadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Simulated Tag Presets (Instant Test)", systemImage: "sparkles")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    nfcManager.simulateTagRead(
                        presetText: "WIFI:T:WPA;S:LiquidGlass_5G;P:GlassQR2026;;",
                        typeName: "Wi-Fi Config"
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "wifi")
                        Text("Wi-Fi Tag")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)

                Button {
                    nfcManager.simulateTagRead(
                        presetText: "https://github.com/Heng-zm/qr-app",
                        typeName: "Web URI"
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "link")
                        Text("URL Tag")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)

                Button {
                    nfcManager.simulateTagRead(
                        presetText: "BEGIN:VCARD\nVERSION:3.0\nN:Chen;Alex\nFN:Alex Chen\nTITLE:iOS Engineer\nEMAIL:alex@glassqr.app\nEND:VCARD",
                        typeName: "vCard"
                    )
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "person.crop.circle")
                        Text("vCard")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.glass)
            }
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }

    // MARK: - Write Mode

    private var writeModeSection: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Payload to Write", systemImage: "pencil.and.outline")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.cyan)
                    Spacer()
                    Text("\(writePayloadText.count) chars")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                TextField("Enter URL, Wi-Fi string, contact card or text...", text: $writePayloadText, axis: .vertical)
                    .lineLimit(4...8)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .padding(12)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 11))
                    Text("Compatible with NTAG213, NTAG215, NTAG216 and NFC Forum Type 2-5 tags.")
                        .font(.system(size: 11))
                }
                .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))

            // Write Status Notice
            if nfcManager.lastWriteSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.green)
                    Text("Tag Programmed Successfully!")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.interactive(), in: .capsule)
            }

            // Write Action Buttons
            Button {
                nfcManager.startWriting(payload: writePayloadText)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.right.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Write to Physical NFC Tag")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
            .disabled(writePayloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // Simulator Write Test
            Button {
                nfcManager.simulateTagWrite(payload: writePayloadText)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Simulate NFC Tag Write")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.glass)
            .disabled(writePayloadText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }
}
