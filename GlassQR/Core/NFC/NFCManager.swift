import Foundation
import CoreNFC
import UIKit

/// High-level mode for NFC session
public enum NFCMode: Sendable, Equatable {
    case read
    case write(payload: String)
}

/// Information parsed from a physical or simulated NFC tag
public struct NFCTagInfo: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let payloadText: String
    public let recordType: String
    public let timestamp: Date
    public let isSimulated: Bool

    public init(id: UUID = UUID(), payloadText: String, recordType: String, timestamp: Date = Date(), isSimulated: Bool = false) {
        self.id = id
        self.payloadText = payloadText
        self.recordType = recordType
        self.timestamp = timestamp
        self.isSimulated = isSimulated
    }
}

/// Core manager for reading and writing NFC tags using CoreNFC
public final class NFCManager: NSObject, ObservableObject, @unchecked Sendable {
    public static let shared = NFCManager()

    @Published public var isReadingAvailable: Bool = false
    @Published public var isSessionActive: Bool = false
    @Published public var lastReadTag: NFCTagInfo? = nil
    @Published public var lastWriteSuccess: Bool = false
    @Published public var statusMessage: String = "Ready"
    @Published public var errorMessage: String? = nil

    private var nfcSession: NFCNDEFReaderSession?

    private let modeLock = NSLock()
    private var _currentMode: NFCMode = .read
    private var currentMode: NFCMode {
        get {
            modeLock.lock()
            defer { modeLock.unlock() }
            return _currentMode
        }
        set {
            modeLock.lock()
            defer { modeLock.unlock() }
            _currentMode = newValue
        }
    }

    public override init() {
        super.init()
        self.isReadingAvailable = NFCNDEFReaderSession.readingAvailable
    }

    /// Check if physical NFC is available on this device
    public func checkAvailability() -> Bool {
        let available = NFCNDEFReaderSession.readingAvailable
        DispatchQueue.main.async {
            self.isReadingAvailable = available
        }
        return available
    }

    /// Starts scanning for an NFC tag to read
    public func startReading() {
        self.currentMode = .read

        DispatchQueue.main.async {
            self.errorMessage = nil
            self.lastWriteSuccess = false
        }

        guard NFCNDEFReaderSession.readingAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC hardware is not available on this device (Simulator/iPad). You can use Simulated NFC Tags below."
            }
            return
        }

        nfcSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: true
        )
        nfcSession?.alertMessage = "Hold the top edge of your iPhone near the NFC tag."
        nfcSession?.begin()

        DispatchQueue.main.async {
            self.isSessionActive = true
            self.statusMessage = "Scanning for NFC tag..."
        }
    }

    /// Starts scanning for an NFC tag to write a payload to
    public func startWriting(payload: String) {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                self.errorMessage = "Cannot write empty payload to NFC tag."
            }
            return
        }

        self.currentMode = .write(payload: trimmed)

        DispatchQueue.main.async {
            self.errorMessage = nil
            self.lastWriteSuccess = false
        }

        guard NFCNDEFReaderSession.readingAvailable else {
            DispatchQueue.main.async {
                self.statusMessage = "NFC hardware is not available on this device. You can test writing with Simulated NFC Tags."
            }
            return
        }

        nfcSession = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        nfcSession?.alertMessage = "Hold iPhone near a writable NFC tag to program it."
        nfcSession?.begin()

        DispatchQueue.main.async {
            self.isSessionActive = true
            self.statusMessage = "Ready to write to NFC tag..."
        }
    }

    /// Simulator test method to simulate reading a tag without physical hardware
    public func simulateTagRead(presetText: String, typeName: String = "URI / Text") {
        let tag = NFCTagInfo(payloadText: presetText, recordType: typeName, isSimulated: true)
        DispatchQueue.main.async {
            self.lastReadTag = tag
            self.statusMessage = "Simulated Tag Read: \(typeName)"
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }

    /// Simulator test method to simulate writing to a tag
    public func simulateTagWrite(payload: String) {
        DispatchQueue.main.async {
            self.lastWriteSuccess = true
            self.statusMessage = "Simulated Write Successful!"
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension NFCManager: NFCNDEFReaderSessionDelegate {
    public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        DispatchQueue.main.async {
            self.isSessionActive = true
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isSessionActive = false
            let nfcError = error as? NFCReaderError
            if nfcError?.code != .readerSessionInvalidationErrorUserCanceled {
                self.errorMessage = error.localizedDescription
                self.statusMessage = "NFC Session ended: \(error.localizedDescription)"
            } else {
                self.statusMessage = "Ready"
            }
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        var extractedText = ""
        var recordType = "NDEF Payload"

        for message in messages {
            for record in message.records {
                if let url = record.wellKnownTypeURIPayload() {
                    extractedText = url.absoluteString
                    recordType = "URI"
                    break
                } else {
                    let (textOpt, _) = record.wellKnownTypeTextPayload()
                    if let text = textOpt {
                        extractedText = text
                        recordType = "Text"
                        break
                    } else if let stringPayload = String(data: record.payload, encoding: .utf8) {
                        extractedText = stringPayload
                        recordType = "MIME / Data"
                        break
                    }
                }
            }
            if !extractedText.isEmpty { break }
        }

        let finalPayload = extractedText
        let finalType = recordType

        DispatchQueue.main.async {
            if !finalPayload.isEmpty {
                let tag = NFCTagInfo(payloadText: finalPayload, recordType: finalType, isSimulated: false)
                self.lastReadTag = tag
                self.statusMessage = "Tag Scanned: \(finalType)"
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            } else {
                self.statusMessage = "Tag contained no readable NDEF data."
            }
        }
    }

    public func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard case .write(let payload) = self.currentMode else {
            // Read Mode with didDetect tags callback
            if let firstTag = tags.first {
                session.connect(to: firstTag) { [weak self] error in
                    guard let self = self, error == nil else {
                        session.invalidate(errorMessage: "Could not connect to NFC tag.")
                        return
                    }
                    firstTag.readNDEF { message, _ in
                        if let msg = message {
                            self.readerSession(session, didDetectNDEFs: [msg])
                        }
                        session.invalidate()
                    }
                }
            }
            return
        }

        // Write Mode
        guard let tag = tags.first else {
            session.invalidate(errorMessage: "No valid NFC tag detected.")
            return
        }

        session.connect(to: tag) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                session.invalidate(errorMessage: "Connection failed: \(error.localizedDescription)")
                return
            }

            tag.queryNDEFStatus { [weak self] status, capacity, queryError in
                guard let self = self else { return }
                if let queryError = queryError {
                    session.invalidate(errorMessage: "Could not query tag status: \(queryError.localizedDescription)")
                    return
                }

                switch status {
                case .notSupported:
                    session.invalidate(errorMessage: "Tag is not NDEF compliant.")
                case .readOnly:
                    session.invalidate(errorMessage: "Tag is locked (Read-Only).")
                case .readWrite:
                    // Construct NDEF Payload
                    let ndefPayload: NFCNDEFPayload?
                    let safeURL = URL(string: payload) ?? URL(string: payload.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                    if let url = safeURL, payload.lowercased().hasPrefix("http") {
                        ndefPayload = NFCNDEFPayload.wellKnownTypeURIPayload(url: url)
                    } else {
                        ndefPayload = NFCNDEFPayload.wellKnownTypeTextPayload(string: payload, locale: Locale(identifier: "en"))
                    }

                    guard let validPayload = ndefPayload else {
                        session.invalidate(errorMessage: "Failed to construct NDEF payload.")
                        return
                    }

                    let message = NFCNDEFMessage(records: [validPayload])

                    // Check capacity
                    if capacity > 0 && message.length > capacity {
                        session.invalidate(errorMessage: "Tag capacity (\(capacity) bytes) too small for payload (\(message.length) bytes).")
                        return
                    }

                    tag.writeNDEF(message) { [weak self] writeError in
                        guard let self = self else { return }
                        if let writeError = writeError {
                            session.invalidate(errorMessage: "Write failed: \(writeError.localizedDescription)")
                        } else {
                            session.alertMessage = "Payload written to NFC tag successfully! ✨"
                            session.invalidate()

                            DispatchQueue.main.async {
                                self.lastWriteSuccess = true
                                self.statusMessage = "Payload written successfully!"
                                let feedback = UINotificationFeedbackGenerator()
                                feedback.notificationOccurred(.success)
                            }
                        }
                    }

                @unknown default:
                    session.invalidate(errorMessage: "Unknown tag status.")
                }
            }
        }
    }
}
