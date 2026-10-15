# GlassQR 🪞📱

A production-ready SwiftUI application targeting **iOS 26.0+ & Xcode 26** showcasing Apple's native **Liquid Glass Design System**, hardware-accelerated QR code generation, live AVFoundation camera scanning, and fluid physics-based animations.

---

## 📁 Project Architecture & File Hierarchy

```text
GlassQR/
├── .github/
│   └── workflows/
│       └── build-ipa.yml                    # Automated GitHub Action to build iPhone IPA
│
├── GlassQR.xcodeproj/
│   ├── project.pbxproj                      # Complete Xcode project configuration
│   └── xcshareddata/
│       └── xcschemes/
│           └── GlassQR.xcscheme             # Shared scheme for headless CI xcodebuild
│
└── GlassQR/
    ├── App/
    │   └── GlassQRApp.swift                 # App entry point & #Preview definitions
    │
    ├── Models/
    │   ├── FeatureHighlight.swift           # Model for Onboarding screen features
    │   ├── ScanResultItem.swift             # Model for decoded QR payload & URL detection
    │   └── AIAgentMessage.swift             # Model for AI messages, threat levels & QR widgets
    │
    ├── Core/
    │   ├── DesignSystem/
    │   │   └── LiquidGlassSystem.swift      # Native iOS 26 Liquid Glass modifiers & button styles
    │   ├── Background/
    │   │   └── LiquidMeshGradientView.swift # Living animated MeshGradient background
    │   ├── Components/
    │   │   └── ReplayOnboardingButton.swift # Toolbar quick-replay test component
    │   ├── AI/
    │   │   └── GlassAIEngine.swift          # Dual-engine on-device heuristics & cloud LLM
    │   ├── Crypto/
    │   │   └── SteganographicQREngine.swift # Zero-knowledge AES-GCM 256-bit & Biometric Face ID vault
    │   ├── OCR/
    │   │   └── LiveTextScannerRepresentable.swift # VisionKit DataScannerViewController & simulator fallback
    │   ├── Translation/
    │   │   └── GlassTranslationEngine.swift # On-device language detection & translation engine
    │   └── NFC/
    │       └── NFCManager.swift             # CoreNFC NDEF reader, writer & hardware simulator
    │
    ├── Features/
    │   ├── Onboarding/
    │   │   ├── WelcomeView.swift            # 3D squircle hero emblem & staggered cards
    │   │   └── FeatureCardView.swift        # Interactive refractive glass card
    │   │
    │   ├── Generator/
    │   │   ├── GeneratorView.swift          # Live input bar, morphing clear, crisp QR card
    │   │   ├── CrispQRRenderer.swift        # CoreImage CIFilter vector rendering engine
    │   │   └── MapLocationPickerView.swift  # Interactive Apple Maps pin dropper & geocoding studio
    │   │
    │   ├── Scanner/
    │   │   ├── ScannerView.swift            # Main scanner screen with HUD & sheet
    │   │   ├── CameraEngineRepresentable.swift # AVCaptureSession & simulator fallback
    │   │   ├── ScannerReticleView.swift     # Viewfinder corner targeting brackets
    │   │   ├── ScanningLaserView.swift      # Glowing oscillating laser bar
    │   │   ├── ScanResultSheetView.swift    # Medium-detent Liquid Glass result sheet & Apple Map preview
    │   │   ├── SecretVaultUnlockSheetView.swift # Biometric Face ID / Passcode encrypted QR unlock studio
    │   │   └── TextOCRSheetView.swift       # Live Camera Text OCR to QR modal studio
    │   │
    │   ├── Translation/
    │   │   └── TranslationSheetView.swift   # On-device real-time translation & dual-language QR studio
    │   │
    │   ├── NFC/
    │   │   └── NFCStudioSheetView.swift     # Liquid Glass NFC radar scanner, NDEF programmer & presets
    │   │
    │   ├── Assistant/
    │   │   └── AIAssistantView.swift        # Liquid Glass AI Agent chat, threat inspector & QR generator
    │   │
    │   └── Navigation/
    │       ├── MainGlassTabView.swift       # 3-tab platter ("Generate", "Scan" & "AI Agent")
    │       └── RootContentView.swift       # Root coordinator between Onboarding & TabView
    │
    └── Resources/
        ├── Info.plist                       # Camera, NFC, Face ID & Location permissions
        └── Assets.xcassets/                 # App icon & AccentColor assets
```

---

## 🤖 GitHub Actions: Automated iPhone IPA Build

A GitHub Actions workflow is included at [`.github/workflows/build-ipa.yml`](file:///.github/workflows/build-ipa.yml) to automatically compile and package an `.ipa` file for iPhone.

### How It Works:
1. **Triggers:** Automatically runs on `push` and `pull_request` to `main` or `master`, or manually via **Workflow Dispatch** under the Actions tab.
2. **Dual-Mode Signing Engine:**
   - **Out-of-the-Box Mode (Zero Configuration):** If no Apple Developer secrets are configured, the workflow compiles and packages an **unsigned/sideloadable `.ipa`** (`Payload/GlassQR.app`). This can be installed immediately using **AltStore**, **Sideloadly**, or **TrollStore**.
   - **Signed Enterprise / Development Mode (Optional):** If you provide Apple Developer credentials in GitHub Secrets, it imports your certificate, configures your provisioning profile, and exports a signed `.ipa`.
3. **Download the IPA:**
   - Go to your repository on GitHub.
   - Click on the **Actions** tab.
   - Select the latest **"Build iPhone IPA"** workflow run.
   - Scroll down to the **Artifacts** section and click **`GlassQR-iOS-IPA`** to download `GlassQR.ipa`.

### Optional: Configuring Apple Developer Secrets in GitHub:
If you wish to sign with an Apple Developer Certificate, add these in **Repo Settings > Secrets and variables > Actions**:
- `BUILD_CERTIFICATE_BASE64`: Base64-encoded `.p12` certificate.
- `P12_PASSWORD`: Password for your `.p12` file.
- `BUILD_PROVISION_PROFILE_BASE64`: Base64-encoded `.mobileprovision` file.
- `KEYCHAIN_PASSWORD`: Any random password string to protect the temporary CI keychain.

---

## 🚀 Key Architectural Features

### 1. Native iOS 26 Liquid Glass Architecture
- **Zero Legacy Workarounds**: Strictly avoids deprecated `.ultraThinMaterial` overlays and manual gradient border hacks.
- **Native Platter Navigation**: Employs a floating `GlassEffectContainer` housing refractive tab platters with spring droplet morphing (`.glassEffectID`), SF Symbol physics, and persistent state preservation across "Generate" and "Scan".
- **Spec-Driven Glass Modifiers**:
  - Floating HUD pills & toasts: `.glassEffect()`
  - Viewfinder framing: `.glassEffect(.clear, in: .rect(cornerRadius: 32))`
  - Interactive cards & hero badges: `.glassEffect(.regular.interactive(), in: .rect(cornerRadius: ...))`
- **Glass Button Hierarchy**:
  - Secondary actions: `.buttonStyle(.glass)`
  - Primary call-to-actions: `.buttonStyle(.glassProminent)`
- **Droplet Morphing (`GlassEffectContainer`)**:
  - Grouped controls paired with `@Namespace` and `.glassEffectID(_:in:)` morph and split like liquid droplets during state transitions.

### 2. High-Performance Optical Engines
- **Real-Time Vector QR & Multi-Format Generation**:
  - Uses `CoreImage.CIFilterBuiltins` (`CIFilter.qrCodeGenerator()`) with `.interpolation(.none)` and custom affine vector scaling.
  - **Custom Center Logo**: Embed any photo or brand mark from your Photos library with anti-aliased squircle clipping.
  - **Error Correction Selector**: Switch between Low (7%), Medium (15%), Quartile (25%), and High (30%) recovery.
  - **Infinitely Scalable Vector Exports**: Export to pure mathematical **SVG** and **Vector PDF** alongside standard PNG.
- **Universal 1D/2D Barcode & Camera Scanner**:
  - Supports all standard symbologies: **QR Code**, **EAN-13**, **EAN-8**, **UPC-E**, **Code 128**, **Code 39**, **Code 93**, **Data Matrix**, **PDF417**, and **Aztec**.
  - **Instant Audio Chime**: Subtle confirmation sound effect and haptic response on code recognition.
  - **One-Tap Product Lookups**: Instant Google and Amazon search buttons for retail product barcodes.
  - **Apple Maps Geo Location Studio (`MapLocationPickerView`)**: Dedicated Geo tool in scanner quick tools allowing users to drop pins on Apple Maps, geocode locations, inspect GPS coordinates, and scan or generate location codes.
  - **Ergonomic Quick Tools Platter**: Center-aligned floating zoom pill (`1x | 2x | 3x`) and 4 balanced quick tools (`Live OCR`, `Geo Map`, `NFC Tag`, `Photos`) with zero text wrapping or distortion across all iPhone screen sizes.
  - **Pixel-Locked Viewfinder Reticle**: Subpixel-aligned camera cutout and reticle brackets sharing identical coordinate offsets and continuous squircle curvature.
  - **Uniform Circular Glass Controls**: Top HUD buttons and navigation bar items use `.buttonStyle(.glassCircle)` to ensure consistent circular proportions without vertical stretching.
  - Thread-safe camera capture running on a dedicated serial background queue with tap-to-focus and optical zoom.
  - Automatic detection of simulator/preview environments with interactive bypass testing chips (including Apple Maps Geo simulation).

### 3. Glass AI Copilot & Multi-Modal Security Agent 🧠✨
- **Multi-Modal Vision & Photo OCR Inspection**:
  - Direct photo attachment via `PhotosPicker`: attach any photo, document, sign, or complex graphic from your library.
  - Optical barcode detection (`VNDetectBarcodesRequest`) decodes hidden 1D/2D symbologies, extracts metadata, and provides real-time security breakdowns.
  - Optical Character Recognition (`VNRecognizeTextRequest`) extracts text lines with language correction and automatically synthesizes a vector QR code.
  - Multi-modal cloud vision support for OpenAI GPT-4o, Google Gemini, and Anthropic Claude.
- **Dynamic AI Personas**:
  - **🪄 Copilot**: Universal assistance, code creation, and natural language reasoning.
  - **🛡️ Security Guard**: Strict link safety audits, tracking parameter scrubbing, homograph spoof checks, and malware download alerts.
  - **🎨 QR Architect**: Error correction recommendations, contrast balancing, and vector branding specifications.
  - **🔒 Vault & Privacy**: Zero-knowledge encryption, steganography, and cryptographic seed protection.
- **Expanded Natural Language QR Generation**:
  - **Zero-Knowledge Encrypted Vaults**: "Encrypt secret note with passcode 1234" -> authentic AES-256 GCM steganographic QR.
  - **Apple Maps Geolocation**: "Drop pin at Tokyo Tower" or "Directions to Central Park" -> native `maps.apple.com/?ll=...` Apple Maps pins.
  - **iCalendar Events (RFC 5545)**: "Schedule Product Launch on Oct 20 at 6pm" -> standard `.ics` calendar invitation.
  - **Cryptocurrency Wallets**: Bitcoin (`BIP-21`), Ethereum (`EIP-681`), and Solana addresses with checksum validation.
  - **Payment Portals**: Instant Venmo, Cash App, and PayPal payment links.
  - **Wi-Fi & vCard 3.0**: Compliant Wi-Fi consortium network schemas and digital business cards.
- **1-Tap Interactive Smart Actions**:
  - **"Program to NFC Tag"**: Directly flash the AI's generated QR code to a physical NFC sticker or card via `NFCStudioSheetView`.
  - **"Open in Apple Maps"**: 1-tap navigation launch for map locations.
  - **"Unlock in Vault Studio"**: 1-tap biometric Face ID / passcode unlock for encrypted QR codes.
- **Voice Read-Aloud & Audio Synthesis (`AVFoundation`)**:
  - Native `AVSpeechSynthesizer` provides Siri-grade voice readout of all AI responses with animated speech waveform indicators.
- **Multi-Provider Cloud & On-Device Engine with Auto-Fetched Models**:
  - **100% On-Device Neural Engine (Default)**: Zero cloud latency, works offline in airplane mode, zero data collection.
  - **Auto-Fetch Compatible Models via API Key**:
    - Automatically contacts OpenAI (`/v1/models`), Google Gemini (`/models?key=...`), Anthropic Claude (`/v1/models`), or Local Ollama (`/v1/models` and `/api/tags`) upon entering or pasting your API key.
    - Filters and displays an interactive Liquid Glass **Model Dropdown Menu** with available models, active status checks, and model counts.
    - 1-tap model switching with support for manual custom model ID overrides.
  - **OpenAI (GPT-4o, GPT-4o-mini, o3-mini, o1-mini)**: Industry-standard reasoning.
  - **Google Gemini (Gemini 1.5 Flash / Pro, Gemini 2.0 Flash)**: High-speed multi-modal comprehension.
  - **Anthropic Claude (Claude 3.5 Sonnet, Claude 3.5 Haiku)**: Nuanced analysis and architectural advice.
  - **Custom / Local (Ollama, LM Studio, vLLM)**: Self-hosted local LLMs over local network.

### 4. Living Liquid MeshGradient
- An oscillating `MeshGradient` powered by `TimelineView(.animation)` shifts through deep midnight indigo, electric violet, ocean cyan, and liquid magenta, creating a rich dynamic palette that refracts through every floating glass element in real time.

### 5. Live Camera Text OCR to QR (VisionKit & Apple Vision) 👁️
- **Hardware-Accelerated Live Text Scanning**:
  - Leverages Apple's native `VisionKit.DataScannerViewController` with optical character recognition targeting text strings directly in the live camera feed.
  - Interactive tap-to-select text highlighting with continuous optical tracking.
  - Seamless fallback on simulators and headless CI runners with built-in test fixtures and manual input support.
- **Instant Vector QR Generation Studio**:
  - Any captured or tapped live text is immediately rendered into a crisp vector QR code preview inside the Liquid Glass modal studio.
  - Auto-categorization engine detects whether recognized text is **Wi-Fi**, **Web URL**, **vCard Contact**, or **Plain Text** with matching badge indicators.
- **Photos Library OCR Fallback**:
  - Picking an image from Photos library runs dual recognition: first tries standard barcode decoding; if no barcode is found, it automatically activates Apple `Vision.VNRecognizeTextRequest` (`.accurate` level) to extract text and generate a QR code seamlessly.
- **Two-Way Studio Routing**:
  - **Scanner Tab**: Quick-access Live OCR viewfinder button (`text.viewfinder`) in the floating camera HUD.
  - **Generator Tab**: Live OCR button in both the navigation bar and input area with smart auto-routing into Wi-Fi, URL, Contact, or Text templates with visual confirmation toasts.

### 6. On-Device Real-Time Translation & Dual-Language QR 🌍
- **Zero Cloud Latency & Total Privacy**:
  - Uses Apple's `NaturalLanguage.NLLanguageRecognizer` to automatically identify the source language (English, Khmer 🇰🇭, Spanish, French, German, Japanese, Chinese, Korean, Thai, Vietnamese, Italian, Arabic, etc.).
  - Instant on-device translation for OCR signs, menus, Wi-Fi stickers, and product labels.
  - Built-in audio pronunciation with `AVSpeechSynthesizer` for both original and translated text.
- **Dual-Language QR Matrix**:
  - 1-tap generation of a **Dual-Language QR Code** combining original and translated text side-by-side, perfect for international cafes, tourist signs, and airport notices.
- **Integrated Across All Tabs**:
  - Available inside **Live OCR Studio**, **Scanner Result Sheet**, and **Generator Studio**.

### 7. NFC Smart Tag Writer & Reader (`CoreNFC`) 📡
- **Universal NDEF Tag Reader**:
  - Read standard NFC Forum Type 1–5, NTAG213, NTAG215, and NTAG216 physical tags.
  - Parses URI records (web links, tel, sms), Text records, and custom MIME payloads (Wi-Fi, vCard).
  - 1-tap conversion of any read NFC tag into an animated vector QR code.
- **Physical NFC Tag Programmer / Writer**:
  - Write any generated QR code payload (Wi-Fi network strings, personal contact vCards, web links, or plain text) directly to physical NFC stickers and smart cards.
  - Integrated capacity validation, lock status query, and success confirmation chimes.
- **Full Simulator & CI Support**:
  - Built-in `SimulatedNFCTag` presets ("Office Wi-Fi Tag", "Web URI Tag", "Business Card vCard Tag") allow complete testing on simulators and headless GitHub Actions without hardware dependencies.

### 8. Zero-Knowledge Steganographic Encrypted QR (CryptoKit & Face ID) 🔐
- **Zero-Knowledge Architecture**:
  - Military-grade **AES-GCM 256-bit** authenticated symmetric encryption powered by Apple's hardware-backed `CryptoKit`.
  - Keys derived via SHA-256 with nonce and 128-bit authentication tag verification. Secrets are encrypted and decrypted purely in device RAM — zero data ever touches disk or the cloud.
- **Steganographic Disguise**:
  - To third-party scanners, camera apps, or onlookers, the generated QR appears as an innocent, ordinary web address (e.g. `https://glassqr.app/vault#enc=...` or custom decoy URL).
  - GlassQR automatically detects the cryptographic steganographic header signature (`GQR_VAULT:1:`).
- **Biometric Face ID / Touch ID / Passcode Vault**:
  - Scanning an encrypted QR automatically raises the biometric authentication modal (`LocalAuthentication` framework).
  - Optional fallback to user's secret password/passcode.
  - **Auto-Scrub Memory Security**: Auto-locks after 30 seconds of inactivity to protect sensitive passwords, private keys, seeds, and medical records from shoulder-surfing.

### 9. Interactive Apple Maps Pin Dropper & Geolocation Studio (`MapKit`) 📍
- **Default Apple Maps Pin Dropping (`MapKit.Map`)**:
  - Drop a pin anywhere on the globe with fluid pan, pinch, and zoom controls.
  - Centered crosshair target with drop pin indicator and coordinate badge displaying precise latitude and longitude to 6 decimal places.
- **Instant Search & Autocomplete (`MKLocalSearch`)**:
  - Search any place, business, café, landmark, or address worldwide with real-time suggestion pills and 1-tap camera centering.
- **One-Tap Current Location GPS (`CoreLocation`)**:
  - Real-time GPS location button centers the map instantly on user's current coordinates.
- **Reverse Geocoding (`CLGeocoder`)**:
  - Converts dropped coordinates in real time into human-readable street names, cities, and administrative areas.
- **Universal Apple Maps QR Generator & Native Scanner Preview**:
  - Encodes coordinates into standard Apple Maps deep-links (`maps.apple.com/?ll=...&q=...`).
  - Scanned location QRs render a high-fidelity native Apple Maps widget with a custom pin marker, address header, coordinate badge, and 1-tap **"Open in Apple Maps"** navigation button.

---

## 🛠️ How to Open and Run Locally

1. Open `GlassQR.xcodeproj` in **Xcode 16 / Xcode 26**.
2. Select an iOS Simulator (e.g., iPhone 16 Pro / iPhone 17 Pro) or a connected physical device.
3. Press **Cmd + R** to build and run.
4. If testing in the Simulator or Xcode Previews, use the built-in **"Simulate QR Scan"** button in the Scanner tab to test sheet presentations, URL opening, and haptics without physical camera hardware.
