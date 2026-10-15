//
//  MainGlassTabView.swift
//  GlassQR
//
//  Native iOS 26 Liquid Glass Floating Bottom Navigation Bar
//

import SwiftUI

public struct MainGlassTabView: View {
    @Binding var hasCompletedOnboarding: Bool

    public enum TabItem: String, CaseIterable, Identifiable {
        case generator = "Generate"
        case scanner = "Scan"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .generator: return "qrcode"
            case .scanner: return "qrcode.viewfinder"
            }
        }
    }

    @State private var selectedTab: TabItem = .generator
    @Namespace private var bottomNavNamespace

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Persistent Tab View Hierarchy (prevents camera resets and state churn)
            ZStack {
                NavigationStack {
                    GeneratorView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
                .opacity(selectedTab == .generator ? 1 : 0)
                .allowsHitTesting(selectedTab == .generator)
                .accessibilityHidden(selectedTab != .generator)

                NavigationStack {
                    ScannerView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                            }
                        }
                }
                .opacity(selectedTab == .scanner ? 1 : 0)
                .allowsHitTesting(selectedTab == .scanner)
                .accessibilityHidden(selectedTab != .scanner)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.22), value: selectedTab)

            // Native iOS 26 Liquid Glass Floating Bottom Navigation Bar
            GlassEffectContainer(spacing: 12) {
                liquidGlassBottomNavBar
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Native iOS 26 Liquid Glass Bottom Nav

    private var liquidGlassBottomNavBar: some View {
        HStack(spacing: 6) {
            ForEach(TabItem.allCases) { tab in
                tabButton(for: tab)
            }
        }
        .padding(6)
        .glassEffect(.regular, in: .capsule)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    private func tabButton(for tab: TabItem) -> some View {
        Button {
            if selectedTab != tab {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                    selectedTab = tab
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: selectedTab == tab ? .bold : .medium))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: selectedTab == tab ? .bold : .semibold, design: .rounded))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .foregroundStyle(
                selectedTab == tab
                    ? Color(red: 0.05, green: 0.05, blue: 0.08)
                    : Color.white.opacity(0.72)
            )
            .background {
                if selectedTab == tab {
                    activeTabDropletIndicator
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(LiquidGlassTabButtonStyle())
        .accessibilityLabel(tab.rawValue)
        .accessibilityAddTraits(selectedTab == tab ? [.isSelected] : [])
    }

    // MARK: - Refractive Droplet Indicator

    private var activeTabDropletIndicator: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.98),
                        Color.white.opacity(0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.white.opacity(0.40), radius: 10, x: 0, y: 2)
            .shadow(color: Color.cyan.opacity(0.25), radius: 14, x: 0, y: 0)
            .glassEffectID("selectedTabMorphPill", in: bottomNavNamespace)
    }
}

// MARK: - Interactive Tactile Button Physics

private struct LiquidGlassTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Xcode Previews

#Preview("Main Glass Tab View - iOS 26") {
    ZStack {
        LiquidMeshGradientView()
            .ignoresSafeArea()
        MainGlassTabView(hasCompletedOnboarding: .constant(true))
    }
    .preferredColorScheme(.dark)
}
