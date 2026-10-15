//
//  LiquidGlassSystem.swift
//  GlassQR
//
//  Native iOS 26 Liquid Glass Architecture & Interface Protocols
//

import SwiftUI

public struct GlassEffectStyle: Sendable, Equatable {
    public enum Variant: Sendable, Equatable {
        case regular
        case clear
    }

    public var variant: Variant
    public var isInteractive: Bool

    public static var regular: GlassEffectStyle {
        GlassEffectStyle(variant: .regular, isInteractive: false)
    }

    public static var clear: GlassEffectStyle {
        GlassEffectStyle(variant: .clear, isInteractive: false)
    }

    public func interactive(_ active: Bool = true) -> GlassEffectStyle {
        var copy = self
        copy.isInteractive = active
        return copy
    }
}

public enum GlassEffectTransition: Sendable, Equatable {
    case materialize
    case matchedGeometry
}

public struct GlassShapeToken: Sendable {
    public enum ShapeKind: Sendable, Equatable {
        case capsule
        case rect(cornerRadius: CGFloat)
    }
    public var kind: ShapeKind

    public static var capsule: GlassShapeToken {
        GlassShapeToken(kind: .capsule)
    }

    public static func rect(cornerRadius: CGFloat) -> GlassShapeToken {
        GlassShapeToken(kind: .rect(cornerRadius: cornerRadius))
    }
}

public extension View {
    /// Native iOS 26 `.glassEffect()` modifier
    func glassEffect(
        _ style: GlassEffectStyle = .regular,
        in shape: GlassShapeToken = .capsule
    ) -> some View {
        modifier(NativeLiquidGlassModifier(style: style, shape: shape))
    }

    /// Native iOS 26 geometry matching for liquid droplet morphing
    func glassEffectID(_ id: AnyHashable, in namespace: Namespace.ID) -> some View {
        self.matchedGeometryEffect(id: id, in: namespace)
    }

    /// Native iOS 26 liquid appearance transition
    @ViewBuilder
    func glassEffectTransition(_ transition: GlassEffectTransition) -> some View {
        switch transition {
        case .materialize:
            self.transition(
                .asymmetric(
                    insertion: .scale(scale: 0.94).combined(with: .opacity),
                    removal: .scale(scale: 0.88).combined(with: .opacity)
                )
            )
        case .matchedGeometry:
            self.transition(.identity)
        }
    }
}

/// Liquid Morphing Glass Effect Container
public struct GlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    public let content: Content

    public init(spacing: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}

/// Native Liquid Glass Button Styles
public struct GlassButtonStyle: ButtonStyle {
    public let isProminent: Bool

    public init(isProminent: Bool = false) {
        self.isProminent = isProminent
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .semibold))
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .background {
                if isProminent {
                    Capsule()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.82 : 0.96))
                        .shadow(color: Color.white.opacity(0.35), radius: 14, x: 0, y: 0)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.14))
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == GlassButtonStyle {
    static var glass: GlassButtonStyle { GlassButtonStyle(isProminent: false) }
    static var glassProminent: GlassButtonStyle { GlassButtonStyle(isProminent: true) }
}

/// Clean native rendering engine for Liquid Glass surfaces
private struct NativeLiquidGlassModifier: ViewModifier {
    let style: GlassEffectStyle
    let shape: GlassShapeToken
    @State private var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                glassBackdrop
            }
            .clipShape(shapeView)
            .scaleEffect(style.isInteractive && isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: isPressed)
            .simultaneousGesture(
                style.isInteractive ?
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
                : nil
            )
    }

    @ViewBuilder
    private var glassBackdrop: some View {
        switch style.variant {
        case .regular:
            shapeView
                .fill(Color.white.opacity(0.12))
                .shadow(color: Color.black.opacity(0.24), radius: 18, x: 0, y: 8)
                .shadow(color: Color.white.opacity(0.09), radius: 1, x: 0, y: -1)
        case .clear:
            shapeView
                .fill(Color.white.opacity(0.04))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 4)
        }
    }

    private var shapeView: AnyShape {
        switch shape.kind {
        case .capsule:
            return AnyShape(Capsule())
        case .rect(let radius):
            return AnyShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        }
    }
}
