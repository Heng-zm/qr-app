//
//  LiDARManager.swift
//  GlassQR
//
//  Apple LiDAR Scanner (Time-of-Flight Depth Sensor) Telemetry & AR Engine.
//  Provides distance ranging, surface plane tilt estimation, depth heatmap
//  palettes, physical target size calculation, and AR anchor tracking.
//

import Foundation
import ARKit
import AVFoundation
import SwiftUI
import Combine

public final class LiDARManager: NSObject, ObservableObject, ARSessionDelegate {
    public static let shared = LiDARManager()

    // MARK: - Hardware Capabilities
    public static var isLiDARHardwareAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) ||
               ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        #endif
    }

    // MARK: - Published Telemetry Metrics
    @Published public var isLiDARRangingActive: Bool = false
    @Published public var isHardwareLiDAR: Bool = false
    @Published public var measuredDistanceMeters: Double = 1.25 // Smoothed distance
    @Published public var rawDistanceMeters: Double = 1.25
    @Published public var surfaceTiltDegrees: Double = 5.0
    @Published public var laserConfidencePercent: Double = 98.5
    @Published public var estimatedPhysicalWidthCm: Double = 12.0
    @Published public var estimatedPhysicalHeightCm: Double = 12.0
    @Published public var pointCloudDensity: Int = 18450
    @Published public var isNightVisionActive: Bool = false
    @Published public var depthHeatmapMode: DepthColorPalette = .cyberpunk
    @Published public var lastDetectedCode: String? = nil
    @Published public var lastDetectedSymbology: String? = nil
    @Published public var arHologramPosition: SIMD3<Float>? = nil
    @Published public var isTargetLocked: Bool = false
    @Published public var isCameraAccessDenied: Bool = false

    // MARK: - Internal ARKit Engine
    // ARSession delegate callbacks are delivered on the main queue (default),
    // so all state below is only touched from the main thread.
    public private(set) var arSession = ARSession()
    private var isSessionRunning = false
    private var smoothedDistance: Double = 1.25
    private var hasFirstSample = false
    private var simulationTimer: Timer?
    private var simulationAngle: Double = 0.0
    private var lastProcessedTimestamp: TimeInterval = 0
    private let updateInterval: TimeInterval = 1.0 / 20.0 // throttle UI updates to 20 Hz

    // Valid depth range (meters)
    private let minValidDepth: Float = 0.08
    private let maxValidDepth: Float = 12.0

    public enum DepthColorPalette: String, CaseIterable, Identifiable {
        case cyberpunk = "Cyberpunk"
        case infraredNight = "Night Vision"
        case thermalHeat = "Thermal"

        public var id: String { rawValue }

        public var tintColor: Color {
            switch self {
            case .cyberpunk: return .cyan
            case .infraredNight: return .green
            case .thermalHeat: return .orange
            }
        }
    }

    public override init() {
        super.init()
        self.isHardwareLiDAR = Self.isLiDARHardwareAvailable
        arSession.delegate = self
    }

    deinit {
        simulationTimer?.invalidate()
        arSession.pause()
    }

    // MARK: - Start / Stop Telemetry & AR Session

    private func makeConfiguration() -> ARWorldTrackingConfiguration {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            config.sceneReconstruction = .mesh
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        config.isLightEstimationEnabled = true
        return config
    }

    public func startSession() {
        // Guard on the ranging flag so repeated calls don't restart simulation either.
        guard !isLiDARRangingActive else { return }
        isLiDARRangingActive = true
        hasFirstSample = false
        lastProcessedTimestamp = 0
        isCameraAccessDenied = false

        #if !targetEnvironment(simulator)
        // Fast-path: skip the failing ARSession dance when camera access was
        // already denied (ARSession would just fail with .cameraUnauthorized).
        if AVCaptureDevice.authorizationStatus(for: .video) == .denied {
            isCameraAccessDenied = true
            return
        }
        if ARWorldTrackingConfiguration.isSupported {
            arSession.run(makeConfiguration(), options: [.resetTracking, .removeExistingAnchors])
            isSessionRunning = true
            isHardwareLiDAR = Self.isLiDARHardwareAvailable
            return
        }
        #endif

        // Graceful fallback to the physics simulator
        isHardwareLiDAR = false
        startSimulationMode()
    }

    public func stopSession() {
        isLiDARRangingActive = false
        if isSessionRunning {
            arSession.pause()
            isSessionRunning = false
        }
        stopSimulationMode()
    }

    public func toggleNightVision() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isNightVisionActive.toggle()
        }
    }

    public func cycleDepthPalette() {
        let all = DepthColorPalette.allCases
        if let idx = all.firstIndex(of: depthHeatmapMode) {
            depthHeatmapMode = all[(idx + 1) % all.count]
        }
    }

    // MARK: - ARSessionDelegate

    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isLiDARRangingActive else { return }

        // Throttle: ARKit delivers ~60 fps; publishing a dozen properties
        // that often needlessly re-renders SwiftUI.
        guard frame.timestamp - lastProcessedTimestamp >= updateInterval else { return }
        lastProcessedTimestamp = frame.timestamp

        let cameraTransform = frame.camera.transform
        let camPos = SIMD3<Float>(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        let camForward = -SIMD3<Float>(cameraTransform.columns.2.x, cameraTransform.columns.2.y, cameraTransform.columns.2.z)

        var extractedDistance: Double? = nil
        var depthConfidence: Double? = nil
        var validPointCount: Int? = nil

        // 1. LiDAR depth map (center sample + confidence + valid pixel count)
        if let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth {
            if let d = readCenterDepth(from: depthData.depthMap) {
                extractedDistance = Double(d)
            }
            if let confMap = depthData.confidenceMap {
                depthConfidence = readCenterConfidence(from: confMap)
            }
            validPointCount = countValidDepthPixels(in: depthData.depthMap)
        }

        // 2. Raycast: used for surface tilt (always) and as distance fallback
        let query = frame.raycastQuery(from: CGPoint(x: 0.5, y: 0.5),
                                       allowing: .estimatedPlane,
                                       alignment: .any)
        var tilt: Double? = nil
        if let hit = session.raycast(query).first {
            let t = hit.worldTransform.columns
            let targetPos = SIMD3<Float>(t.3.x, t.3.y, t.3.z)
            if extractedDistance == nil {
                extractedDistance = Double(simd_distance(camPos, targetPos))
            }
            // Plane normal is the Y axis of the hit transform
            let normal = simd_normalize(SIMD3<Float>(t.1.x, t.1.y, t.1.z))
            let dot = min(Float(1.0), max(Float(0.0), abs(simd_dot(normal, camForward))))
            tilt = Double(acos(dot) * 180.0 / Float.pi)
        }

        guard let validDist = extractedDistance,
              validDist > Double(minValidDepth), validDist < Double(maxValidDepth) else { return }

        // 3. Smoothing (EMA). Seed with the first sample to avoid a startup glide.
        if !hasFirstSample {
            smoothedDistance = validDist
            hasFirstSample = true
        }
        let jitter = abs(validDist - smoothedDistance) // measured BEFORE updating the filter
        smoothedDistance += (validDist - smoothedDistance) * 0.22

        rawDistanceMeters = validDist
        measuredDistanceMeters = smoothedDistance
        if let tilt = tilt { surfaceTiltDegrees = tilt }

        // Confidence: LiDAR confidence level (0 low, 1 medium, 2 high) minus jitter penalty
        let base: Double
        switch depthConfidence {
        case .some(let c) where c >= 2: base = 99.0
        case .some(let c) where c >= 1: base = 85.0
        case .some:                     base = 65.0
        case .none:                     base = 90.0
        }
        laserConfidencePercent = max(40.0, min(99.9, base - jitter * 40.0))
        isTargetLocked = smoothedDistance > 0.2 && smoothedDistance < 3.5

        // 4. Physical size from the real camera intrinsics (not a hard-coded FOV).
        // Use the shorter image side (screen width in portrait).
        let f = Double(frame.camera.intrinsics[0][0])
        let res = frame.camera.imageResolution
        let shortSide = Double(min(res.width, res.height))
        let fov = f > 0 ? 2.0 * atan(shortSide / (2.0 * f)) : 60.0 * .pi / 180.0
        let viewWidthMeters = 2.0 * smoothedDistance * tan(fov / 2.0)
        let qrRatioOnScreen = 0.32 // approx reticle proportion
        let physicalCm = max(3.0, min(100.0, viewWidthMeters * qrRatioOnScreen * 100.0))
        estimatedPhysicalWidthCm = physicalCm
        estimatedPhysicalHeightCm = physicalCm

        // 5. Point count: real number of valid depth pixels (falls back to feature points)
        if let count = validPointCount {
            pointCloudDensity = count
        } else if let pts = frame.rawFeaturePoints?.points {
            pointCloudDensity = pts.count
        }
    }

    public func session(_ session: ARSession, didFailWithError error: Error) {
        isSessionRunning = false

        // Camera access denied: real ranging is unusable. Surface the permission
        // problem instead of hiding it behind fake simulation readings.
        if (error as NSError).code == ARError.cameraUnauthorized.rawValue {
            isCameraAccessDenied = true
            return
        }

        // Fall back to simulation so the UI keeps working.
        if isLiDARRangingActive {
            isHardwareLiDAR = false
            startSimulationMode()
        }
    }

    public func sessionWasInterrupted(_ session: ARSession) {
        hasFirstSample = false
    }

    public func sessionInterruptionEnded(_ session: ARSession) {
        guard isLiDARRangingActive, isSessionRunning else { return }
        hasFirstSample = false
        session.run(makeConfiguration(), options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - Pixel Buffer Readers

    /// Reads the center depth in meters, respecting bytesPerRow (rows can be padded).
    private func readCenterDepth(from pixelBuffer: CVPixelBuffer) -> Float? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0,
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32,
              let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let row = base.advanced(by: (height / 2) * bytesPerRow).assumingMemoryBound(to: Float32.self)
        let depth = row[width / 2]
        return (depth.isNaN || depth <= minValidDepth || depth > 15.0) ? nil : depth
    }

    /// Reads the ARConfidenceLevel (UInt8: 0 low, 1 medium, 2 high) at the center.
    private func readCenterConfidence(from pixelBuffer: CVPixelBuffer) -> Double? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0,
              let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let row = base.advanced(by: (height / 2) * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        return Double(row[width / 2])
    }

    /// Counts valid depth pixels (sampled every 2nd pixel, scaled back up).
    private func countValidDepthPixels(in pixelBuffer: CVPixelBuffer) -> Int? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0, height > 0,
              CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_DepthFloat32,
              let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var count = 0
        for y in stride(from: 0, to: height, by: 2) {
            let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
            for x in stride(from: 0, to: width, by: 2) {
                let d = row[x]
                if !d.isNaN && d > minValidDepth && d < maxValidDepth { count += 1 }
            }
        }
        return count * 4
    }

    // MARK: - Holographic AR QR Code Anchor

    public func anchorHologram(code: String, symbology: String) {
        lastDetectedCode = code
        lastDetectedSymbology = symbology

        #if !targetEnvironment(simulator)
        if let currentFrame = arSession.currentFrame {
            let t = currentFrame.camera.transform
            let forward = -SIMD3<Float>(t.columns.2.x, t.columns.2.y, t.columns.2.z)
            let camPos = SIMD3<Float>(t.columns.3.x, t.columns.3.y, t.columns.3.z)
            let dist = Float(max(0.4, min(2.0, measuredDistanceMeters)))
            arHologramPosition = camPos + forward * dist
            return
        }
        #endif

        // Simulation hologram anchor
        arHologramPosition = SIMD3<Float>(0.0, 0.05, -Float(measuredDistanceMeters))
    }

    public func clearHologram() {
        lastDetectedCode = nil
        lastDetectedSymbology = nil
        arHologramPosition = nil
    }

    // MARK: - Simulation Mode (For Non-Pro Devices & Simulator)

    private func startSimulationMode() {
        simulationTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isLiDARRangingActive else { return }

            self.simulationAngle += 0.04
            // Natural hand tremor and slight distance variation (~1.1m to 1.5m)
            let simDist = 1.28 + sin(self.simulationAngle * 0.7) * 0.16 + cos(self.simulationAngle * 1.5) * 0.03
            self.rawDistanceMeters = simDist
            self.smoothedDistance += (simDist - self.smoothedDistance) * 0.18
            self.measuredDistanceMeters = self.smoothedDistance

            self.surfaceTiltDegrees = 4.2 + abs(cos(self.simulationAngle * 0.5)) * 6.5
            self.laserConfidencePercent = 97.8 + sin(self.simulationAngle * 2.0) * 1.8
            self.isTargetLocked = true

            let physicalCm = 12.0 + sin(self.simulationAngle * 0.3) * 0.6
            self.estimatedPhysicalWidthCm = physicalCm
            self.estimatedPhysicalHeightCm = physicalCm
            self.pointCloudDensity = 17800 + Int(sin(self.simulationAngle * 3.0) * 1200)
        }
        // .common keeps the timer firing while the user scrolls / interacts
        RunLoop.main.add(timer, forMode: .common)
        simulationTimer = timer
    }

    private func stopSimulationMode() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    // MARK: - Formatting Helpers

    public func formattedDistance(isKhmer: Bool = false) -> String {
        let meters = measuredDistanceMeters
        if meters < 1.0 {
            return String(format: "%.1f %@", meters * 100.0, isKhmer ? "ស.ម" : "cm")
        } else {
            return String(format: "%.2f %@", meters, isKhmer ? "ម៉ែត្រ" : "m")
        }
    }

    public func targetZoneColor() -> Color {
        if measuredDistanceMeters < 0.25 {
            return .orange // Too close
        } else if measuredDistanceMeters <= 2.2 {
            return .green  // Optimal Time-of-Flight sweet spot
        } else if measuredDistanceMeters <= 5.0 {
            return .cyan   // Mid-range
        } else {
            return .purple // Long-range
        }
    }
}