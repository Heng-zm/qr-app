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
    │   └── ScanResultItem.swift             # Model for decoded QR payload & URL detection
    │
    ├── Core/
    │   ├── DesignSystem/
    │   │   └── LiquidGlassSystem.swift      # Native iOS 26 Liquid Glass modifiers & button styles
    │   ├── Background/
    │   │   └── LiquidMeshGradientView.swift # Living animated MeshGradient background
    │   └── Components/
    │       └── ReplayOnboardingButton.swift # Toolbar quick-replay test component
    │
    ├── Features/
    │   ├── Onboarding/
    │   │   ├── WelcomeView.swift            # 3D squircle hero emblem & staggered cards
    │   │   └── FeatureCardView.swift        # Interactive refractive glass card
    │   │
    │   ├── Generator/
    │   │   ├── GeneratorView.swift          # Live input bar, morphing clear, crisp QR card
    │   │   └── CrispQRRenderer.swift        # CoreImage CIFilter vector rendering engine
    │   │
    │   ├── Scanner/
    │   │   ├── ScannerView.swift            # Main scanner screen with HUD & sheet
    │   │   ├── CameraEngineRepresentable.swift # AVCaptureSession & simulator fallback
    │   │   ├── ScannerReticleView.swift     # Viewfinder corner targeting brackets
    │   │   ├── ScanningLaserView.swift      # Glowing oscillating laser bar
    │   │   └── ScanResultSheetView.swift    # Medium-detent Liquid Glass result sheet
    │   │
    │   └── Navigation/
    │       ├── MainGlassTabView.swift       # Native TabView platter ("Generate" & "Scan")
    │       └── RootContentView.swift       # Root coordinator between Onboarding & TabView
    │
    └── Resources/
        ├── Info.plist                       # Camera permissions (NSCameraUsageDescription)
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
  - Thread-safe camera capture running on a dedicated serial background queue with tap-to-focus and optical zoom.
  - Automatic detection of simulator/preview environments with interactive bypass testing chips.

### 3. Living Liquid MeshGradient
- An oscillating `MeshGradient` powered by `TimelineView(.animation)` shifts through deep midnight indigo, electric violet, ocean cyan, and liquid magenta, creating a rich dynamic palette that refracts through every floating glass element in real time.

---

## 🛠️ How to Open and Run Locally

1. Open `GlassQR.xcodeproj` in **Xcode 16 / Xcode 26**.
2. Select an iOS Simulator (e.g., iPhone 16 Pro / iPhone 17 Pro) or a connected physical device.
3. Press **Cmd + R** to build and run.
4. If testing in the Simulator or Xcode Previews, use the built-in **"Simulate QR Scan"** button in the Scanner tab to test sheet presentations, URL opening, and haptics without physical camera hardware.
