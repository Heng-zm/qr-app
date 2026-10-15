//
//  GlassQRApp.swift
//  GlassQR
//
//  Targeting iOS 26.0+ & Xcode 26
//  Native Liquid Glass Design System Architecture
//

import SwiftUI

@main
struct GlassQRApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            RootContentView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Xcode 26 Previews

#Preview("Main App - Liquid Glass") {
    RootContentView(hasCompletedOnboarding: .constant(true))
        .preferredColorScheme(.dark)
}

#Preview("Welcome & Onboarding") {
    RootContentView(hasCompletedOnboarding: .constant(false))
        .preferredColorScheme(.dark)
}
