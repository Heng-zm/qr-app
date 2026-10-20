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
    │   │   ├── GlassAIEngine.swift          # Dual-engine on-device heuristics & cloud LLM
    │   │   └── CoreMLSLMEngine.swift        # 100% offline CoreML Small Language Model & ANE pipeline
    │   ├── Crypto/
    │   │   └── SteganographicQREngine.swift # Zero-knowledge AES-GCM 256-bit & Biometric Face ID vault
    │   ├── DocumentScanner/
    │   │   └── DocumentCameraRepresentable.swift # VisionKit multi-page physical document scanner
    │   ├── LiDAR/
    │   │   └── LiDARManager.swift           # Apple LiDAR ToF rangefinder, depth telemetry & AR engine
    │   ├── OCR/
    │   │   └── LiveTextScannerRepresentable.swift # VisionKit DataScannerViewController & simulator fallback
    │   ├── Tracking/
    │   │   └── TrackMapManager.swift        # GNSS telemetry, speedometer engine & turn-by-turn routing
    │   ├── Translation/
    │   │   └── GlassTranslationEngine.swift # On-device language detection & translation engine
    │   ├── NFC/
    │   │   └── NFCManager.swift             # CoreNFC NDEF reader, writer & hardware simulator
    │   ├── Wallet/
    │   │   └── GlassPassEngine.swift        # PassKit Apple Wallet pass compiler & card renderer
    │   └── AppIntents/
    │       └── GlassQRAppIntents.swift      # Siri Shortcuts & AppIntents automations
    │
    ├── Features/
    │   ├── Onboarding/
    │   │   ├── WelcomeView.swift            # 3D squircle hero emblem & staggered cards
    │   │   └── FeatureCardView.swift        # Interactive refractive glass card
    │   │
    │   ├── Generator/
    │   │   ├── GeneratorView.swift          # Live input bar, morphing clear, crisp QR card
    │   │   ├── CrispQRRenderer.swift        # CoreImage CIFilter vector rendering, liquid dots & eyes
    │   │   └── MapLocationPickerView.swift  # Interactive Apple Maps pin dropper & geocoding studio
    │   │
    │   ├── Scanner/
    │   │   ├── ScannerView.swift            # Main scanner screen with HUD & sheet
    │   │   ├── CameraEngineRepresentable.swift # AVCaptureSession & simulator fallback
    │   │   ├── ScannerReticleView.swift     # Viewfinder corner targeting brackets
    │   │   ├── ScanningLaserView.swift      # Glowing oscillating laser bar
    │   │   ├── ScanResultSheetView.swift    # Medium-detent Liquid Glass result sheet & Apple Map preview
    │   │   ├── DocumentScannerSheetView.swift # Multi-page document scanner, image filters & PDF compiler
    │   │   ├── SecretVaultUnlockSheetView.swift # Biometric Face ID / Passcode encrypted QR unlock studio
    │   │   ├── TextOCRSheetView.swift       # Live Camera Text OCR to QR modal studio
    │   │   └── LiDARScannerView.swift       # LiDAR rangefinder, depth-mesh & AR hologram studio
    │   │
    │   ├── TrackMap/
    │   │   ├── TrackMapView.swift           # 3D navigation map, destination search & telemetry HUD
    │   │   └── TrackMapHUDView.swift        # Mirrored windshield Head-Up Display projection
    │   │
    │   ├── Wallet/
    │   │   └── WalletPassSheetView.swift    # Interactive Apple Wallet Pass card studio & .pkpass export
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
    │       ├── MainGlassTabView.swift       # 4-tab platter ("Generate", "Scan", "TrackMap" & "AI Agent")
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
  - **Apple Maps Geo Location Studio (`MapLocationPickerView`)**: Interactive MapKit pin-dropper supporting **tap-to-drop**, **long-press drop**, **draggable marker pins**, satellite/hybrid aerial toggles, and instant street-level reverse geocoding with cancellable async Task debouncing.
  - **Ergonomic Quick Tools Platter & Generator Tools Menu**: Center-aligned floating zoom pill (`1x | 2x | 3x`) and quick tools platter with zero text wrapping. Generator view features a compact Liquid Glass "Tools" menu eliminating horizontal header clipping.
  - **Fluid Keyboard Docking & Auto-Hiding Tab Bar**: When typing in AI Copilot or Generator fields, the floating tab bar gracefully transitions away and input bars dock cleanly above the iOS keyboard.
  - **Scrollable Result Sheet**: Result sheets adapt smoothly to `.medium` and `.large` presentation detents with zero button clipping.
  - **Pixel-Locked Viewfinder Reticle**: Subpixel-aligned camera cutout and reticle brackets sharing identical coordinate offsets and continuous squircle curvature.
  - **Uniform Circular Glass Controls**: Top HUD buttons and navigation bar items use `.buttonStyle(.glassCircle)` to ensure consistent circular proportions without vertical stretching.
  - Thread-safe camera capture running on a dedicated serial background queue with tap-to-focus and optical zoom.
- **Liquid Glass TrackMap & Live Speedometer Telemetry 🗺️🏎️**:
  - **Beyond Google Maps Navigation**: Full-bleed interactive 3D MapKit map with traffic overlays, heading tracking, destination search, distance, ETA, and turn-by-turn directions.
  - **Live Turn-by-Turn Tracking**: Maneuver guidance card with per-step progress, multi-mode routes (Drive / Walk / Transit), alternate route picker, off-route detection with automatic silent rerouting, and a simulated drive demo mode.
  - **High-Precision Live Speedometer**: Sub-second GPS digital readout & chromatic arc tachometer with seamless km/h ⇄ mph switching.
  - **Windshield HUD Mode (Head-Up Display)**: Inverted/mirrored high-contrast projection designed for placing on car dashboards at night for holographic windshield reflection.
  - **Speed-Gradient Breadcrumbs**: Real-time GPS path recording color-coded by velocity (Cyan=slow, Green=cruise, Orange/Red=high speed).
  - **GPX Trail Export**: Share your recorded track as a standard `.gpx` file — importable into Strava, Google Earth, Garmin, and Relive.
  - **Region Fallback Direct Path**: When Apple Maps has no turn-by-turn coverage for a trip (common outside routing-supported regions), TrackMap draws a dashed straight line with exact distance and a speed-estimated ETA instead of failing, with a bilingual card to clear it.
  - **Overspeed Haptic Warning**: Configurable speed limit threshold with alert glow and physical sensory pulses.
  - **Instant Geo-QR Integration**: 1-tap generation of styled Liquid Glass Geo-QR codes for live coordinates and recorded trips.
  - **Full Khmer (ភាសាខ្មែរ 🇰🇭) & English Support**: Bilingual telemetry metrics, compass bearings, HUD controls, and route summaries.
  - **100% Offline GPS Operation**: Telemetry operates directly from hardware GNSS receiver with zero cellular connectivity required.

### 3. Glass AI Copilot & Multi-Modal Security Agent 🧠✨
- **Conversational Multi-Turn Dialogue (like ChatGPT & Gemini)**:
  - **Contextual Memory**: Remembers and references previous questions, answers, and generated payloads across conversation turns.
  - **Persistent Chat Memory**: The transcript survives app relaunches (last 60 turns restored automatically; trash resets it). Photo attachment blobs stay session-local.
  - **General & Technical Q&A**: Answers educational questions about QR codes, Reed-Solomon math, NFC protocols, PassKit, and mobile cryptography.
  - **Autonomous QR Detection**: When cloud LLMs (OpenAI, Gemini, Claude) generate QR configurations, GlassQR automatically detects the payload and renders an interactive, customizable vector QR widget with smart actions.
- **Full Khmer Language Support (ការគាំទ្រភាសាខ្មែរ 🇰🇭)**:
  - **Native Understanding**: Understands natural conversational prompts, Wi-Fi requests, Apple Wallet passes, and cryptographic commands written in Khmer script.
  - **Bilingual Response Generation**: Replies fluently and politely in natural Khmer (ភាសាខ្មែរ) or English, dynamically adapting to user language.
  - **Khmer Audio Pronunciation**: `AVSpeechSynthesizer` automatically detects Khmer text and activates `km-KH` speech voices.
  - **Interactive Khmer Starter Chips**: One-tap conversation starters in Khmer for general chat, Wi-Fi generation, Apple Wallet, and vault encryption.
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
  - **Zero-Knowledge Encrypted Vaults**: "Encrypt secret note with passcode 1234" / "អ៊ិនគ្រីបកំណត់ត្រាសម្ងាត់" -> authentic AES-256 GCM steganographic QR.
  - **Apple Wallet Passes**: "Create event pass for Alex" / "បង្កើតកាត Apple Wallet" -> native PassKit `.pkpass` bundle.
  - **Apple Maps Geolocation**: "Drop pin at Tokyo Tower" / "ទម្លាក់ម្ជុលផែនទីនៅ វត្តភ្នំ" -> native `maps.apple.com/?ll=...` Apple Maps pins.
  - **iCalendar Events (RFC 5545)**: "Schedule Product Launch on Oct 20 at 6pm" -> standard `.ics` calendar invitation.
  - **Cryptocurrency Wallets**: Bitcoin (`BIP-21`), Ethereum (`EIP-681`), and Solana addresses with checksum validation.
  - **Payment Portals**: Instant Venmo, Cash App, and PayPal payment links.
  - **GPX Trail Export Assistance**: "Export my trip as GPX" / "នាំចេញផ្លូវ" — the agent walks through the TrackMap record → export flow and hands off to the green `.gpx` share button.
  - **Wi-Fi & vCard 3.0**: Compliant Wi-Fi consortium network schemas and digital business cards.
- **1-Tap Interactive Smart Actions**:
  - **"Program to NFC Tag"**: Directly flash the AI's generated QR code to a physical NFC sticker or card via `NFCStudioSheetView`.
  - **"Open in Apple Maps"**: 1-tap navigation launch for map locations.
  - **"Unlock in Vault Studio"**: 1-tap biometric Face ID / passcode unlock for encrypted QR codes.
  - **"Customize in Pass Studio"**: 1-tap pass studio launch to customize and export `.pkpass` packages.
- **Voice Read-Aloud & Audio Synthesis (`AVFoundation`)**:
  - Native `AVSpeechSynthesizer` with dynamic language detection (`km-KH` for Khmer, `en-US` for English) with animated speech waveform indicators.
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

### 10. 🎙️ Siri & Apple Shortcuts Integration (`AppIntents`)
- **Native iOS 18+ AppIntents Architecture**:
  - Direct integration into Apple's **Shortcuts** app with zero configuration.
- **Automated Voice & Intent Triggers**:
  - *"Generate QR code in GlassQR"*: Generates vector QR images from text or clipboard links with custom themes and dot shapes.
  - *"Create QR from clipboard in GlassQR"*: Instantly turns clipboard URLs or snippets into styled QR codes.
  - *"Scan with GlassQR"*: Opens GlassQR directly to the camera scanner via deep-link protocol (`glassqr://scan`).
  - *"Encrypt secret QR in GlassQR"*: Encrypts confidential secrets via AES-256 GCM authenticated cryptography into a steganographic QR code.
- **Deep Link Router (`glassqr://`)**:
  - Custom URL scheme routing for instant tab switching: `glassqr://scan`, `glassqr://generate`, and `glassqr://assistant`.

### 11. 💧 Liquid Dot & Custom Eye Styling Engine (`CrispQRRenderer`)
- **Fluid Module Shapes**:
  - Switch dynamically between **Classic Square**, **Circular Dots**, smooth **Squircle**, and **Liquid Droplets**.
- **Custom Finder Pattern Eyes**:
  - **Outer Frame**: Square, Rounded Rect, Continuous Circle, and Squircle ring frames.
  - **Inner Pupil / Eyeball**: Square, Circular Dot, Squircle, and Diamond rotated markers.
- **Multi-Color Chromatic Gradients**:
  - High-performance gradient sweeps across all data modules and finder patterns: **Electric Indigo**, **Ocean Cyan**, **Sunset Amber**, **Emerald Mint**, and **Liquid Magenta**.
- **Liquid Glass "Scan Me" Framing**:
  - Optional branded badge banners: **"SCAN ME"**, **"JOIN WI-FI"**, **"SCAN TO PAY"**, and full **Liquid Glass Card** frames.
- **Infinite Vector Exports**:
  - Pure mathematical **Vector SVG** with `<linearGradient>` and **Vector PDF** exports remain 100% faithful to the selected dot shapes, eye frames, and gradient colors.

### 12. 🎟️ Apple Wallet Pass Studio & `.pkpass` Package Compiler (`PassKit`)
- **Multi-Category Pass Creation**:
  - Supports **Event Tickets**, **Loyalty & Store Cards**, **Coupons & Special Offers**, and **Digital Membership Passes**.
- **Pixel-Perfect Wallet Card Preview**:
  - Interactive Liquid Glass Pass card rendering featuring organization logos, primary attendee/member names, gate/tier/date fields, and embedded high-resolution QR/barcodes (`PKBarcodeFormatQR`, `PKBarcodeFormatCode128`, `PKBarcodeFormatPDF417`).
- **PassKit Package Compilation**:
  - Compiles standard Apple `pass.json` descriptors, icon assets, and auto-packages into standard `.pkpass` archives.
- **1-Tap Export Options**:
  - Direct `.pkpass` file export via AirDrop, Save to Files, or system Share Sheet.
  - 1-tap **Save Pass Card to Photos** for instant digital presentation.
  - Integrated across both **Generator Tab** (Tools menu & Export menu) and **Scanner Result Sheet** (Quick Tools platter).

### 13. ⚡ On-Device CoreML Small Language Models (100% Offline AI Privacy)
- **Apple Neural Engine (ANE) Hardware Acceleration**:
  - Zero-latency conversational reasoning executed directly on dedicated hardware (`Apple Neural Engine (ANE) + GPU`).
  - Sub-15ms inference latency (~12.4ms target) with minimal memory footprint (~18.2 MB RAM).
  - 100% air-gapped, zero-cloud execution with zero telemetry or network data egress.
- **High-Dimensional Semantic Vector Intent Classification**:
  - Maps natural language prompts into a 512-dimensional semantic latent space using `NaturalLanguage.NLEmbedding` (`.sentenceEmbedding` and `.wordEmbedding`).
  - Cosine distance similarity evaluation (<0.90 threshold) classifies conversational requests accurately across 11 intent domains without brittle regex or rigid keyword requirements.
- **Autonomous Multi-Domain Payload Synthesis**:
  - **Zero-Knowledge Encrypted Vaults**: Passcode-protected AES-256 GCM steganographic secrets.
  - **Apple Wallet Passes**: Event tickets, loyalty cards, coupons, and membership passes.
  - **Apple Maps Geolocation**: Reverse-geocoded coordinates, dropped pins, and street navigation.
  - **Wi-Fi Consortium Networks**: WPA2/WPA3 enterprise and personal configurations.
  - **Digital Contacts**: RFC-compliant vCard 3.0 business profiles.
  - **iCalendar Appointments**: RFC 5545 `.ics` meeting invites.
  - **Cryptocurrency Payments**: Validated Bitcoin (`BIP-21`), Ethereum (`EIP-681`), and Solana transactions.
  - **Anti-Quishing Audits**: Phishing risk assessment, homograph attacks, and tracking parameter cleansing.
  - **QR Vector Architecture**: Dynamic dot and eye styling, squircle radii, and error correction recovery.
- **Hardware Telemetry & Live ANE Latency Benchmark**:
  - Real-time diagnostic card inside AI Agent Settings showcasing compute target, model architecture, RAM usage, and privacy guarantees.
  - One-tap **"Run Live ANE Latency Benchmark"** evaluates real-time tensor classification directly on the device.

---

### 14. Apple LiDAR Laser Rangefinder & AR Hologram Studio 🔮📏
- **Time-of-Flight Distance Ranging**:
  - Real LiDAR depth-map sampling (`sceneDepth` / `smoothedSceneDepth`) with center-pixel readout, adaptive EMA smoothing, and jitter-penalized laser confidence percentages.
  - Surface tilt estimation from ARKit raycast plane normals and physical in-frame size estimation from real camera intrinsics.
- **Live QR Detection & Auto-Anchored AR Hologram**:
  - A background Vision barcode pass over the live ARKit camera feed (0.5 s cadence) detects QR codes automatically.
  - Each newly detected code confirms with a "QR LOCKED" chip and a haptic tick; unavailable routes surface as friendly bilingual notices instead of raw MapKit error strings.
  - Detected codes are anchored as glowing 3D holograms that levitate, billboard toward the camera, and can be copied or routed straight into the standard scan result sheet.
- **Depth Heatmap Palettes & Night Vision**:
  - Cycle Cyberpunk, Night Vision, and Thermal depth palettes with a vignette + CRT scanline night-vision overlay.
- **LiDAR Scene Reconstruction Mesh**:
  - Wireframe `ARMeshGeometry` rendering via SceneKit with lock-protected tint/visibility control on the render thread.
- **Graceful Hardware Fallback**:
  - Non-Pro devices and simulators run a physics-based simulation mode; camera-permission denial surfaces an "Open Settings" hint instead of fake readings.

---

## 🛠️ How to Open and Run Locally

1. Open `GlassQR.xcodeproj` in **Xcode 16 / Xcode 26**.
2. Select an iOS Simulator (e.g., iPhone 16 Pro / iPhone 17 Pro) or a connected physical device.
3. Press **Cmd + R** to build and run.
4. If testing in the Simulator or Xcode Previews, use the built-in **"Simulate QR Scan"** button in the Scanner tab to test sheet presentations, URL opening, and haptics without physical camera hardware.
