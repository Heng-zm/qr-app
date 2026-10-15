//
//  LiquidGlassSystem.swift
//  GlassQR
//
//  Native iOS 26+ Liquid Glass adapters and interface helpers.
//
//  Prefer SwiftUI's native APIs in new code:
//    .glassEffect(.regular, in: Capsule())
//    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 20))
//    .buttonStyle(.glass)
//    .buttonStyle(.glassProminent)
//

import SwiftUI

/// Compatibility configuration for code that wants to choose between the
/// regular and clear native Liquid Glass materials.
///
/// The actual rendering is performed by SwiftUI's `Glass` and `View.glassEffect`.
public struct GlassEffectStyle: Sendable, Equatable {
    public enum Variant: Sendable, Equatable {
        case regular
        case clear
    }

    public var variant: Variant
    public var isInteractive: Bool

    public init(variant: Variant, isInteractive: Bool = false) {
        self.variant = variant
        self.isInteractive = isInteractive
    }

    public static var regular: GlassEffectStyle {
        GlassEffectStyle(variant: .regular)
    }

    public static var clear: GlassEffectStyle {
        GlassEffectStyle(variant: .clear)
    }

    /// Returns a copy configured to use the native interactive glass response.
    public func interactive(_ active: Bool = true) -> GlassEffectStyle {
        var copy = self
        copy.isInteractive = active
        return copy
    }
}

/// Use the native SwiftUI transition type while keeping the GlassQR name.
/// This is a typealias rather than a custom imitation, so `.materialize`,
/// `.matchedGeometry`, and `.identity` have their genuine iOS 26 behavior.
public typealias GlassEffectTransition = SwiftUI.GlassEffectTransition

/// Shape tokens retained for compatibility with existing GlassQR call sites.
public struct GlassShapeToken: Sendable, Equatable {
    public enum ShapeKind: Sendable, Equatable {
        case capsule
        case rect(cornerRadius: CGFloat)
    }

    public var kind: ShapeKind

    public init(kind: ShapeKind) {
        self.kind = kind
    }

    public static var capsule: GlassShapeToken {
        GlassShapeToken(kind: .capsule)
    }

    public static func rect(cornerRadius: CGFloat) -> GlassShapeToken {
        GlassShapeToken(kind: .rect(cornerRadius: cornerRadius))
    }
}

private extension GlassEffectStyle {
    var nativeGlass: SwiftUI.Glass {
        let glass: SwiftUI.Glass
        switch variant {
        case .regular:
            glass = .regular
        case .clear:
            glass = .clear
        }
        return glass.interactive(isInteractive)
    }
}

private extension GlassShapeToken {
    var nativeShape: AnyShape {
        switch kind {
        case .capsule:
            AnyShape(Capsule())
        case .rect(let cornerRadius):
            AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// Thin adapter that delegates rendering to SwiftUI's native Liquid Glass API.
private struct NativeLiquidGlassModifier: ViewModifier {
    let style: GlassEffectStyle
    let shape: GlassShapeToken

    func body(content: Content) -> some View {
        content.glassEffect(style.nativeGlass, in: shape.nativeShape)
    }
}

public extension View {
    /// Adapter for callers using GlassQR's custom style and shape tokens.
    ///
    /// This intentionally has a distinct name from SwiftUI's `.glassEffect`
    /// to avoid ambiguity with the genuine native API, whose parameters have
    /// the same labels and defaults.
    func liquidGlassEffect(
        _ style: GlassEffectStyle = .regular,
        in shape: GlassShapeToken = .capsule
    ) -> some View {
        modifier(NativeLiquidGlassModifier(style: style, shape: shape))
    }

    /// Source-compatibility overload for existing calls that pass both custom
    /// GlassQR tokens explicitly. New code should use SwiftUI's native API,
    /// e.g. `.glassEffect(.regular, in: Capsule())`, or `liquidGlassEffect`.
    @available(*, deprecated, message: "Use native .glassEffect(_:in:) with SwiftUI.Glass and a Shape, or use .liquidGlassEffect(_:in:) with GlassQR tokens.")
    func glassEffect(
        _ style: GlassEffectStyle,
        in shape: GlassShapeToken
    ) -> some View {
        modifier(NativeLiquidGlassModifier(style: style, shape: shape))
    }

    /// SwiftUI provides the native `.glassEffectID(_:in:)` and
    /// `.glassEffectTransition(_:)` modifiers on iOS 26+. Use those directly
    /// so SwiftUI can coordinate genuine glass morphing within a container.
}

/// Native Liquid Glass container with the original GlassQR horizontal layout.
/// The enclosed items must themselves apply `.glassEffect` (or
/// `.liquidGlassEffect`) to participate in glass blending and morphing.
public struct GlassEffectContainer<Content: View>: View {
    public let spacing: CGFloat
    public let content: Content

    public init(
        spacing: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        SwiftUI.GlassEffectContainer(spacing: spacing) {
            HStack(spacing: spacing) {
                content
            }
        }
    }
}

/// Backward-compatible custom ButtonStyle adapter.
///
/// For new buttons, prefer the genuine system styles directly:
/// `.buttonStyle(.glass)` or `.buttonStyle(.glassProminent)`. Those styles
/// provide platform-managed glass button behavior and are not simulated here.
@available(*, deprecated, message: "Prefer .buttonStyle(.glass) or .buttonStyle(.glassProminent) for the native iOS 26 button styles.")
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
            .foregroundStyle(isProminent ? Color.black : Color.primary)
            .glassEffect(
                SwiftUI.Glass.regular
                    .interactive(configuration.isPressed)
                    .tint(isProminent ? Color.white.opacity(0.88) : nil),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.7),
                value: configuration.isPressed
            )
    }
}
