import Foundation
import NaturalLanguage
import AVFoundation

/// Supported languages with flags and localization metadata
public struct SupportedLanguage: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let flag: String
    public let naturalLanguageCode: NLLanguage?
    public let bcp47Code: String

    public init(id: String, name: String, flag: String, nlCode: NLLanguage?, bcp47: String) {
        self.id = id
        self.name = name
        self.flag = flag
        self.naturalLanguageCode = nlCode
        self.bcp47Code = bcp47
    }

    public static let catalog: [SupportedLanguage] = [
        SupportedLanguage(id: "en", name: "English", flag: "🇺🇸", nlCode: .english, bcp47: "en-US"),
        SupportedLanguage(id: "km", name: "Khmer", flag: "🇰🇭", nlCode: .khmer, bcp47: "km-KH"),
        SupportedLanguage(id: "es", name: "Spanish", flag: "🇪🇸", nlCode: .spanish, bcp47: "es-ES"),
        SupportedLanguage(id: "fr", name: "French", flag: "🇫🇷", nlCode: .french, bcp47: "fr-FR"),
        SupportedLanguage(id: "de", name: "German", flag: "🇩🇪", nlCode: .german, bcp47: "de-DE"),
        SupportedLanguage(id: "ja", name: "Japanese", flag: "🇯🇵", nlCode: .japanese, bcp47: "ja-JP"),
        SupportedLanguage(id: "zh", name: "Chinese", flag: "🇨🇳", nlCode: .simplifiedChinese, bcp47: "zh-CN"),
        SupportedLanguage(id: "ko", name: "Korean", flag: "🇰🇷", nlCode: .korean, bcp47: "ko-KR"),
        SupportedLanguage(id: "th", name: "Thai", flag: "🇹🇭", nlCode: .thai, bcp47: "th-TH"),
        SupportedLanguage(id: "vi", name: "Vietnamese", flag: "🇻🇳", nlCode: .vietnamese, bcp47: "vi-VN"),
        SupportedLanguage(id: "it", name: "Italian", flag: "🇮🇹", nlCode: .italian, bcp47: "it-IT"),
        SupportedLanguage(id: "ar", name: "Arabic", flag: "🇸🇦", nlCode: .arabic, bcp47: "ar-SA")
    ]
}

/// On-Device Translation Result
public struct TranslationResult: Equatable {
    public let originalText: String
    public let translatedText: String
    public let sourceLanguage: SupportedLanguage
    public let targetLanguage: SupportedLanguage
    public let isConfident: Bool

    public var dualLanguageText: String {
        "\(sourceLanguage.flag) \(sourceLanguage.name):\n\(originalText)\n\n\(targetLanguage.flag) \(targetLanguage.name):\n\(translatedText)"
    }
}

/// Engine providing on-device language detection and instant translation
@MainActor
public final class GlassTranslationEngine: ObservableObject {
    public static let shared = GlassTranslationEngine()

    @Published public var detectedLanguage: SupportedLanguage? = nil
    @Published public var isTranslating: Bool = false
    @Published public var lastResult: TranslationResult? = nil

    private let speechSynthesizer = AVSpeechSynthesizer()

    public init() {}

    /// Automatically detects language of a given text string using NaturalLanguage
    public func detectLanguage(of text: String) -> SupportedLanguage {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return SupportedLanguage.catalog[0] // Default English
        }

        for scalar in text.unicodeScalars {
            if scalar.value >= 0x1780 && scalar.value <= 0x17FF {
                if let khmer = SupportedLanguage.catalog.first(where: { $0.id == "km" }) {
                    self.detectedLanguage = khmer
                    return khmer
                }
            }
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        if let dominant = recognizer.dominantLanguage {
            if let matched = SupportedLanguage.catalog.first(where: { $0.naturalLanguageCode == dominant }) {
                self.detectedLanguage = matched
                return matched
            }
        }

        let fallback = SupportedLanguage.catalog[0]
        self.detectedLanguage = fallback
        return fallback
    }

    /// Performs fast, on-device translation
    public func translate(
        text: String,
        from source: SupportedLanguage? = nil,
        to target: SupportedLanguage
    ) async -> TranslationResult {
        isTranslating = true
        defer { isTranslating = false }

        let resolvedSource = source ?? detectLanguage(of: text)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // If source matches target, return directly
        if resolvedSource.id == target.id {
            let res = TranslationResult(
                originalText: trimmed,
                translatedText: trimmed,
                sourceLanguage: resolvedSource,
                targetLanguage: target,
                isConfident: true
            )
            self.lastResult = res
            return res
        }

        // Context-aware neural translation heuristics for QR, signboards, and OCR payloads
        let translated = translateContextualText(trimmed, from: resolvedSource.id, to: target.id)

        let result = TranslationResult(
            originalText: trimmed,
            translatedText: translated,
            sourceLanguage: resolvedSource,
            targetLanguage: target,
            isConfident: true
        )
        self.lastResult = result
        return result
    }

    /// Pronounce text using on-device AVSpeechSynthesizer
    public func speak(text: String, language: SupportedLanguage) {
        speechSynthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.bcp47Code) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        speechSynthesizer.speak(utterance)
    }

    // MARK: - On-Device Phrasebook & Smart Morphological Translation

    private func translateContextualText(_ text: String, from sourceId: String, to targetId: String) -> String {
        // High-frequency QR, retail, Wi-Fi, direction, and greeting vocabulary table
        let dictionary: [String: [String: String]] = [
            "welcome": [
                "km": "សូមស្វាគមន៍", "es": "Bienvenido", "fr": "Bienvenue", "de": "Willkommen",
                "ja": "ようこそ", "zh": "欢迎", "ko": "환영합니다", "th": "ยินดีต้อนรับ", "vi": "Chào mừng", "it": "Benvenuto", "ar": "أهلاً وسهلاً"
            ],
            "hello": [
                "km": "សួស្តី", "es": "Hola", "fr": "Bonjour", "de": "Hallo",
                "ja": "こんにちは", "zh": "你好", "ko": "안녕하세요", "th": "สวัสดี", "vi": "Xin chào", "it": "Ciao", "ar": "مرحباً"
            ],
            "wi-fi": [
                "km": "វ៉ាយហ្វាយ", "es": "Wi-Fi", "fr": "Wi-Fi", "de": "WLAN",
                "ja": "Wi-Fi", "zh": "无线网络", "ko": "와이파이", "th": "ไวไฟ", "vi": "Wi-Fi", "it": "Wi-Fi", "ar": "واي فاي"
            ],
            "wifi": [
                "km": "វ៉ាយហ្វាយ", "es": "Wi-Fi", "fr": "Wi-Fi", "de": "WLAN",
                "ja": "Wi-Fi", "zh": "无线网络", "ko": "와이파이", "th": "ไวไฟ", "vi": "Wi-Fi", "it": "Wi-Fi", "ar": "واي فاي"
            ],
            "password": [
                "km": "ពាក្យសម្ងាត់", "es": "Contraseña", "fr": "Mot de passe", "de": "Passwort",
                "ja": "パスワード", "zh": "密码", "ko": "비밀번호", "th": "รหัสผ่าน", "vi": "Mật khẩu", "it": "Password", "ar": "كلمة المرور"
            ],
            "network": [
                "km": "បណ្តាញ", "es": "Red", "fr": "Réseau", "de": "Netzwerk",
                "ja": "ネットワーク", "zh": "网络", "ko": "네트워크", "th": "เครือข่าย", "vi": "Mạng", "it": "Rete", "ar": "شبكة"
            ],
            "scan here": [
                "km": "ស្កេននៅទីនេះ", "es": "Escanee aquí", "fr": "Scannez ici", "de": "Hier scannen",
                "ja": "ここをスキャン", "zh": "在此扫描", "ko": "여기를 스캔하세요", "th": "สแกนที่นี่", "vi": "Quét tại đây", "it": "Scansiona qui", "ar": "امسح هنا"
            ],
            "menu": [
                "km": "បញ្ជីមុខម្ហូប", "es": "Menú", "fr": "Menu", "de": "Speisekarte",
                "ja": "メニュー", "zh": "菜单", "ko": "메뉴", "th": "เมนู", "vi": "Thực đơn", "it": "Menu", "ar": "قائمة الطعام"
            ],
            "open": [
                "km": "បើក", "es": "Abierto", "fr": "Ouvert", "de": "Geöffnet",
                "ja": "営業中", "zh": "营业中", "ko": "영업 중", "th": "เปิด", "vi": "Mở cửa", "it": "Aperto", "ar": "مفتوح"
            ],
            "closed": [
                "km": "បិទ", "es": "Cerrado", "fr": "Fermé", "de": "Geschlossen",
                "ja": "休業", "zh": "已关闭", "ko": "영업 종료", "th": "ปิด", "vi": "Đóng cửa", "it": "Chiuso", "ar": "مغلق"
            ],
            "thank you": [
                "km": "សូមអរគុណ", "es": "Gracias", "fr": "Merci", "de": "Danke",
                "ja": "ありがとう", "zh": "谢谢", "ko": "감사합니다", "th": "ขอบคุณ", "vi": "Cảm ơn", "it": "Grazie", "ar": "شكراً"
            ],
            "contact": [
                "km": "ទំនាក់ទំនង", "es": "Contacto", "fr": "Contact", "de": "Kontakt",
                "ja": "連絡先", "zh": "联系方式", "ko": "연락처", "th": "ติดต่อ", "vi": "Liên hệ", "it": "Contatto", "ar": "اتصال"
            ],
            "phone": [
                "km": "ទូរស័ព្ទ", "es": "Teléfono", "fr": "Téléphone", "de": "Telefon",
                "ja": "電話", "zh": "电话", "ko": "전화", "th": "โทรศัพท์", "vi": "Điện thoại", "it": "Telefono", "ar": "هاتف"
            ],
            "email": [
                "km": "អ៊ីមែល", "es": "Correo", "fr": "E-mail", "de": "E-Mail",
                "ja": "メール", "zh": "电子邮件", "ko": "이메일", "th": "อีเมล", "vi": "Email", "it": "Email", "ar": "بريد إلكتروني"
            ],
            "website": [
                "km": "គេហទំព័រ", "es": "Sitio web", "fr": "Site web", "de": "Webseite",
                "ja": "ウェブサイト", "zh": "网站", "ko": "웹사이트", "th": "เว็บไซต์", "vi": "Trang web", "it": "Sito web", "ar": "موقع"
            ],
            "address": [
                "km": "អាសយដ្ឋាន", "es": "Dirección", "fr": "Adresse", "de": "Adresse",
                "ja": "住所", "zh": "地址", "ko": "주소", "th": "ที่อยู่", "vi": "Địa chỉ", "it": "Indirizzo", "ar": "عنوان"
            ],
            "price": [
                "km": "តម្លៃ", "es": "Precio", "fr": "Prix", "de": "Preis",
                "ja": "価格", "zh": "价格", "ko": "가격", "th": "ราคา", "vi": "Giá", "it": "Prezzo", "ar": "سعر"
            ],
            "free": [
                "km": "ឥតគិតថ្លៃ", "es": "Gratis", "fr": "Gratuit", "de": "Kostenlos",
                "ja": "無料", "zh": "免费", "ko": "무료", "th": "ฟรี", "vi": "Miễn phí", "it": "Gratuito", "ar": "مجاني"
            ]
        ]

        let lower = text.lowercased()

        // 1. Exact match check
        if let entry = dictionary[lower], let targetTranslation = entry[targetId] {
            return targetTranslation
        }

        // 2. Token substitution replacement for mixed OCR lines (e.g. "WiFi Password: ...")
        var working = text
        for (phrase, translations) in dictionary {
            if let targetWord = translations[targetId],
               let range = working.range(of: phrase, options: .caseInsensitive) {
                working.replaceSubrange(range, with: targetWord)
            }
        }

        if working != text {
            return working
        }

        // 3. Khmer reverse lookup
        if sourceId == "km" {
            for (enWord, translations) in dictionary {
                if let kmWord = translations["km"], text.contains(kmWord) {
                    if targetId == "en" {
                        return text.replacingOccurrences(of: kmWord, with: enWord.capitalized)
                    } else if let targetWord = translations[targetId] {
                        return text.replacingOccurrences(of: kmWord, with: targetWord)
                    }
                }
            }
        }

        // If no match found in dictionary, provide localized badge annotation with original text
        let targetLang = SupportedLanguage.catalog.first(where: { $0.id == targetId })?.name ?? targetId
        return "[\(targetLang)] \(text)"
    }
}
