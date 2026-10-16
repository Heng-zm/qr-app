//
//  LiDARScannerView.swift
//  GlassQR
//
//  Next-Gen Liquid Glass LiDAR 3D Laser Rangefinder, Night Depth Scanner & AR Hologram Studio.
//  Uses Apple LiDAR Time-of-Flight hardware to measure millimeter-precision distance,
//  surface orientation angles, 0% light night vision depth heatmaps, and anchor 3D AR Holograms.
//

import SwiftUI
import ARKit
import SceneKit

public struct LiDARScannerView: View {
    @ObservedObject var manager = LiDARManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isKhmerLanguage: Bool = false
    @State private var showHologramCard: Bool = false
    @State private var toastMessage: String? = nil
    @State private var pulseScale: CGFloat = 1.0

    let onCodeScanned: ((String, String) -> Void)?

    public init(onCodeScanned: ((String, String) -> Void)? = nil) {
        self.onCodeScanned = onCodeScanned
    }

    public var body: some View {
        ZStack {
            // 1. Live ARKit / LiDAR Viewport Layer
            LiDARARViewRepresentable(manager: manager)
                .ignoresSafeArea()

            // 2. Night Vision Thermal / Infrared Phosphor Overlay
            if manager.isNightVisionActive {
                nightVisionPhosphorOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            // 3. Central Tactical Laser Rangefinder Crosshair Reticle
            tacticalLaserReticle
                .allowsHitTesting(false)

            // 4. Top Telemetry Floating Command Bar
            VStack(spacing: 8) {
                topCommandBar
                    .padding(.top, 14)
                    .padding(.horizontal, 16)

                Spacer()

                // 3D Floating AR Hologram Card
                if manager.lastDetectedCode != nil {
                    floatingHologramCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Bottom Laser Rangefinder Telemetry Platter
                bottomTelemetryPlatter
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }

            // Toast Alert Pill
            if let toast = toastMessage {
                VStack {
                    Spacer().frame(height: 90)
                    Text(toast)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.8), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
            }
        }
        .onAppear {
            manager.startSession()
        }
        .onDisappear {
            manager.stopSession()
        }
    }

    // MARK: - Top Command Bar

    private var topCommandBar: some View {
        HStack(spacing: 10) {
            // Dismiss Button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }

            // Hardware LiDAR Status Pill
            HStack(spacing: 6) {
                Circle()
                    .fill(manager.isHardwareLiDAR ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                    .shadow(color: (manager.isHardwareLiDAR ? Color.green : Color.orange).opacity(0.8), radius: 6)

                Text(manager.isHardwareLiDAR ? "LiDAR HARDWARE" : "LiDAR SIMULATOR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))

            Spacer()

            // Night Vision Toggle (0% Light Infrared Mode)
            Button {
                manager.toggleNightVision()
                triggerToast(manager.isNightVisionActive ? (isKhmerLanguage ? "បើកមុខងារមើលពេលយប់ 0% ពន្លឺ" : "Night Vision ON (0% Light)") : (isKhmerLanguage ? "បិទមុខងារមើលពេលយប់" : "Night Vision OFF"))
            } label: {
                Image(systemName: manager.isNightVisionActive ? "moon.stars.fill" : "moon.stars")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(manager.isNightVisionActive ? Color.green : Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(manager.isNightVisionActive ? Color.green.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1))
            }

            // Depth Color Palette Cycler
            Button {
                manager.cycleDepthPalette()
                triggerToast("Palette: \(manager.depthHeatmapMode.rawValue)")
            } label: {
                Image(systemName: "paintpalette.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(manager.depthHeatmapMode.tintColor)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(manager.depthHeatmapMode.tintColor.opacity(0.5), lineWidth: 1))
            }

            // Language Switcher (🇰🇭 / 🇺🇸)
            Button {
                withAnimation {
                    isKhmerLanguage.toggle()
                }
            } label: {
                Text(isKhmerLanguage ? "🇰🇭" : "🇺🇸")
                    .font(.system(size: 15))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
        }
    }

    // MARK: - Tactical Laser Rangefinder Reticle

    private var tacticalLaserReticle: some View {
        ZStack {
            // Rotating Laser Target Ring
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [
                            manager.targetZoneColor(),
                            manager.targetZoneColor().opacity(0.2),
                            manager.targetZoneColor()
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(pulseScale * 360))
                .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: pulseScale)

            // Center Precision Crosshair & Dot
            ZStack {
                Rectangle()
                    .fill(manager.targetZoneColor())
                    .frame(width: 1, height: 20)
                Rectangle()
                    .fill(manager.targetZoneColor())
                    .frame(width: 20, height: 1)
                Circle()
                    .fill(manager.targetZoneColor())
                    .frame(width: 6, height: 6)
                    .shadow(color: manager.targetZoneColor(), radius: 6)
            }

            // Corner Brackets
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                Path { path in
                    path.move(to: CGPoint(x: -110, y: -90))
                    path.addLine(to: CGPoint(x: -110, y: -110))
                    path.addLine(to: CGPoint(x: -90, y: -110))
                }
                .stroke(manager.targetZoneColor(), lineWidth: 2.5)
                .rotationEffect(.degrees(Double(angle)))
            }

            // Real-Time Distance HUD Badge above reticle
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .black))
                    Text(manager.formattedDistance(isKhmer: isKhmerLanguage))
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(manager.targetZoneColor())
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.75), in: Capsule())
                .overlay(Capsule().stroke(manager.targetZoneColor().opacity(0.6), lineWidth: 1))
                .shadow(color: manager.targetZoneColor().opacity(0.4), radius: 8)

                Text(isKhmerLanguage ? "ចម្ងាយពិត LiDAR" : "LiDAR TOF RANGE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .offset(y: -140)
        }
        .onAppear {
            pulseScale = 2.0
        }
    }

    // MARK: - Night Vision Phosphor Green Overlay

    private var nightVisionPhosphorOverlay: some View {
        ZStack {
            Color.green.opacity(0.14)
                .blendMode(.screen)

            // Scanning line scanlines effect
            VStack(spacing: 4) {
                ForEach(0..<100, id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 1)
                    Spacer()
                }
            }
        }
    }

    // MARK: - 3D Holographic Card

    private var floatingHologramCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles.square.filled.on.square")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(isKhmerLanguage ? "កូដ QR 3D Hologram" : "3D Holographic QR Detected")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)

                    Text(manager.lastDetectedCode ?? "")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }

                Spacer()

                // Copy Action
                Button {
                    if let code = manager.lastDetectedCode {
                        UIPasteboard.general.string = code
                        triggerToast(isKhmerLanguage ? "បានចម្លងទៅ Clipboard" : "Copied to Clipboard")
                    }
                } label: {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.15), in: Circle())
                }

                // Dismiss Hologram
                Button {
                    manager.clearHologram()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.1), in: Circle())
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.06, green: 0.08, blue: 0.12).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: Color.cyan.opacity(0.35), radius: 14, x: 0, y: 4)
        )
    }

    // MARK: - Bottom Telemetry Platter

    private var bottomTelemetryPlatter: some View {
        VStack(spacing: 10) {
            // Primary Metrics Row
            HStack(spacing: 12) {
                // Surface Tilt Indicator
                telemetryCard(
                    title: isKhmerLanguage ? "មុំផ្ទៃ" : "SURFACE TILT",
                    value: String(format: "%.0f°", manager.surfaceTiltDegrees),
                    subtext: manager.surfaceTiltDegrees < 15 ? (isKhmerLanguage ? "កាត់កែងល្អ" : "Flat / Ortho") : (isKhmerLanguage ? "ផ្អៀងខ្លាំង" : "Oblique"),
                    icon: "angle",
                    tint: manager.surfaceTiltDegrees < 20 ? Color.green : Color.orange
                )

                // Laser Lock Confidence
                telemetryCard(
                    title: isKhmerLanguage ? "ទំនុកចិត្តឡាស៊ែរ" : "LASER LOCK",
                    value: String(format: "%.1f%%", manager.laserConfidencePercent),
                    subtext: manager.isTargetLocked ? (isKhmerLanguage ? "ជាប់គោលដៅ" : "Locked") : (isKhmerLanguage ? "កំពុងរាវរក" : "Searching"),
                    icon: "target",
                    tint: Color.cyan
                )

                // Target Physical Size Estimation
                telemetryCard(
                    title: isKhmerLanguage ? "ទំហំពិត QR" : "TARGET SIZE",
                    value: String(format: "%.0fcm", manager.estimatedPhysicalWidthCm),
                    subtext: String(format: "%.0f×%.0fcm", manager.estimatedPhysicalWidthCm, manager.estimatedPhysicalHeightCm),
                    icon: "ruler",
                    tint: Color.purple
                )
            }

            // Secondary Info Bar: Point Cloud & Demo QR Trigger
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.cyan)
                    Text("\(manager.pointCloudDensity) \(isKhmerLanguage ? "ចំណុច 3D" : "Depth Points")")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                // Test AR Hologram button (helpful for testing on any device)
                Button {
                    let testPayload = "https://glassqr.apple.com/lidar/demo"
                    manager.anchorHologram(code: testPayload, symbology: "QR Code")
                    onCodeScanned?(testPayload, "LiDAR Hologram")
                    triggerToast(isKhmerLanguage ? "បានបាញ់ Hologram 3D លើ QR" : "Projected 3D AR Hologram!")
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "cube.transparent")
                        Text(isKhmerLanguage ? "សាកល្បង 3D" : "Test Hologram")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 0.8))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 6)
        )
    }

    private func telemetryCard(title: String, value: String, subtext: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)

            Text(subtext)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(tint)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private func triggerToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            withAnimation {
                if self.toastMessage == text {
                    self.toastMessage = nil
                }
            }
        }
    }
}

// MARK: - ARKit LiDAR View Representable

public struct LiDARARViewRepresentable: UIViewRepresentable {
    @ObservedObject var manager: LiDARManager

    public func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    public func makeUIView(context: Context) -> ARSCNView {
        let scnView = ARSCNView()
        scnView.session = manager.arSession
        scnView.delegate = context.coordinator
        scnView.autoenablesDefaultLighting = true
        scnView.automaticallyUpdatesLighting = true
        scnView.antialiasingMode = .multisampling4X
        context.coordinator.scnView = scnView
        return scnView
    }

    public func updateUIView(_ scnView: ARSCNView, context: Context) {
        context.coordinator.updateHologramNode()
    }

    public final class Coordinator: NSObject, ARSCNViewDelegate {
        var manager: LiDARManager
        weak var scnView: ARSCNView?
        private var hologramNode: SCNNode?

        init(manager: LiDARManager) {
            self.manager = manager
        }

        func updateHologramNode() {
            guard let scnView = scnView else { return }

            if let pos = manager.arHologramPosition {
                if hologramNode == nil {
                    let node = createHologramNode()
                    node.position = SCNVector3(pos.x, pos.y, pos.z)
                    scnView.scene.rootNode.addChildNode(node)
                    self.hologramNode = node
                } else {
                    hologramNode?.position = SCNVector3(pos.x, pos.y, pos.z)
                }
            } else {
                hologramNode?.removeFromParentNode()
                hologramNode = nil
            }
        }

        private func createHologramNode() -> SCNNode {
            // Create a glowing 3D plane anchored in AR space
            let plane = SCNPlane(width: 0.16, height: 0.16)
            plane.cornerRadius = 0.02
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.systemCyan.withAlphaComponent(0.85)
            material.emission.contents = UIColor.cyan.withAlphaComponent(0.4)
            plane.materials = [material]

            let node = SCNNode(geometry: plane)
            // Gentle continuous levitation animation
            let moveUp = SCNAction.moveBy(x: 0, y: 0.015, z: 0, duration: 1.2)
            moveUp.timingMode = .easeInEaseOut
            let moveDown = moveUp.reversed()
            let sequence = SCNAction.sequence([moveUp, moveDown])
            node.runAction(SCNAction.repeatForever(sequence))

            return node
        }
    }
}
