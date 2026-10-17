//
//  TrackMapHUDView.swift
//  GlassQR
//
//  Futuristic Scifi Head-Up Display (HUD) for Windshield Projection.
//  Inverts/mirrors the display horizontally for crisp, glare-free optical
//  reflection on vehicle windshields during night driving.
//

import SwiftUI

public struct TrackMapHUDView: View {
    @ObservedObject var manager = TrackMapManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var isMirrored: Bool = true
    @State private var hudColor: Color = .cyan
    @State private var showSettings: Bool = false
    @State private var pulseOverspeed: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Pitch Black High-Contrast Background for Windshield Reflection
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Top HUD Control Bar (Subtle)
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Exit HUD")
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: Capsule())
                    }

                    Spacer()

                    // Mirror Windshield Flip Toggle
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isMirrored.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right.fill")
                            Text(isMirrored ? "MIRRORED (HUD)" : "NORMAL")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(isMirrored ? hudColor : .white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(hudColor.opacity(isMirrored ? 0.2 : 0.05), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(hudColor.opacity(isMirrored ? 0.6 : 0.2), lineWidth: 1)
                        )
                    }

                    // Color Theme Picker
                    Menu {
                        Button("Electric Cyan") { hudColor = .cyan }
                        Button("Hyper Green") { hudColor = .green }
                        Button("Neon Amber") { hudColor = .orange }
                        Button("Liquid Violet") { hudColor = .purple }
                    } label: {
                        Circle()
                            .fill(hudColor)
                            .frame(width: 24, height: 24)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // Main HUD Telemetry Cluster (Mirrored when active)
                VStack(spacing: 12) {
                    // Compass Bearing Tape
                    HStack(spacing: 16) {
                        Text("\(Int(manager.headingDegrees))° \(manager.compassCardinal)")
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundStyle(hudColor.opacity(0.9))

                        Circle()
                            .fill(hudColor.opacity(0.4))
                            .frame(width: 4, height: 4)

                        Text("ALT: \(String(format: "%.0f", manager.currentAltitudeMeters))m")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    // Active Navigation Guidance Strip (HUD Mode)
                    if manager.activeRoute != nil {
                        HStack(spacing: 12) {
                            Image(systemName: manager.currentManeuverIcon)
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(hudColor)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(manager.unit.formatDistance(meters: manager.distanceToNextStep))
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundStyle(hudColor)

                                    if manager.routeSteps.indices.contains(manager.currentStepIndex) {
                                        Text(manager.routeSteps[manager.currentStepIndex].instructions)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                }

                                HStack(spacing: 10) {
                                    Text("DEST: \(manager.unit.formatDistance(meters: manager.distanceToDestination))")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                    Text("ETA: \(manager.formattedETAClock()) (\(manager.formattedDurationRemaining()))")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.green.opacity(0.85))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(hudColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(hudColor.opacity(0.35), lineWidth: 1))
                        .padding(.horizontal, 24)
                    }

                    // Massive High-Precision Speedometer Readout
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text(String(format: "%.0f", manager.currentSpeed))
                            .font(.system(size: 140, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                manager.isOverspeed
                                    ? Color.red
                                    : hudColor
                            )
                            .shadow(color: (manager.isOverspeed ? Color.red : hudColor).opacity(0.6), radius: 24, x: 0, y: 0)

                        Text(manager.unit.rawValue.uppercased())
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.bottom, 24)
                    }

                    // Overspeed Alert Warning Banner
                    if manager.isOverspeed {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("OVERSPEED: LIMIT \(String(format: "%.0f", manager.speedLimit)) \(manager.unit.rawValue)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.18), in: Capsule())
                        .overlay(Capsule().stroke(Color.red, lineWidth: 1.5))
                        .scaleEffect(pulseOverspeed ? 1.05 : 0.98)
                        .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: pulseOverspeed)
                        .onAppear { pulseOverspeed = true }
                    }

                    // Dynamic Speed Arc Bar
                    GeometryReader { geo in
                        let width = geo.size.width
                        let maxSpeed = max(120.0, manager.speedLimit * 1.3)
                        let ratio = min(1.0, max(0.0, manager.currentSpeed / maxSpeed))

                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 12)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [hudColor, manager.isOverspeed ? .red : hudColor.opacity(0.7)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(12, width * ratio), height: 12)
                                .shadow(color: hudColor.opacity(0.5), radius: 8, x: 0, y: 0)
                        }
                    }
                    .frame(height: 12)
                    .padding(.horizontal, 40)
                    .padding(.vertical, 8)

                    // Secondary Telemetry Row: Top Speed, Avg Speed, Distance, Time
                    HStack(spacing: 24) {
                        telemetryHUDCell(
                            title: "MAX",
                            value: String(format: "%.0f", manager.topSpeed),
                            unit: manager.unit.rawValue
                        )

                        telemetryHUDCell(
                            title: "AVG",
                            value: String(format: "%.0f", manager.averageSpeed),
                            unit: manager.unit.rawValue
                        )

                        telemetryHUDCell(
                            title: "DIST",
                            value: manager.unit.formatDistance(meters: manager.totalDistanceMeters),
                            unit: ""
                        )

                        telemetryHUDCell(
                            title: "G-FORCE",
                            value: String(format: "%+.2f", manager.accelerationG),
                            unit: "G"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .scaleEffect(x: isMirrored ? -1 : 1, y: 1) // Optical mirror transformation
                .contentShape(Rectangle())

                Spacer()

                // Windshield Placement Tip (Unmirrored for driver to read when holding phone)
                Text("Place your iPhone face-up on your vehicle dashboard under the front windshield at night.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .statusBar(hidden: true)
    }

    private func telemetryHUDCell(title: String, value: String, unit: String) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(hudColor.opacity(0.8))
                }
            }
        }
    }
}
