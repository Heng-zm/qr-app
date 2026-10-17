//
//  LiDARScannerView.swift
//  GlassQR
//
//  Liquid Glass LiDAR laser rangefinder, depth-mesh scanner & AR hologram studio.
//  Uses Apple LiDAR time-of-flight hardware for distance, surface orientation,
//  a depth-mesh overlay, and anchors a real QR hologram in AR space.
//
//  Requires NSCameraUsageDescription in Info.plist.
//

import SwiftUI
import ARKit
import SceneKit
import Combine

public struct LiDARScannerView: View {
    @ObservedObject var manager = LiDARManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isKhmerLanguage: Bool = false
    @State private var toastMessage: String? = nil
    @State private var ringRotation: Double = 0

    let onCodeScanned: ((String, String) -> Void)?

    public init(onCodeScanned: ((String, String) -> Void)? = nil) {
        self.onCodeScanned = onCodeScanned
    }

    public var body: some View {
        ZStack {
            // 1. Live ARKit / LiDAR viewport (does not observe the manager itself;
            //    the coordinator subscribes only to what it needs)
            LiDARARViewRepresentable(manager: manager)
                .ignoresSafeArea()

            // 2. Night-vision style overlay, tinted by the selected palette
            if manager.isNightVisionActive {
                nightVisionOverlay
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // 3. Laser reticle
            tacticalLaserReticle
                .allowsHitTesting(false)

            // 4. HUD
            VStack(spacing: 8) {
                topCommandBar
                    .padding(.top, 14)
                    .padding(.horizontal, 16)

                Spacer()

                if manager.lastDetectedCode != nil {
                    floatingHologramCard
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                bottomTelemetryPlatter
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }

            // Toast
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
                .allowsHitTesting(false)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.lastDetectedCode != nil)
        .onAppear {
            manager.startSession()
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
        .onDisappear {
            manager.stopSession()
            manager.clearHologram()
        }
    }

    // MARK: - Top Command Bar

    private var topCommandBar: some View {
        HStack(spacing: 10) {
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
            .accessibilityLabel(isKhmerLanguage ? "បិទ" : "Close")

            HStack(spacing: 6) {
                let statusColor: Color = manager.isHardwareLiDAR ? .green : .orange
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.8), radius: 6)

                Text(manager.isHardwareLiDAR ? "LiDAR HARDWARE" : "LiDAR SIMULATOR")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.65), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))

            Spacer(minLength: 0)

            // Night vision toggle
            Button {
                manager.toggleNightVision()
                triggerToast(manager.isNightVisionActive
                             ? (isKhmerLanguage ? "បើកមុខងារមើលពេលយប់" : "Night Vision ON")
                             : (isKhmerLanguage ? "បិទមុខងារមើលពេលយប់" : "Night Vision OFF"))
            } label: {
                Image(systemName: manager.isNightVisionActive ? "moon.stars.fill" : "moon.stars")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(manager.isNightVisionActive ? manager.depthHeatmapMode.tintColor : Color.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(manager.isNightVisionActive ? manager.depthHeatmapMode.tintColor.opacity(0.6) : Color.white.opacity(0.2), lineWidth: 1))
            }
            .accessibilityLabel(isKhmerLanguage ? "មើលពេលយប់" : "Night vision")

            // Depth palette cycler
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
            .accessibilityLabel(isKhmerLanguage ? "ពណ៌ជម្រៅ" : "Depth palette")

            // Language switcher
            Button {
                withAnimation { isKhmerLanguage.toggle() }
            } label: {
                Text(isKhmerLanguage ? "🇰🇭" : "🇺🇸")
                    .font(.system(size: 15))
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.55), in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            }
            .accessibilityLabel(isKhmerLanguage ? "ភាសា" : "Language")
        }
    }

    // MARK: - Laser Reticle

    private var tacticalLaserReticle: some View {
        let zone = manager.targetZoneColor()
        return ZStack {
            // Rotating ring
            Circle()
                .stroke(
                    AngularGradient(colors: [zone, zone.opacity(0.2), zone], center: .center),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
                .frame(width: 240, height: 240)
                .rotationEffect(.degrees(ringRotation))

            // Center crosshair
            ZStack {
                Rectangle().fill(zone).frame(width: 1, height: 20)
                Rectangle().fill(zone).frame(width: 20, height: 1)
                Circle().fill(zone).frame(width: 6, height: 6)
                    .shadow(color: zone, radius: 6)
            }

            // Corner brackets (each is a fixed-size shape rotated about the reticle center)
            ForEach([0, 90, 180, 270], id: \.self) { angle in
                CornerBracket(length: 20)
                    .stroke(zone, lineWidth: 2.5)
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(Double(angle)))
            }

            // Distance badge
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: "scope")
                        .font(.system(size: 11, weight: .black))
                    Text(manager.formattedDistance(isKhmer: isKhmerLanguage))
                        .font(.system(size: 15, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(zone)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.75), in: Capsule())
                .overlay(Capsule().stroke(zone.opacity(0.6), lineWidth: 1))
                .shadow(color: zone.opacity(0.4), radius: 8)

                Text(isKhmerLanguage ? "ចម្ងាយពិត LiDAR" : "LiDAR TOF RANGE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .offset(y: -140)
        }
    }

    // MARK: - Night Vision Overlay

    private var nightVisionOverlay: some View {
        let tint = manager.depthHeatmapMode.tintColor
        return ZStack {
            tint.opacity(0.14).blendMode(.screen)

            // Vignette
            RadialGradient(colors: [.clear, .black.opacity(0.55)],
                           center: .center, startRadius: 120, endRadius: 520)

            // Scanlines
            Canvas { ctx, size in
                var y: CGFloat = 0
                while y < size.height {
                    ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: 1)),
                             with: .color(.black.opacity(0.12)))
                    y += 4
                }
            }
        }
    }

    // MARK: - Hologram Card

    private var floatingHologramCard: some View {
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

            Spacer(minLength: 0)

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
            .accessibilityLabel(isKhmerLanguage ? "ចម្លង" : "Copy")

            Button {
                manager.clearHologram()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel(isKhmerLanguage ? "បិទ Hologram" : "Dismiss hologram")
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
        let isFlat = manager.surfaceTiltDegrees < 15
        return VStack(spacing: 10) {
            HStack(spacing: 12) {
                telemetryCard(
                    title: isKhmerLanguage ? "មុំផ្ទៃ" : "SURFACE TILT",
                    value: String(format: "%.0f°", manager.surfaceTiltDegrees),
                    subtext: isFlat ? (isKhmerLanguage ? "កាត់កែងល្អ" : "Flat / Ortho")
                                    : (isKhmerLanguage ? "ផ្អៀងខ្លាំង" : "Oblique"),
                    icon: "angle",
                    tint: isFlat ? .green : .orange
                )

                telemetryCard(
                    title: isKhmerLanguage ? "ទំនុកចិត្តឡាស៊ែរ" : "LASER LOCK",
                    value: String(format: "%.1f%%", manager.laserConfidencePercent),
                    subtext: manager.isTargetLocked ? (isKhmerLanguage ? "ជាប់គោលដៅ" : "Locked")
                                                    : (isKhmerLanguage ? "កំពុងរាវរក" : "Searching"),
                    icon: "target",
                    tint: .cyan
                )

                telemetryCard(
                    title: isKhmerLanguage ? "ទំហំប៉ាន់ស្មាន" : "EST. SIZE",
                    value: String(format: "%.0f cm", manager.estimatedPhysicalWidthCm),
                    subtext: isKhmerLanguage ? "ទទឹងក្នុងស៊ុម" : "frame width",
                    icon: "ruler",
                    tint: .purple
                )
            }

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

                Button {
                    let testPayload = "https://example.com/lidar/demo"
                    manager.anchorHologram(code: testPayload, symbology: "QR Code")
                    onCodeScanned?(testPayload, "QR Code")
                    triggerToast(isKhmerLanguage ? "បានបាញ់ Hologram 3D" : "Projected 3D AR Hologram!")
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(value)
                .font(.system(size: 16, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

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
                if toastMessage == text { toastMessage = nil }
            }
        }
    }
}

// MARK: - Corner Bracket Shape

private struct CornerBracket: Shape {
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))
        return p
    }
}

// MARK: - ARKit LiDAR View Representable

public struct LiDARARViewRepresentable: UIViewRepresentable {
    // Not @ObservedObject: observing would call updateUIView ~20x/second.
    // The coordinator subscribes to only the properties it needs.
    let manager: LiDARManager

    public func makeCoordinator() -> Coordinator {
        Coordinator(manager: manager)
    }

    public func makeUIView(context: Context) -> ARSCNView {
        let scnView = ARSCNView(frame: .zero)
        scnView.session = manager.arSession
        scnView.delegate = context.coordinator
        scnView.automaticallyUpdatesLighting = true
        scnView.antialiasingMode = .multisampling4X
        context.coordinator.attach(to: scnView)
        return scnView
    }

    public func updateUIView(_ scnView: ARSCNView, context: Context) {}

    public static func dismantleUIView(_ uiView: ARSCNView, coordinator: Coordinator) {
        uiView.delegate = nil
        coordinator.detach()
    }

    public final class Coordinator: NSObject, ARSCNViewDelegate {
        private let manager: LiDARManager
        private weak var scnView: ARSCNView?
        private var cancellables = Set<AnyCancellable>()

        // Hologram state (main thread only)
        private var hologramNode: SCNNode?
        private var lastHologramPosition: SIMD3<Float>?
        private var lastHologramCode: String?

        // Mesh state (read from the SceneKit render thread, so lock-protected)
        private let lock = NSLock()
        private var _meshTint: UIColor = .systemCyan
        private var _meshVisible = false

        init(manager: LiDARManager) {
            self.manager = manager
            super.init()
        }

        func attach(to view: ARSCNView) {
            scnView = view

            Publishers.CombineLatest(manager.$arHologramPosition, manager.$lastDetectedCode)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] position, code in
                    self?.updateHologram(position: position, code: code)
                }
                .store(in: &cancellables)

            manager.$depthHeatmapMode
                .receive(on: DispatchQueue.main)
                .sink { [weak self] mode in
                    self?.setMesh(tint: UIColor(mode.tintColor))
                }
                .store(in: &cancellables)

            manager.$isNightVisionActive
                .receive(on: DispatchQueue.main)
                .sink { [weak self] active in
                    self?.setMesh(visible: active)
                }
                .store(in: &cancellables)
        }

        func detach() {
            cancellables.removeAll()
            hologramNode?.removeFromParentNode()
            hologramNode = nil
        }

        // MARK: Depth mesh (LiDAR scene reconstruction)

        private var meshTint: UIColor { lock.lock(); defer { lock.unlock() }; return _meshTint }
        private var meshVisible: Bool { lock.lock(); defer { lock.unlock() }; return _meshVisible }

        private func setMesh(tint: UIColor? = nil, visible: Bool? = nil) {
            lock.lock()
            if let tint = tint { _meshTint = tint }
            if let visible = visible { _meshVisible = visible }
            let t = _meshTint, v = _meshVisible
            lock.unlock()

            scnView?.scene.rootNode
                .childNodes(passingTest: { node, _ in node.name == "lidarMesh" })
                .forEach { node in
                    node.isHidden = !v
                    node.geometry?.materials.forEach { $0.diffuse.contents = t.withAlphaComponent(0.7) }
                }
        }

        private func makeMeshMaterial() -> SCNMaterial {
            let m = SCNMaterial()
            m.fillMode = .lines
            m.lightingModel = .constant
            m.isDoubleSided = true
            m.diffuse.contents = meshTint.withAlphaComponent(0.7)
            return m
        }

        private func makeGeometry(from mesh: ARMeshGeometry) -> SCNGeometry {
            let v = mesh.vertices
            let vertexSource = SCNGeometrySource(buffer: v.buffer,
                                                 vertexFormat: v.format,
                                                 semantic: .vertex,
                                                 vertexCount: v.count,
                                                 dataOffset: v.offset,
                                                 dataStride: v.stride)
            let f = mesh.faces
            // Copy the index data: the Metal buffer is reused by ARKit between updates.
            let data = Data(bytes: f.buffer.contents(),
                            count: f.indexCountPerPrimitive * f.bytesPerIndex * f.count)
            let element = SCNGeometryElement(data: data,
                                             primitiveType: .triangles,
                                             primitiveCount: f.count,
                                             bytesPerIndex: f.bytesPerIndex)
            let geometry = SCNGeometry(sources: [vertexSource], elements: [element])
            geometry.materials = [makeMeshMaterial()]
            return geometry
        }

        public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return nil }
            let node = SCNNode(geometry: makeGeometry(from: meshAnchor.geometry))
            node.name = "lidarMesh"
            node.isHidden = !meshVisible
            return node
        }

        public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            node.geometry = makeGeometry(from: meshAnchor.geometry)
        }

        // MARK: Hologram

        private func updateHologram(position: SIMD3<Float>?, code: String?) {
            guard let scnView = scnView else { return }

            guard let position = position, let code = code else {
                hologramNode?.removeFromParentNode()
                hologramNode = nil
                lastHologramPosition = nil
                lastHologramCode = nil
                return
            }

            if hologramNode == nil {
                let node = makeHologramNode(code: code)
                node.position = SCNVector3(position.x, position.y, position.z)
                scnView.scene.rootNode.addChildNode(node)
                hologramNode = node
                lastHologramPosition = position
                lastHologramCode = code
                return
            }

            // Only touch what changed so the levitation animation isn't reset.
            if code != lastHologramCode, let plane = hologramNode?.childNode(withName: "qrPlane", recursively: true)?.geometry {
                plane.firstMaterial?.diffuse.contents = qrImage(for: code)
                lastHologramCode = code
            }
            if position != lastHologramPosition {
                hologramNode?.position = SCNVector3(position.x, position.y, position.z)
                lastHologramPosition = position
            }
        }

        private func makeHologramNode(code: String) -> SCNNode {
            let container = SCNNode()

            // Always face the camera (rotate around Y only so it stays upright)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .Y
            container.constraints = [billboard]

            // Glowing backing plate
            let glow = SCNPlane(width: 0.19, height: 0.19)
            glow.cornerRadius = 0.02
            let glowMat = SCNMaterial()
            glowMat.lightingModel = .constant
            glowMat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.35)
            glowMat.isDoubleSided = true
            glow.materials = [glowMat]
            let glowNode = SCNNode(geometry: glow)
            glowNode.position = SCNVector3(0, 0, -0.002)

            // Actual QR code texture
            let plane = SCNPlane(width: 0.16, height: 0.16)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.diffuse.contents = qrImage(for: code) ?? UIColor.white
            mat.diffuse.magnificationFilter = .nearest
            mat.isDoubleSided = true
            plane.materials = [mat]
            let qrNode = SCNNode(geometry: plane)
            qrNode.name = "qrPlane"

            // Levitation animation lives on a child so position updates don't fight it
            let floater = SCNNode()
            floater.addChildNode(glowNode)
            floater.addChildNode(qrNode)
            let up = SCNAction.moveBy(x: 0, y: 0.015, z: 0, duration: 1.2)
            up.timingMode = .easeInEaseOut
            floater.runAction(.repeatForever(.sequence([up, up.reversed()])))

            container.addChildNode(floater)
            return container
        }

        private func qrImage(for code: String) -> UIImage? {
            guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
            filter.setValue(Data(code.utf8), forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
            guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
                  let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
            return UIImage(cgImage: cg)
        }
    }
}