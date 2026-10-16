//
//  TrackMapView.swift
//  GlassQR
//
//  Next-Generation Liquid Glass TrackMap & High-Precision Telemetry Navigation.
//  Combines Google Maps-grade route directions, live traffic, 3D perspective pitch,
//  with telemetry superpowers: Live Speedometer HUD, speed-colored breadcrumb trails,
//  overspeed alerts, instant Geo-QR generation, and 100% offline GPS operation.
//

import SwiftUI
import MapKit
import CoreLocation

public struct TrackMapView: View {
    @ObservedObject var manager = TrackMapManager.shared
    @StateObject private var searchCompleter = MapSearchModel()

    // Map Presentation States
    @State private var mapType: MKMapType = .standard
    @State private var showsTraffic: Bool = false
    @State private var is3DPitchActive: Bool = true
    @State private var userTrackingMode: MKUserTrackingMode = .followWithHeading
    @State private var mapCenterTrigger: Int = 0

    // Search & Navigation States
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [MKMapItem] = []
    @State private var showDirectionsSheet: Bool = false
    @State private var showSpeedLimitPicker: Bool = false
    @State private var showHUDSheet: Bool = false
    @State private var showGeoQRSheet: Bool = false
    @State private var isKhmerLanguage: Bool = false

    // Telemetry Expanded State
    @State private var isTelemetryExpanded: Bool = false
    @State private var toastMessage: String? = nil

    private let qrRenderer = CrispQRRenderer()

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Full-Bleed Interactive MapKit Map
            TrackMapViewRepresentable(
                manager: manager,
                mapType: mapType,
                showsTraffic: showsTraffic,
                is3DPitchActive: is3DPitchActive,
                userTrackingMode: $userTrackingMode,
                mapCenterTrigger: mapCenterTrigger,
                onSelectCoordinate: { coord in
                    reverseGeocodeAndRoute(to: coord)
                }
            )
            .ignoresSafeArea()

            // 2. Top Floating Glass Island: Search Bar, Map Layers & Language
            VStack(spacing: 8) {
                topSearchBar

                if !searchResults.isEmpty {
                    searchResultsDropdown
                } else if let route = manager.activeRoute {
                    activeRouteBanner(route: route)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 3. Right-Side Map Quick Action Buttons
            VStack(spacing: 10) {
                Spacer()

                // Recenter & 3D Heading Lock
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        userTrackingMode = .followWithHeading
                        mapCenterTrigger += 1
                        is3DPitchActive = true
                    }
                    triggerToast(isKhmerLanguage ? "បានចាក់សោតាមទិសដៅក្បាល" : "Heading Locked")
                } label: {
                    Image(systemName: userTrackingMode == .followWithHeading ? "location.north.line.fill" : "location.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(userTrackingMode == .followWithHeading ? Color.cyan : Color.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
                }

                // Traffic Overlay Toggle
                Button {
                    withAnimation {
                        showsTraffic.toggle()
                    }
                    triggerToast(showsTraffic ? (isKhmerLanguage ? "បង្ហាញចរាចរណ៍" : "Traffic ON") : (isKhmerLanguage ? "បិទចរាចរណ៍" : "Traffic OFF"))
                } label: {
                    Image(systemName: showsTraffic ? "car.2.fill" : "car.2")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(showsTraffic ? Color.green : Color.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
                }

                // Map Style Switcher (Standard, Satellite, Hybrid)
                Menu {
                    Button(action: { mapType = .standard }) {
                        Label(isKhmerLanguage ? "ផែនទីស្តង់ដារ" : "Standard Vector", systemImage: "map")
                    }
                    Button(action: { mapType = .satellite }) {
                        Label(isKhmerLanguage ? "ផ្កាយរណប" : "Satellite", systemImage: "globe.americas.fill")
                    }
                    Button(action: { mapType = .hybrid }) {
                        Label(isKhmerLanguage ? "ផ្កាយរណប+ផ្លូវ" : "Hybrid", systemImage: "square.2.layers.3d.top.filled")
                    }
                } label: {
                    Image(systemName: "square.3.layers.3d.bottom.filled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.9))
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
                }

                // Simulated Drive Demo Mode Button
                Button {
                    manager.toggleSimulation()
                    triggerToast(manager.isSimulating ? (isKhmerLanguage ? "កំពុងបើកបរសាកល្បង..." : "Simulation Started") : (isKhmerLanguage ? "បានបញ្ឈប់ការសាកល្បង" : "Simulation Stopped"))
                } label: {
                    Image(systemName: manager.isSimulating ? "play.circle.fill" : "steeringwheel")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(manager.isSimulating ? Color.green : Color.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
                }

                Spacer().frame(height: 230)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 14)

            // 4. Bottom Floating Liquid Glass Telemetry & Speedometer Platter
            VStack(spacing: 8) {
                // Toast Pill
                if let toast = toastMessage {
                    Text(toast)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 0.75))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                speedometerHUDPlatter
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 72) // Space for floating bottom tab bar
        }
        .onAppear {
            manager.startTracking()
        }
        .sheet(isPresented: $showHUDSheet) {
            TrackMapHUDView()
        }
        .sheet(isPresented: $showGeoQRSheet) {
            geoQRSheet
        }
        .sheet(isPresented: $showDirectionsSheet) {
            turnByTurnDirectionsSheet
        }
        .sheet(isPresented: $showSpeedLimitPicker) {
            speedLimitConfigSheet
        }
    }

    // MARK: - Top Search Bar & Suggestions

    private var topSearchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                TextField(
                    isKhmerLanguage ? "ស្វែងរកទីតាំង ឬផ្លូវ (Google/Apple Maps)..." : "Search destination or address...",
                    text: $searchQuery
                )
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .autocorrectionDisabled()
                .onSubmit {
                    performSearch()
                }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                        searchResults.removeAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )

            // Language Toggle Chip (🇰🇭 / 🇺🇸)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isKhmerLanguage.toggle()
                }
                triggerToast(isKhmerLanguage ? "បានប្តូរទៅ ភាសាខ្មែរ 🇰🇭" : "Switched to English 🇺🇸")
            } label: {
                Text(isKhmerLanguage ? "🇰🇭" : "🇺🇸")
                    .font(.system(size: 16))
                    .frame(width: 40, height: 40)
                    .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 4)
    }

    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            ForEach(searchResults.prefix(4), id: \.self) { item in
                Button {
                    selectSearchResult(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.cyan)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Location")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)

                            Text(item.placemark.title ?? "")
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.6))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }

                if item != searchResults.prefix(4).last {
                    Divider().background(Color.white.opacity(0.1))
                }
            }
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.95), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 12, x: 0, y: 6)
    }

    private func activeRouteBanner(route: MKRoute) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                        .foregroundStyle(.green)
                    Text(manager.destinationMapItem?.name ?? (isKhmerLanguage ? "ទិសដៅ" : "Route Destination"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                HStack(spacing: 10) {
                    Text(manager.unit.formatDistance(meters: route.distance, isKhmer: isKhmerLanguage))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.cyan)

                    Text("•")
                        .foregroundStyle(.white.opacity(0.4))

                    let minutes = Int(route.expectedTravelTime / 60)
                    Text("\(minutes) \(isKhmerLanguage ? "នាទី" : "mins")")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                }
            }

            Spacer()

            // View Steps
            Button {
                showDirectionsSheet = true
            } label: {
                Text(isKhmerLanguage ? "ជំហាន" : "Steps")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.cyan.opacity(0.3), in: Capsule())
                    .overlay(Capsule().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
            }

            // Cancel Route
            Button {
                withAnimation {
                    manager.clearActiveRoute()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.92), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.green.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
    }

    // MARK: - Speedometer & Telemetry Glass Platter

    private var speedometerHUDPlatter: some View {
        VStack(spacing: 10) {
            // Speed Header & Arc Gauge
            HStack(alignment: .center, spacing: 14) {
                // Arc Gauge Widget
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 8)
                        .frame(width: 88, height: 88)

                    let maxSpeed = max(140.0, manager.speedLimit * 1.3)
                    let progress = min(1.0, max(0.0, manager.currentSpeed / maxSpeed))

                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            AngularGradient(
                                colors: [
                                    .cyan,
                                    .green,
                                    manager.isOverspeed ? .red : .yellow,
                                    .red
                                ],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 88, height: 88)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: progress)

                    VStack(spacing: 0) {
                        Text(String(format: "%.0f", manager.currentSpeed))
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(manager.isOverspeed ? Color.red : Color.white)

                        Text(manager.unit.rawValue)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                    }
                }

                // Middle Info: Speed Limit, Heading & Status
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        // Speed Limit Pill
                        Button {
                            showSpeedLimitPicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("LIMIT")
                                    .font(.system(size: 9, weight: .black))
                                Text("\(Int(manager.speedLimit))")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                            }
                            .foregroundStyle(manager.isOverspeed ? Color.white : Color.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(manager.isOverspeed ? Color.red : Color.white, in: RoundedRectangle(cornerRadius: 6))
                        }

                        // Compass Direction
                        HStack(spacing: 3) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 11))
                            Text("\(Int(manager.headingDegrees))° \(isKhmerLanguage ? manager.compassCardinalKhmer() : manager.compassCardinal)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(Color.white.opacity(0.85))

                        Spacer()

                        // Unit Switcher (km/h ⇄ mph)
                        Button {
                            manager.setUnit(manager.unit == .kmh ? .mph : .kmh)
                        } label: {
                            Text(manager.unit == .kmh ? "MPH" : "KM/H")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.cyan.opacity(0.18), in: Capsule())
                                .overlay(Capsule().stroke(Color.cyan.opacity(0.4), lineWidth: 0.75))
                        }
                    }

                    // Trip Status Summary
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(isKhmerLanguage ? "ចម្ងាយសរុប" : "DISTANCE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text(manager.unit.formatDistance(meters: manager.totalDistanceMeters, isKhmer: isKhmerLanguage))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(isKhmerLanguage ? "ល្បឿនមធ្យម" : "AVG SPEED")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(String(format: "%.1f", manager.averageSpeed)) \(manager.unit.rawValue)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(isKhmerLanguage ? "កម្ពស់" : "ALTITUDE")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                            Text("\(Int(manager.currentAltitudeMeters)) m")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            // Expanded Telemetry Drawer (Top speed, G-force, Elapsed time)
            if isTelemetryExpanded {
                Divider().background(Color.white.opacity(0.12))

                HStack(spacing: 16) {
                    telemetryMetricBlock(
                        title: isKhmerLanguage ? "ល្បឿនអតិបរមា" : "PEAK SPEED",
                        value: "\(String(format: "%.1f", manager.topSpeed)) \(manager.unit.rawValue)",
                        color: .yellow
                    )

                    let hours = Int(manager.tripElapsedTime) / 3600
                    let mins = (Int(manager.tripElapsedTime) % 3600) / 60
                    let secs = Int(manager.tripElapsedTime) % 60
                    telemetryMetricBlock(
                        title: isKhmerLanguage ? "រយៈពេល" : "DURATION",
                        value: String(format: "%02d:%02d:%02d", hours, mins, secs),
                        color: .green
                    )

                    telemetryMetricBlock(
                        title: isKhmerLanguage ? "កម្លាំង G" : "G-FORCE",
                        value: String(format: "%+.2f G", manager.accelerationG),
                        color: .cyan
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Quick Tool Action Buttons Row
            HStack(spacing: 8) {
                // 1. HUD Mode Button (Windshield Mirror)
                Button {
                    showHUDSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.dots.needle.bottom.100percent")
                        Text(isKhmerLanguage ? "របៀប HUD" : "HUD Mode")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.cyan.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cyan.opacity(0.4), lineWidth: 1))
                }

                // 2. Trip Recording Toggle
                Button {
                    if manager.isRecordingTrip {
                        manager.pauseTripRecording()
                        triggerToast(isKhmerLanguage ? "បានផ្អាកការកត់ត្រាផ្លូវ" : "Trip Paused")
                    } else {
                        manager.startTripRecording()
                        triggerToast(isKhmerLanguage ? "បានចាប់ផ្តើមកត់ត្រាផ្លូវ" : "Recording Trip...")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(manager.isRecordingTrip ? Color.red : Color.green)
                            .frame(width: 7, height: 7)
                        Text(manager.isRecordingTrip ? (isKhmerLanguage ? "កំពុងកត់ត្រា" : "Recording") : (isKhmerLanguage ? "កត់ត្រាផ្លូវ" : "Record"))
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }

                // 3. Share Geo-QR Button
                Button {
                    showGeoQRSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "qrcode")
                        Text(isKhmerLanguage ? "កូដ QR ទីតាំង" : "Geo-QR")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }

                // 4. Expand / Collapse Drawer Toggle
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isTelemetryExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isTelemetryExpanded ? "chevron.down" : "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 34, height: 32)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .background(
            Color(red: 0.07, green: 0.08, blue: 0.12).opacity(0.92),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            manager.isOverspeed ? Color.red : Color.cyan.opacity(0.6),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private func telemetryMetricBlock(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Turn-by-Turn Directions Sheet

    private var turnByTurnDirectionsSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()

                if manager.routeSteps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "signpost.right.and.left")
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(isKhmerLanguage ? "គ្មានទិសដៅផ្លូវត្រូវបានជ្រើសរើស" : "No Active Route Directions")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                } else {
                    List {
                        ForEach(Array(manager.routeSteps.enumerated()), id: \.element.id) { index, step in
                            HStack(alignment: .top, spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                    Text("\(index + 1)")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.cyan)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(step.instructions)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.white)

                                    Text(manager.unit.formatDistance(meters: step.distanceMeters, isKhmer: isKhmerLanguage))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.6))
                                }
                            }
                            .listRowBackground(Color.white.opacity(0.04))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle(isKhmerLanguage ? "ការណែនាំផ្លូវ" : "Route Directions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isKhmerLanguage ? "បិទ" : "Done") {
                        showDirectionsSheet = false
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Speed Limit Config Sheet

    private var speedLimitConfigSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Text(isKhmerLanguage ? "កំណត់ល្បឿនអតិបរមាសម្រាប់ការព្រមាន" : "Configure Overspeed Alert Threshold")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)

                    Text("\(Int(manager.speedLimit)) \(manager.unit.rawValue)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(.cyan)

                    // Presets
                    HStack(spacing: 10) {
                        let presets: [Double] = manager.unit == .kmh ? [40, 60, 80, 100, 120] : [25, 35, 45, 65, 75]
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                manager.speedLimit = preset
                            } label: {
                                Text("\(Int(preset))")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                    .foregroundStyle(manager.speedLimit == preset ? .black : .white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(manager.speedLimit == preset ? Color.cyan : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    Slider(value: $manager.speedLimit, in: (manager.unit == .kmh ? 20...180 : 15...110), step: 5)
                        .tint(.cyan)
                        .padding(.horizontal, 32)

                    Toggle(isKhmerLanguage ? "បើកការព្រមានល្បឿនលើសកម្រិត" : "Enable Overspeed Haptic Warning", isOn: $manager.isSpeedLimitAlertEnabled)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle(isKhmerLanguage ? "ការកំណត់ល្បឿន" : "Speed Alert Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isKhmerLanguage ? "រួចរាល់" : "Done") {
                        showSpeedLimitPicker = false
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Instant Geo-QR Generator Sheet

    private var geoQRSheet: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.09)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    Text(isKhmerLanguage ? "ស្កេនដើម្បីបើកទីតាំងនេះលើ Apple ឬ Google Maps" : "Scan to open this live coordinate in Apple Maps")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.top, 16)

                    let payload = manager.generateGeoQRData()
                    if let qrImage = qrRenderer.render(
                        text: payload,
                        foregroundColor: UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0),
                        backgroundColor: .white,
                        dotShape: .squircle,
                        eyeFrame: .rounded,
                        eyePupil: .squircle
                    ) {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 220, height: 220)
                            .padding(14)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.cyan.opacity(0.3), radius: 20, x: 0, y: 8)
                    }

                    Text(payload)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(2)
                        .padding(.horizontal, 24)

                    HStack(spacing: 12) {
                        ShareLink(item: payload) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text(isKhmerLanguage ? "ចែករំលែកតំណភ្ជាប់" : "Share Link")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white, in: Capsule())
                        }

                        Button {
                            UIPasteboard.general.string = payload
                            triggerToast(isKhmerLanguage ? "បានចម្លងទៅ Clipboard" : "Copied to Clipboard")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.doc")
                                Text(isKhmerLanguage ? "ចម្លង" : "Copy")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15), in: Capsule())
                        }
                    }

                    Spacer()
                }
            }
            .navigationTitle(isKhmerLanguage ? "កូដ QR ទីតាំង" : "Live Location Geo-QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isKhmerLanguage ? "រួចរាល់" : "Done") {
                        showGeoQRSheet = false
                    }
                    .foregroundStyle(.cyan)
                }
            }
        }
    }

    // MARK: - Actions & Search

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        if let current = manager.currentCoordinate {
            request.region = MKCoordinateRegion(center: current, latitudinalMeters: 50000, longitudinalMeters: 50000)
        }

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                if let items = response?.mapItems {
                    self.searchResults = items
                }
            }
        }
    }

    private func selectSearchResult(_ item: MKMapItem) {
        searchResults.removeAll()
        searchQuery = item.name ?? ""
        manager.calculateRoute(to: item)
        triggerToast(isKhmerLanguage ? "កំពុងគណនាផ្លូវទៅកាន់ \(item.name ?? "")..." : "Calculating Route to \(item.name ?? "")...")
    }

    private func reverseGeocodeAndRoute(to coord: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                let placemark = placemarks?.first ?? MKPlacemark(coordinate: coord)
                let item = MKMapItem(placemark: MKPlacemark(placemark: placemark))
                item.name = placemarks?.first?.name ?? "Dropped Pin"
                self.manager.calculateRoute(to: item)
            }
        }
    }

    private func triggerToast(_ text: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            toastMessage = text
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                if self.toastMessage == text {
                    self.toastMessage = nil
                }
            }
        }
    }
}

// MARK: - Search Model Helper

final class MapSearchModel: ObservableObject {
    // Kept lightweight for search management
}

// MARK: - UIViewRepresentable for MKMapView

public struct TrackMapViewRepresentable: UIViewRepresentable {
    @ObservedObject var manager: TrackMapManager
    var mapType: MKMapType
    var showsTraffic: Bool
    var is3DPitchActive: Bool
    @Binding var userTrackingMode: MKUserTrackingMode
    var mapCenterTrigger: Int
    var onSelectCoordinate: (CLLocationCoordinate2D) -> Void

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true

        // Tap gesture to drop pin and navigate
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tap)

        return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.mapType = mapType
        mapView.showsTraffic = showsTraffic

        // Update Overlays (Route & Breadcrumbs)
        updateRouteOverlays(mapView: mapView)

        // Handle Tracking Mode
        if mapView.userTrackingMode != userTrackingMode {
            mapView.setUserTrackingMode(userTrackingMode, animated: true)
        }

        // Camera Pitch
        if is3DPitchActive && mapView.camera.pitch < 30 {
            var camera = mapView.camera
            camera.pitch = 45.0
            mapView.setCamera(camera, animated: true)
        }
    }

    private func updateRouteOverlays(mapView: MKMapView) {
        // Clear old polylines if needed
        let existingPolylines = mapView.overlays.filter { $0 is MKPolyline }

        if let route = manager.activeRoute {
            if !existingPolylines.contains(where: { ($0 as? MKPolyline) == route.polyline }) {
                mapView.removeOverlays(existingPolylines)
                mapView.addOverlay(route.polyline, level: .aboveRoads)

                // Add destination annotation if not present
                if let dest = manager.destinationMapItem {
                    let existingPins = mapView.annotations.filter { !($0 is MKUserLocation) }
                    mapView.removeAnnotations(existingPins)

                    let pin = MKPointAnnotation()
                    pin.coordinate = dest.placemark.coordinate
                    pin.title = dest.name
                    mapView.addAnnotation(pin)
                }
            }
        } else if existingPolylines.count > 0 && manager.activeRoute == nil {
            mapView.removeOverlays(existingPolylines)
            let existingPins = mapView.annotations.filter { !($0 is MKUserLocation) }
            mapView.removeAnnotations(existingPins)
        }

        // Draw breadcrumbs if recording trip
        if manager.isRecordingTrip && manager.breadcrumbs.count > 1 {
            let coords = manager.breadcrumbs.map { $0.coordinate }
            let breadcrumbLine = MKPolyline(coordinates: coords, count: coords.count)
            // Add breadcrumb trail
            if !mapView.overlays.contains(where: { $0.title == "BreadcrumbTrail" }) {
                breadcrumbLine.title = "BreadcrumbTrail"
                mapView.addOverlay(breadcrumbLine, level: .aboveRoads)
            }
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: TrackMapViewRepresentable

        init(_ parent: TrackMapViewRepresentable) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onSelectCoordinate(coord)
        }

        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.title == "BreadcrumbTrail" {
                    renderer.strokeColor = UIColor(red: 0.0, green: 0.9, blue: 0.95, alpha: 0.85)
                    renderer.lineWidth = 5.0
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                } else {
                    // Navigation Route
                    renderer.strokeColor = UIColor(red: 0.05, green: 0.65, blue: 1.0, alpha: 0.95)
                    renderer.lineWidth = 7.0
                    renderer.lineCap = .round
                    renderer.lineJoin = .round
                }
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        public func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !annotation.isKind(of: MKUserLocation.self) else { return nil }

            let identifier = "DestinationPin"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                view?.markerTintColor = UIColor(red: 0.05, green: 0.65, blue: 1.0, alpha: 1.0)
                view?.glyphImage = UIImage(systemName: "flag.fill")
            } else {
                view?.annotation = annotation
            }
            return view
        }

        public func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            DispatchQueue.main.async {
                self.parent.userTrackingMode = mode
            }
        }
    }
}
