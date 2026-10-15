//
//  ReplayOnboardingButton.swift
//  GlassQR
//

import SwiftUI

public struct ReplayOnboardingButton: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var hapticCount: Int = 0

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        Button {
            hapticCount += 1
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                hasCompletedOnboarding = false
            }
        } label: {
            Label("Replay Welcome", systemImage: "sparkles")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.glass)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticCount)
        .help("Replay Liquid Glass Welcome Screen")
    }
}
