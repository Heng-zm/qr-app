//
//  RootContentView.swift
//  GlassQR
//

import SwiftUI

public struct RootContentView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var rootTransitionNamespace

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack {
            // Persistent fluid background layer refracting through all Liquid Glass platters
            LiquidMeshGradientView()
                .ignoresSafeArea()

            if !hasCompletedOnboarding {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .glassEffectTransition(.materialize)
            } else {
                MainGlassTabView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .glassEffectTransition(.materialize)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.78), value: hasCompletedOnboarding)
    }
}
