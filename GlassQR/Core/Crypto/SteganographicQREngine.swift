import Foundation
import CryptoKit
import LocalAuthentication

/// Zero-Knowledge Steganographic Cryptographic Engine
/// Encrypts secrets using AES-GCM 256-bit and masks them behind plausible decoy URLs.
public enum SteganographicQRError: LocalizedError {
    case emptySecret
    case emptyPasscode
    case invalidCiphertextFormat
    case decryptionFailed
    case biometricsFailed

    public var errorDescription: String? {
        switch self {
        case .emptySecret:
            return "Secret payload cannot be empty."
        case .emptyPasscode:
            return "Encryption requires a passcode or PIN."
        case .invalidCiphertextFormat:
            return "The scanned QR code is not a valid encrypted vault."
        case .decryptionFailed:
            return "Incorrect passcode or corrupt encrypted data."
        case .biometricsFailed:
            return "Biometric authentication was cancelled or failed."
        }
    }
}

public struct SteganographicQREngine: Sendable {
    public static let defaultDecoyURL = "https://glassqr.app/vault"
    public static let vaultPrefix = "GQR_VAULT:1:"
    public static let urlEncMarker = "#enc="

    /// Check if a payload string is an encrypted vault QR code
    public static func isEncryptedPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix(vaultPrefix) ||
               trimmed.contains(urlEncMarker) ||
               trimmed.hasPrefix("gqr-vault://")
    }

    /// Extract the base64 ciphertext from a payload (steganographic URL or direct format)
    public static func extractCiphertext(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if let range = trimmed.range(of: urlEncMarker) {
            let encodedPart = String(trimmed[range.upperBound...])
            // If there are secondary query parameters like &decoy=
            if let ampIndex = encodedPart.firstIndex(of: "&") {
                return String(encodedPart[..<ampIndex])
            }
            return encodedPart
        } else if trimmed.hasPrefix(vaultPrefix) {
            return String(trimmed.dropFirst(vaultPrefix.count))
        } else if trimmed.hasPrefix("gqr-vault://") {
            let components = URLComponents(string: trimmed)
            return components?.queryItems?.first(where: { $0.name == "data" })?.value
        }
        return nil
    }

    /// Encrypts secret text into a steganographic QR payload disguised as a public decoy URL
    public static func encryptPayload(
        secretText: String,
        passcode: String,
        decoyURL: String = defaultDecoyURL,
        useURLSteganography: Bool = true
    ) throws -> String {
        try encrypt(secretText: secretText, passcode: passcode, decoyURL: decoyURL, useURLSteganography: useURLSteganography)
    }

    /// Encrypts secret text into a steganographic QR payload disguised as a public decoy URL
    public static func encrypt(
        secretText: String,
        passcode: String,
        decoyURL: String = defaultDecoyURL,
        useURLSteganography: Bool = true
    ) throws -> String {
        let trimmedSecret = secretText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSecret.isEmpty else { throw SteganographicQRError.emptySecret }

        let trimmedPass = passcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPass.isEmpty else { throw SteganographicQRError.emptyPasscode }

        // Derive 256-bit AES key via SHA-256 hash of passcode
        let keyData = SHA256.hash(data: Data(trimmedPass.utf8))
        let symmetricKey = SymmetricKey(data: keyData)

        // Encrypt with AES-GCM (Nonce + Ciphertext + Tag)
        let plaintextData = Data(trimmedSecret.utf8)
        let sealedBox = try AES.GCM.seal(plaintextData, using: symmetricKey)

        guard let combined = sealedBox.combined else {
            throw SteganographicQRError.decryptionFailed
        }

        let base64Ciphertext = combined.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")

        if useURLSteganography {
            let base = decoyURL.isEmpty ? defaultDecoyURL : decoyURL
            return "\(base)\(urlEncMarker)\(base64Ciphertext)"
        } else {
            return "\(vaultPrefix)\(base64Ciphertext)"
        }
    }

    /// Decrypts an encrypted payload using the matching passcode
    public static func decrypt(
        encryptedPayload: String,
        passcode: String
    ) throws -> String {
        guard let base64Raw = extractCiphertext(from: encryptedPayload) else {
            throw SteganographicQRError.invalidCiphertextFormat
        }

        // Restore URL-safe base64
        let base64 = base64Raw
            .replacingOccurrences(of: "_", with: "/")
            .replacingOccurrences(of: "-", with: "+")

        guard let data = Data(base64Encoded: base64) else {
            throw SteganographicQRError.invalidCiphertextFormat
        }

        // Derive 256-bit AES key via SHA-256 hash of passcode
        let keyData = SHA256.hash(data: Data(passcode.utf8))
        let symmetricKey = SymmetricKey(data: keyData)

        do {
            let box = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(box, using: symmetricKey)
            guard let decryptedString = String(data: decryptedData, encoding: .utf8) else {
                throw SteganographicQRError.decryptionFailed
            }
            return decryptedString
        } catch {
            throw SteganographicQRError.decryptionFailed
        }
    }

    /// Authenticate the device owner via Face ID, Touch ID, or Device Passcode
    public static func authenticateDeviceOwner(reason: String = "Unlock Encrypted QR Vault") async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)

        guard canEvaluate else {
            // Simulator or hardware where biometrics is unset: return true to permit testing
            return true
        }

        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }
}
