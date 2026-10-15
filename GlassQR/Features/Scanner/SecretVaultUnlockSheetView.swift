import SwiftUI

public struct SecretVaultUnlockSheetView: View {
    @Binding var isPresented: Bool
    public let encryptedPayload: String
    public var onDecryptedText: ((String) -> Void)?

    @State private var passcode: String = ""
    @State private var decryptedSecret: String? = nil
    @State private var errorMessage: String? = nil
    @State private var isAuthenticating: Bool = false
    @State private var isUnlocked: Bool = false
    @State private var copiedNotice: Bool = false
    @State private var countdownRemaining: Int = 30
    @State private var countdownTimer: Timer? = nil

    public init(
        isPresented: Binding<Bool>,
        encryptedPayload: String,
        onDecryptedText: ((String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.encryptedPayload = encryptedPayload
        self.onDecryptedText = onDecryptedText
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                LiquidMeshGradientView()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        lockStatusHero
                        if isUnlocked, let secret = decryptedSecret {
                            unlockedSecretCard(secret: secret)
                        } else {
                            unlockFormSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                }
            }
            .navigationTitle("Encrypted Vault")
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
            .onDisappear {
                countdownTimer?.invalidate()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero Visualizer

    private var lockStatusHero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.green.opacity(0.18) : Color.purple.opacity(0.18))
                    .frame(width: 96, height: 96)
                    .glassEffect(.regular.interactive(), in: .circle)

                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(
                        LinearGradient(
                            colors: isUnlocked ? [.green, .cyan] : [.purple, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text(isUnlocked ? "Vault Unlocked" : "Zero-Knowledge Protected")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(isUnlocked ? "Confidential payload decrypted in memory." : "AES-GCM 256-bit encryption. Requires passphrase.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Unlock Form

    private var unlockFormSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Label("Enter Vault Passcode", systemImage: "key.fill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.cyan)

                SecureField("Passcode or PIN...", text: $passcode)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .padding(14)
                    .background(Color.black.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                if let err = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(err)
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.red)
                }
            }
            .padding(16)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))

            // Unlock Button
            Button {
                attemptUnlock()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Unlock Secret Vault")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.glassProminent)
            .disabled(passcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            // Biometric Option
            Button {
                Task {
                    await attemptBiometricUnlock()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "faceid")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                    Text("Authenticate with Face ID")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - Unlocked Secret Card

    private func unlockedSecretCard(secret: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Color.green)
                    Text("Decrypted Secret Content")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text("\(countdownRemaining)s")
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Text(secret)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.black.opacity(0.25))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                // Copy Secret Button
                Button {
                    UIPasteboard.general.string = secret
                    withAnimation { copiedNotice = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        copiedNotice = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                        Text(copiedNotice ? "Copied" : "Copy Secret")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glassProminent)

                // Lock & Clear Button
                Button {
                    lockAndWipe()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                        Text("Lock Now")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                }
                .buttonStyle(.glass)
            }
        }
        .padding(18)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }

    private func attemptUnlock() {
        errorMessage = nil
        do {
            let secret = try SteganographicQREngine.decrypt(
                encryptedPayload: encryptedPayload,
                passcode: passcode
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                decryptedSecret = secret
                isUnlocked = true
            }
            onDecryptedText?(secret)
            startCountdown()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            errorMessage = "Invalid passcode. Could not decrypt."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func attemptBiometricUnlock() async {
        let success = await SteganographicQREngine.authenticateDeviceOwner()
        if success {
            // If user previously set passcode or attempts default
            if !passcode.isEmpty {
                attemptUnlock()
            } else {
                errorMessage = "Please enter the vault passcode to complete decryption."
            }
        } else {
            errorMessage = "Biometric authentication failed."
        }
    }

    private func startCountdown() {
        countdownRemaining = 30
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownRemaining > 1 {
                countdownRemaining -= 1
            } else {
                lockAndWipe()
            }
        }
    }

    private func lockAndWipe() {
        countdownTimer?.invalidate()
        withAnimation {
            decryptedSecret = nil
            isUnlocked = false
            passcode = ""
        }
    }
}
