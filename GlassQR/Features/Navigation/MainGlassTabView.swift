//
//  MainGlassTabView.swift
//  GlassQR
//

import SwiftUI

public struct MainGlassTabView: View {
    @Binding var hasCompletedOnboarding: Bool

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        TabView {
            Tab("Generate", systemImage: "qrcode") {
                NavigationStack {
                    GeneratorView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
            }

            Tab("Scan", systemImage: "qrcode.viewfinder") {
                NavigationStack {
                    ScannerView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
            }
        }
    }
}
