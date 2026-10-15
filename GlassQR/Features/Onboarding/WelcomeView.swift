//
//  WelcomeView.swift
//  GlassQR
//

import SwiftUI

public struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @Namespace private var welcomeNamespace
    @State private var cardsAppeared: Bool = false
    @State private var emblemBounce: Int = 0
    @State private var buttonHapticTrigger: Int = 0

    private let features: [FeatureHighlight] = [
        FeatureHighlight(
            id: "vector",
            icon: "qrcode",
            title: "Instant Vector QR",
            subtitle: "Generate ultra-crisp vector QR codes in real time as you type."
        ),
        FeatureHighlight(
            id: "viewfinder",
            icon: "qrcode.viewfinder",
            title: "Live Glass Viewfinder",
            subtitle: "Hardware-accelerated live recognition with native Liquid Glass lensing."
        ),
        FeatureHighlight(
            id: "liquidShare",
            icon: "square.and.arrow.up.fill",
            title: "One-Tap Liquid Share",
            subtitle: "Fluidly export and share high-res codes with native glass sheets."
        )
    ]

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 20)

            // Floating Hero Emblem
            VStack(spacing: 16) {
                ZStack {
                    Image(systemName: "qrcode")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.cyan, .white, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.breathe, options: .repeating)
                        .symbolEffect(.bounce, value: emblemBounce)
                }
                .frame(width: 110, height: 110)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 36))
                .onTapGesture {
                    emblemBounce += 1
                }

                VStack(spacing: 6) {
                    Text("GlassQR")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("The Future of Optical Data Interaction")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.top, 16)

            // Staggered Liquid Glass Feature Cards
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 14) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        FeatureCardView(feature: feature)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                            .offset(y: cardsAppeared ? 0 : 40)
                            .opacity(cardsAppeared ? 1 : 0)
                            .animation(
                                .spring(response: 0.55, dampingFraction: 0.76).delay(Double(index) * 0.12),
                                value: cardsAppeared
                            )
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            // Morphing Bottom Call-to-Action Bar
            GlassEffectContainer(spacing: 16) {
                Button {
                    buttonHapticTrigger += 1
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .symbolEffect(.bounce, value: buttonHapticTrigger)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                .glassEffectID("welcomeCTA", in: welcomeNamespace)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: buttonHapticTrigger)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: emblemBounce)
        .onAppear {
            cardsAppeared = true
        }
    }
}
