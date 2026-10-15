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
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .overlay(Circle().stroke(Color.white.opacity(0.24), lineWidth: 0.75))
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: hapticCount)
        .help("Replay Liquid Glass Welcome Screen")
    }
}
