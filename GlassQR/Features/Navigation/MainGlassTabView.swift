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
        case assistant = "AI Agent"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .generator: return "qrcode"
            case .scanner: return "qrcode.viewfinder"
            case .assistant: return "sparkles"
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
            // Main Content Area with smooth transitions
            Group {
                switch selectedTab {
                case .generator:
                    NavigationStack {
                        GeneratorView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                                }
                            }
                    }
                    .transition(.opacity)

                case .scanner:
                    NavigationStack {
                        ScannerView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                                }
                            }
                    }
                    .transition(.opacity)

                case .assistant:
                    NavigationStack {
                        AIAssistantView(hasCompletedOnboarding: $hasCompletedOnboarding)
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    ReplayOnboardingButton(hasCompletedOnboarding: $hasCompletedOnboarding)
                                }
                            }
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Native iOS 26 Liquid Glass Floating Bottom Navigation Bar
            GlassEffectContainer(spacing: 12) {
                liquidGlassBottomNavBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Native iOS 26 Liquid Glass Bottom Nav

    private var liquidGlassBottomNavBar: some View {
        HStack(spacing: 4) {
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
            HStack(spacing: 6) {
                Image(systemName: tab.icon)
                    .font(.system(size: 15, weight: selectedTab == tab ? .bold : .medium))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.rawValue)
                    .font(.system(size: 12, weight: selectedTab == tab ? .bold : .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(minWidth: 80, maxWidth: .infinity)
            .padding(.vertical, 10)
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
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.88)
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
                                Color.white.opacity(0.4)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.25), radius: 4, x: 0, y: 0)
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
