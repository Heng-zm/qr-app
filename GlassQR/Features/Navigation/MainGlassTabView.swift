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
        case trackmap = "TrackMap"
        case assistant = "AI Agent"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .generator: return "qrcode"
            case .scanner: return "qrcode.viewfinder"
            case .trackmap: return "location.north.circle.fill"
            case .assistant: return "sparkles"
            }
        }
    }

    @State private var selectedTab: TabItem = .generator
    @State private var isKeyboardVisible: Bool = false
    @Namespace private var bottomNavNamespace

    public init(hasCompletedOnboarding: Binding<Bool>) {
        self._hasCompletedOnboarding = hasCompletedOnboarding
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area with state preservation across tabs
            ZStack {
                NavigationStack {
                    GeneratorView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
                .opacity(selectedTab == .generator ? 1 : 0)
                .allowsHitTesting(selectedTab == .generator)

                NavigationStack {
                    ScannerView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
                .opacity(selectedTab == .scanner ? 1 : 0)
                .allowsHitTesting(selectedTab == .scanner)

                NavigationStack {
                    TrackMapView()
                }
                .opacity(selectedTab == .trackmap ? 1 : 0)
                .allowsHitTesting(selectedTab == .trackmap)

                NavigationStack {
                    AIAssistantView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
                .opacity(selectedTab == .assistant ? 1 : 0)
                .allowsHitTesting(selectedTab == .assistant)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Native iOS 26 Liquid Glass Floating Bottom Navigation Bar (hides while keyboard is active)
            if !isKeyboardVisible {
                GlassEffectContainer(spacing: 12) {
                    liquidGlassBottomNavBar
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                isKeyboardVisible = false
            }
        }
        .onOpenURL { url in
            guard url.scheme == "glassqr" else { return }
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
                switch url.host {
                case "scan":
                    selectedTab = .scanner
                case "generate":
                    selectedTab = .generator
                case "track", "trackmap", "map":
                    selectedTab = .trackmap
                case "assistant", "ai":
                    selectedTab = .assistant
                default:
                    break
                }
            }
        }
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
            HStack(spacing: 5) {
                Image(systemName: tab.icon)
                    .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                    .symbolEffect(.bounce, value: selectedTab == tab)

                Text(tab.rawValue)
                    .font(.system(size: 11, weight: selectedTab == tab ? .bold : .semibold, design: .rounded))
                    .lineLimit(1)
            }
            .frame(minWidth: 54, maxWidth: .infinity)
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
