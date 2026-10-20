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
import QuartzCore
import UIKit

public struct TrackMapView: View {
    @StateObject private var manager = TrackMapManager.shared

    // Map Presentation States
    @State private var mapType: MKMapType = .standard
    @State private var showsTraffic: Bool = false
    @State private var is3DPitchActive: Bool = true
    @State private var isHeadingLocked: Bool = true
    @State private var mapCenterTrigger: Int = 0

    // Search & Navigation States
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [MKMapItem] = []
    /// Retained so a newer query can cancel the previous in-flight search
    /// instead of letting stale, slower results race in.
    @State private var activeSearch: MKLocalSearch? = nil
    @State private var showDirectionsSheet: Bool = false
    @State private var showSpeedLimitPicker: Bool = false
    @State private var showHUDSheet: Bool = false
    @State private var showGeoQRSheet: Bool = false
    @State private var geoQRPayload: String = ""
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
                isHeadingLocked: $isHeadingLocked,
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
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if let route = manager.activeRoute {
                    activeNavigationGuidanceCard(route: route)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let notice = manager.navigationNotice {
                    noticeBanner(localizedNotice(notice))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: !searchResults.isEmpty)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: manager.activeRoute != nil)
            .animation(.spring(response: 0.42, dampingFraction: 0.85), value: manager.navigationNotice == nil)

            // 3. Right-Side Map Quick Action Buttons
            VStack(spacing: 10) {
                Spacer()

                // Recenter & 3D Heading Lock (60 FPS Cinematic Follow)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        isHeadingLocked = true
                        is3DPitchActive = true
                        mapCenterTrigger += 1
                    }
                    triggerToast(isKhmerLanguage ? "បានចាក់សោតាមទិសដៅក្បាល 60 FPS" : "Heading Locked (60 FPS)")
                } label: {
                    Image(systemName: isHeadingLocked ? "location.north.line.fill" : "location.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isHeadingLocked ? Color.cyan : Color.white)
                        .frame(width: 44, height: 44)
                        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: Circle())
                        .overlay(Circle().stroke(isHeadingLocked ? Color.cyan.opacity(0.65) : Color.white.opacity(0.2), lineWidth: 1.2))
                        .shadow(color: isHeadingLocked ? Color.cyan.opacity(0.4) : Color.black.opacity(0.3), radius: 8, x: 0, y: 3)
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
            .padding(.bottom, 84) // Space for floating bottom tab bar
        }
        // GNSS lifecycle is routed by MainGlassTabView via onChange(of: selectedTab)
        // because opacity-based tabs never fire onAppear/onDisappear on switches.
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
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: searchQuery.isEmpty)

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
        let shownResults = Array(searchResults.prefix(4))

        return VStack(spacing: 0) {
            if isSearching && searchResults.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.cyan)
                        .scaleEffect(0.8)
                    Text(isKhmerLanguage ? "កំពុងស្វែងរក..." : "Searching...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            ForEach(shownResults.indices, id: \.self) { index in
                let item = shownResults[index]

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

                if index < shownResults.count - 1 {
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

    // MARK: - Route / Permission Notice Banner

    private func noticeBanner(_ notice: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)

            Text(notice)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                manager.navigationNotice = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("Dismiss notice")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Manager notices are authored in English; known static strings map to
    /// Khmer at render time. Dynamic strings (raw MapKit error details) fall
    /// back to the original text.
    private func localizedNotice(_ notice: String) -> String {
        guard isKhmerLanguage else { return notice }
        if notice.hasPrefix("Route error: ") {
            return "កំហុសផ្លូវ: \(notice.dropFirst("Route error: ".count))"
        }
        switch notice {
        case "Location permission denied. Enable in iOS Settings to track GPS speed.":
            return "សិទ្ធិទីតាំងត្រូវបានបដិសេធ។ បើកនៅក្នុងការកំណត់ iOS ដើម្បីតាមដានល្បឿន GPS។"
        case "No route found to destination.":
            return "រកមិនឃើញផ្លូវទៅកាន់ទិសដៅទេ។"
        case "No transit route was found. Try Drive or Walk mode.":
            return "រកមិនឃើញផ្លូវដឹកជញ្ជូនទេ។ សូមព្យាយាមរបៀបបើកបរ ឬរបៀបដើរ។"
        case "No route was found for this trip.":
            return "រកមិនឃើញផ្លូវសម្រាប់ដំណើរនេះទេ។"
        default:
            return notice
        }
    }

    private func activeNavigationGuidanceCard(route: MKRoute) -> some View {
        VStack(spacing: 8) {
            guidanceManeuverRow
            guidanceProgressBar
            guidanceEtaAndModeRow
            if manager.alternateRoutes.count > 1 {
                guidanceAlternateRoutesRow
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(red: 0.08, green: 0.09, blue: 0.14).opacity(0.94), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(guidanceCardBorder)
        .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 5)
    }

    private var guidanceCardBorder: some View {
        let colors: [Color]
        if manager.hasArrivedAtDestination {
            colors = [Color.green.opacity(0.6), Color.mint.opacity(0.3)]
        } else if manager.isOffRoute {
            colors = [Color.orange.opacity(0.6), Color.red.opacity(0.3)]
        } else {
            colors = [Color.cyan.opacity(0.5), Color.white.opacity(0.2)]
        }

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: 1.2
            )
    }

    private var guidanceManeuverRow: some View {
        HStack(spacing: 12) {
            guidanceManeuverIconBadge
            guidanceManeuverText
            Spacer(minLength: 4)
            guidanceActionButtons
        }
    }

    private var guidanceManeuverIconBadge: some View {
        let bgColors: [Color]
        let shadowColor: Color
        if manager.hasArrivedAtDestination {
            bgColors = [Color.green.opacity(0.85), Color.mint.opacity(0.7)]
            shadowColor = Color.green
        } else if manager.isOffRoute {
            bgColors = [Color.orange.opacity(0.85), Color.red.opacity(0.7)]
            shadowColor = Color.orange
        } else {
            bgColors = [Color.cyan.opacity(0.85), Color.blue.opacity(0.7)]
            shadowColor = Color.cyan
        }

        return ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 48, height: 48)
                .shadow(color: shadowColor.opacity(0.4), radius: 8, x: 0, y: 3)

            Image(systemName: manager.currentManeuverIcon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var guidanceManeuverText: some View {
        VStack(alignment: .leading, spacing: 2) {
            if manager.hasArrivedAtDestination {
                Text(isKhmerLanguage ? "បានមកដល់ទិសដៅហើយ!" : "You Have Arrived!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.green)

                Text(manager.destinationMapItem?.name ?? (isKhmerLanguage ? "ទិសដៅ" : "Destination"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            } else if manager.isOffRoute {
                HStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .orange))
                        .scaleEffect(0.7)
                    Text(isKhmerLanguage ? "កំពុងគណនាផ្លូវឡើងវិញ..." : "Recalculating Route...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.orange)
                }

                Text(manager.unit.formatDistance(meters: manager.distanceToDestination, isKhmer: isKhmerLanguage))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                HStack(spacing: 6) {
                    Text(manager.unit.formatDistance(meters: manager.distanceToNextStep, isKhmer: isKhmerLanguage))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.cyan)

                    if manager.routeSteps.indices.contains(manager.currentStepIndex + 1) {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.3))
                        Image(systemName: manager.routeSteps[manager.currentStepIndex + 1].maneuverIcon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                if manager.routeSteps.indices.contains(manager.currentStepIndex) {
                    Text(manager.routeSteps[manager.currentStepIndex].instructions)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                } else {
                    Text(manager.destinationMapItem?.name ?? (isKhmerLanguage ? "បន្តទៅមុខ" : "Proceed to destination"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }
        }
    }

    private var guidanceActionButtons: some View {
        HStack(spacing: 6) {
            Button {
                manager.routeOverviewFitTrigger += 1
                triggerToast(isKhmerLanguage ? "ទិដ្ឋភាពទូទៅនៃផ្លូវ" : "Route Overview")
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12), in: Circle())
            }

            Button {
                showDirectionsSheet = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.12), in: Circle())
            }

            Button {
                withAnimation {
                    manager.clearActiveRoute()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Color.red.opacity(0.2), in: Circle())
            }
        }
    }

    private var guidanceProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)

                let progressWidth = max(4.0, geo.size.width * CGFloat(manager.routeProgressPercentage))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: progressWidth, height: 4)
            }
        }
        .frame(height: 4)
    }

    private var guidanceEtaAndModeRow: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                Text(manager.formattedDurationRemaining(isKhmer: isKhmerLanguage))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.green)
            }

            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.cyan)
                Text(manager.unit.formatDistance(meters: manager.distanceToDestination, isKhmer: isKhmerLanguage))
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.cyan)
            }

            HStack(spacing: 4) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
                Text(manager.formattedETAClock())
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            guidanceTransportModes
        }
    }

    private var guidanceTransportModes: some View {
        HStack(spacing: 4) {
            ForEach(TransportMode.allCases) { mode in
                Button {
                    if manager.transportMode != mode, let dest = manager.destinationMapItem {
                        withAnimation {
                            manager.calculateRoute(to: dest, mode: mode, autoFrameOverview: false)
                        }
                        triggerToast(isKhmerLanguage ? "ផ្លាស់ប្តូរទៅ \(mode.localizedName(isKhmer: true))" : "Switched to \(mode.rawValue)")
                    }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(manager.transportMode == mode ? Color.black : Color.white.opacity(0.7))
                        .frame(width: 22, height: 22)
                        .background(manager.transportMode == mode ? Color.cyan : Color.white.opacity(0.08), in: Circle())
                }
            }
        }
    }

    private var guidanceAlternateRoutesRow: some View {
        HStack(spacing: 8) {
            Text(isKhmerLanguage ? "ជម្រើសផ្លូវ:" : "Routes:")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))

            ForEach(Array(manager.alternateRoutes.enumerated()), id: \.offset) { idx, altRoute in
                let isSelected = manager.selectedRouteIndex == idx
                Button {
                    withAnimation {
                        manager.selectRoute(at: idx)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("#\(idx + 1)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                        let mins = Int(altRoute.expectedTravelTime / 60)
                        Text("\(mins)m")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.06), in: Capsule())
                    .overlay(Capsule().stroke(isSelected ? Color.cyan : Color.white.opacity(0.15), lineWidth: 1))
                    .foregroundStyle(isSelected ? Color.cyan : Color.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(.top, 2)
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

                // 2. Trip Recording Toggle (pause / resume without wiping the trip)
                Button {
                    if manager.isRecordingTrip {
                        manager.pauseTripRecording()
                        triggerToast(isKhmerLanguage ? "បានផ្អាកការកត់ត្រាផ្លូវ" : "Trip Paused")
                    } else if manager.tripElapsedTime > 0 {
                        manager.resumeTripRecording()
                        triggerToast(isKhmerLanguage ? "បានបន្តការកត់ត្រាផ្លូវ" : "Trip Resumed")
                    } else {
                        manager.startTripRecording()
                        triggerToast(isKhmerLanguage ? "បានចាប់ផ្តើមកត់ត្រាផ្លូវ" : "Recording Trip...")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(manager.isRecordingTrip ? Color.red : Color.green)
                            .frame(width: 7, height: 7)
                        Text(
                            manager.isRecordingTrip
                            ? (isKhmerLanguage ? "កំពុងកត់ត្រា" : "Recording")
                            : (manager.tripElapsedTime > 0
                               ? (isKhmerLanguage ? "បន្ត" : "Resume")
                               : (isKhmerLanguage ? "កត់ត្រាផ្លូវ" : "Record"))
                        )
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                }

                // 3. Share Geo-QR Button (snapshot the payload per presentation)
                Button {
                    geoQRPayload = manager.generateGeoQRData()
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

                // 5. GPX Trail Export
                Button {
                    exportGPXTrail()
                } label: {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(manager.breadcrumbs.count > 1 ? Color.green : Color.white.opacity(0.65))
                        .frame(width: 34, height: 32)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
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

    // MARK: - GPX Trail Export

    /// Writes the recorded trail to a temp .gpx file and opens the system
    /// share sheet (same presentation flow as GeneratorView.sharePDF).
    private func exportGPXTrail() {
        guard let gpx = manager.buildGPXDocument() else {
            triggerToast(isKhmerLanguage ? "គ្មានផ្លូវដែលបានកត់ត្រាទេ" : "No trail recorded yet")
            return
        }

        let stampFormatter = DateFormatter()
        stampFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        let stamp = manager.breadcrumbs.first?.timestamp ?? Date()
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlassQR-Trip-\(stampFormatter.string(from: stamp)).gpx")
        do {
            try gpx.write(to: tempURL, atomically: true, encoding: .utf8)
        } catch {
            triggerToast(isKhmerLanguage ? "នាំចេញមិនបានជោគជ័យ" : "Export failed")
            return
        }

        let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene ?? UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController {
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            topVC.present(activityVC, animated: true)
        }
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
                        // Header summary card
                        Section {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(manager.destinationMapItem?.name ?? (isKhmerLanguage ? "ទិសដៅ" : "Destination"))
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Image(systemName: manager.transportMode.icon)
                                        Text(manager.transportMode.localizedName(isKhmer: isKhmerLanguage))
                                    }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.15), in: Capsule())
                                }

                                HStack(spacing: 12) {
                                    Text(manager.unit.formatDistance(meters: manager.distanceToDestination, isKhmer: isKhmerLanguage))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.cyan)

                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.3))

                                    Text(manager.formattedDurationRemaining(isKhmer: isKhmerLanguage))
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.green)

                                    Text("•")
                                        .foregroundStyle(.white.opacity(0.3))

                                    Text("ETA \(manager.formattedETAClock())")
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.white.opacity(0.06))
                        }

                        // Steps list
                        Section(header: Text(isKhmerLanguage ? "ជំហានតាមដងផ្លូវ" : "Route Steps").font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.6))) {
                            ForEach(Array(manager.routeSteps.enumerated()), id: \.element.id) { index, step in
                                let isCurrent = index == manager.currentStepIndex
                                let isCompleted = index < manager.currentStepIndex

                                HStack(alignment: .top, spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                isCurrent
                                                    ? Color.cyan.opacity(0.35)
                                                    : isCompleted
                                                    ? Color.white.opacity(0.05)
                                                    : Color.cyan.opacity(0.12)
                                            )
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .stroke(isCurrent ? Color.cyan : Color.white.opacity(0.1), lineWidth: 1.2)
                                            )

                                        Image(systemName: step.maneuverIcon)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(isCurrent ? Color.cyan : (isCompleted ? Color.white.opacity(0.35) : Color.white))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 6) {
                                            Text(step.instructions)
                                                .font(.system(size: 14, weight: isCurrent ? .bold : .medium))
                                                .foregroundStyle(isCompleted ? Color.white.opacity(0.4) : Color.white)

                                            if isCurrent {
                                                Text(isKhmerLanguage ? "បច្ចុប្បន្ន" : "ACTIVE")
                                                    .font(.system(size: 9, weight: .black, design: .monospaced))
                                                    .foregroundStyle(.black)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.cyan, in: Capsule())
                                            }
                                        }

                                        HStack(spacing: 8) {
                                            Text(manager.unit.formatDistance(meters: step.distanceMeters, isKhmer: isKhmerLanguage))
                                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(isCurrent ? Color.cyan : Color.white.opacity(0.55))

                                            if let notice = step.notice {
                                                Text("• \(notice)")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.orange.opacity(0.85))
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                                .listRowBackground(isCurrent ? Color.cyan.opacity(0.08) : Color.white.opacity(0.03))
                            }
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

                    // Captured when the sheet opens, so GPS ticks don't re-run the
                    // QR renderer on every location update while it is showing.
                    let payload = geoQRPayload
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

        // Cancel any in-flight search so a stale, slower response can never
        // overwrite the results of a newer query.
        activeSearch?.cancel()

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        if let current = manager.currentCoordinate {
            request.region = MKCoordinateRegion(center: current, latitudinalMeters: 50000, longitudinalMeters: 50000)
        }

        let search = MKLocalSearch(request: request)
        activeSearch = search
        isSearching = true

        search.start { response, error in
            DispatchQueue.main.async {
                // Ignore completions from outdated queries (including user cancels).
                guard self.activeSearch === search else { return }
                self.activeSearch = nil
                self.isSearching = false

                if let items = response?.mapItems, !items.isEmpty {
                    self.searchResults = items
                } else if let error = error {
                    // User-cancelled searches report as errors; don't nag about them.
                    let nsError = error as NSError
                    let isCancelled = nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
                    if !isCancelled {
                        self.triggerToast(self.isKhmerLanguage ? "ការស្វែងរកមិនជោគជ័យ" : "Search failed — check connection")
                    }
                } else {
                    self.triggerToast(self.isKhmerLanguage ? "រកមិនឃើញលទ្ធផល" : "No results found")
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

// MARK: - UIViewRepresentable for MKMapView (60fps High-Refresh Telemetry Engine)

public struct TrackMapViewRepresentable: UIViewRepresentable {
    @ObservedObject var manager: TrackMapManager
    var mapType: MKMapType
    var showsTraffic: Bool
    var is3DPitchActive: Bool
    @Binding var isHeadingLocked: Bool
    var mapCenterTrigger: Int
    var onSelectCoordinate: (CLLocationCoordinate2D) -> Void

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// CADisplayLink strongly retains its target, so without an explicit
    /// teardown the tick would keep this coordinator (and a dangling map ref)
    /// alive and firing long after the view leaves the hierarchy.
    public static func dismantleUIView(_ mapView: MKMapView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = false
        mapView.showsScale = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.isScrollEnabled = true
        mapView.isZoomEnabled = true

        // The double-tap must exist before the single tap so the single tap can
        // wait for it to fail — otherwise the first press of a double-tap zoom
        // would drop a pin and start navigation.
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.delegate = context.coordinator
        mapView.addGestureRecognizer(doubleTap)

        // Tap gesture to drop pin and navigate
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.require(toFail: doubleTap)
        mapView.addGestureRecognizer(tap)

        // Seamless gestures to detect manual user panning/zooming and unlock camera lock
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.delegate = context.coordinator
        mapView.addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        mapView.addGestureRecognizer(pinch)

        context.coordinator.setup(mapView: mapView)

        return mapView
    }

    public func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }
        if mapView.showsTraffic != showsTraffic {
            mapView.showsTraffic = showsTraffic
        }

        // Battery: suspend the 60fps camera lerp display link whenever
        // heading-lock is off so the main thread doesn't wake for a no-op guard.
        if context.coordinator.lastHeadingLocked != isHeadingLocked {
            context.coordinator.lastHeadingLocked = isHeadingLocked
            context.coordinator.displayLinkSetPaused(!isHeadingLocked)
        }

        // Overlays (Routes & Breadcrumbs)
        context.coordinator.updateOverlays(mapView: mapView)

        // Handle Route Overview Framing Trigger
        if context.coordinator.lastRouteFitTrigger != manager.routeOverviewFitTrigger {
            context.coordinator.lastRouteFitTrigger = manager.routeOverviewFitTrigger
            if let route = manager.activeRoute {
                context.coordinator.frameRouteOverview(route: route)
            }
        }

        // Handle Re-center & Heading Lock Trigger from UI
        if context.coordinator.lastCenterTrigger != mapCenterTrigger {
            context.coordinator.lastCenterTrigger = mapCenterTrigger
            context.coordinator.engageHeadingLock()
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: TrackMapViewRepresentable
        weak var mapView: MKMapView?
        private var displayLink: CADisplayLink?

        // 60fps/120fps Interpolated Camera State
        var camLat: Double = 0.0
        var camLon: Double = 0.0
        var camHeading: Double = 0.0
        var camAltitude: Double = 380.0
        var camPitch: CGFloat = 52.0
        var hasInitializedCamera: Bool = false

        // Last values actually written to the map camera, used to skip
        // redundant camera writes once the lerp has converged.
        var hasWrittenCamera: Bool = false
        var lastWriteLat: Double = 0.0
        var lastWriteLon: Double = 0.0
        var lastWriteHeading: Double = 0.0
        var lastWriteAltitude: Double = 0.0
        var lastWritePitch: CGFloat = 0.0

        var lastCenterTrigger: Int = 0
        var lastRouteFitTrigger: Int = 0
        var lastBreadcrumbCount: Int = 0
        var lastOverlayCrumbs: Int = -1
        weak var lastOverlayRoute: MKRoute?
        var isUserDragging: Bool = false
        var lastHeadingLocked: Bool = false

        public func frameRouteOverview(route: MKRoute) {
            guard let mapView = mapView else { return }
            DispatchQueue.main.async {
                self.parent.isHeadingLocked = false
            }
            let edgePadding = UIEdgeInsets(top: 140, left: 35, bottom: 250, right: 35)
            mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: edgePadding, animated: true)
        }

        init(_ parent: TrackMapViewRepresentable) {
            self.parent = parent
            super.init()
        }

        /// Explicit teardown from dismantleUIView; deinit is not guaranteed to
        /// run while the display link holds a strong reference to this target.
        func teardown() {
            displayLink?.invalidate()
            displayLink = nil
            mapView?.delegate = nil
            mapView = nil
        }

        func setup(mapView: MKMapView) {
            self.mapView = mapView

            displayLink?.invalidate()
            let link = CADisplayLink(target: self, selector: #selector(onDisplayLinkTick))
            // Cap at 60Hz: a lerped camera gains nothing from ProMotion 120Hz,
            // and halving the refresh ceiling is a large battery win on Pro devices
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        }

        /// The CADisplayLink is paused whenever heading-lock is off, so no camera
        /// writes (and no display-link wakeups) happen while the user browses.
        func displayLinkSetPaused(_ paused: Bool) {
            displayLink?.isPaused = paused
        }

        public func engageHeadingLock() {
            guard let mapView = mapView else { return }
            // Seed lerp state with current camera position so camera glides smoothly to user position
            camLat = mapView.camera.centerCoordinate.latitude
            camLon = mapView.camera.centerCoordinate.longitude
            camHeading = mapView.camera.heading
            camAltitude = mapView.camera.centerCoordinateDistance > 50 ? mapView.camera.centerCoordinateDistance : 380.0
            camPitch = mapView.camera.pitch
            hasInitializedCamera = true
            hasWrittenCamera = false
        }

        @objc func onDisplayLinkTick() {
            guard parent.isHeadingLocked else { return }
            guard !isUserDragging else { return }
            guard let targetCoord = parent.manager.currentCoordinate else { return }
            guard let mapView = mapView else { return }

            if !hasInitializedCamera || (camLat == 0.0 && camLon == 0.0) {
                camLat = targetCoord.latitude
                camLon = targetCoord.longitude
                camHeading = parent.manager.headingDegrees
                camAltitude = 380.0
                camPitch = 52.0
                hasInitializedCamera = true
            }

            // Fail-safe: if any lerp state turned NaN/∞ (e.g. from a corrupted
            // location or heading sample), reseed from trusted values instead
            // of handing NaN to MKMapCamera.
            if !camLat.isFinite || !camLon.isFinite || !camHeading.isFinite
                || !camAltitude.isFinite || !camPitch.isFinite {
                camLat = targetCoord.latitude
                camLon = targetCoord.longitude
                camHeading = parent.manager.headingDegrees
                camAltitude = 380.0
                camPitch = parent.is3DPitchActive ? 52.0 : 0.0
            }

            // 1. Position Lerp (Factor 0.12 provides smooth follow without lag)
            camLat += (targetCoord.latitude - camLat) * 0.12
            camLon += (targetCoord.longitude - camLon) * 0.12
            let currentCenter = CLLocationCoordinate2D(latitude: camLat, longitude: camLon)

            // 2. Shortest-Arc Circular Lerp for Heading (Factor 0.10)
            let targetHeading = parent.manager.headingDegrees
            var dHeading = (targetHeading - camHeading).truncatingRemainder(dividingBy: 360.0)
            if dHeading > 180.0 { dHeading -= 360.0 }
            if dHeading < -180.0 { dHeading += 360.0 }
            camHeading += dHeading * 0.10
            if camHeading < 0.0 { camHeading += 360.0 }
            if camHeading >= 360.0 { camHeading -= 360.0 }

            // 3. Dynamic Speed-Based Altitude Zooming
            // Stopped/Slow (< 15 km/h): 380m
            // Cruising (50-80 km/h): ~550m-700m
            // Highway (120+ km/h): up to 880m
            let speedKmh = max(0.0, parent.manager.currentSpeedMPS * 3.6)
            let targetAltitude = 380.0 + min(500.0, speedKmh * 4.2)
            camAltitude += (targetAltitude - camAltitude) * 0.06

            // 4. Smooth 3D Perspective Pitch (52 degrees optimal navigation angle)
            let targetPitch: CGFloat = parent.is3DPitchActive ? 52.0 : 0.0
            camPitch += (targetPitch - camPitch) * 0.08

            // 5. Update MapKit Camera Directly at 60fps/120fps (Zero tracking mode jitter)
            // Skip redundant writes once the lerp has converged: a parked car
            // would otherwise re-drive the MapKit 3D camera engine 60–120
            // times per second with no visual change.
            let hasVisibleChange =
                abs(currentCenter.latitude - lastWriteLat) > 1.5e-6
                || abs(currentCenter.longitude - lastWriteLon) > 1.5e-6
                || abs(camHeading - lastWriteHeading) > 0.1
                || abs(camAltitude - lastWriteAltitude) > 1.5
                || abs(Double(camPitch) - Double(lastWritePitch)) > 0.25
            if hasWrittenCamera && !hasVisibleChange { return }

            let camera = MKMapCamera(
                lookingAtCenter: currentCenter,
                fromDistance: camAltitude,
                pitch: camPitch,
                heading: camHeading
            )
            mapView.camera = camera
            hasWrittenCamera = true
            lastWriteLat = camLat
            lastWriteLon = camLon
            lastWriteHeading = camHeading
            lastWriteAltitude = camAltitude
            lastWritePitch = camPitch
        }

        // Gesture handling for seamless manual map pan/pinch/zoom
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began:
                isUserDragging = true
                if parent.isHeadingLocked {
                    DispatchQueue.main.async {
                        self.parent.isHeadingLocked = false
                    }
                }
            case .ended, .cancelled:
                isUserDragging = false
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                isUserDragging = true
                if parent.isHeadingLocked {
                    DispatchQueue.main.async {
                        self.parent.isHeadingLocked = false
                    }
                }
            case .ended, .cancelled:
                isUserDragging = false
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            if parent.isHeadingLocked {
                DispatchQueue.main.async {
                    self.parent.isHeadingLocked = false
                }
            }
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            return true
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coord = mapView.convert(point, toCoordinateFrom: mapView)
            parent.onSelectCoordinate(coord)
        }

        // Overlay updates — fast-pathed: SwiftUI re-renders at ~30Hz between
        // GPS ticks, so only recompute when the route identity or trail
        // length actually changed.
        func updateOverlays(mapView: MKMapView) {
            let nextRoute = parent.manager.activeRoute
            let crumbCount = parent.manager.breadcrumbs.count
            if nextRoute === lastOverlayRoute && crumbCount == lastOverlayCrumbs {
                return
            }
            lastOverlayRoute = nextRoute
            lastOverlayCrumbs = crumbCount

            // Navigation route
            let routePolylines = mapView.overlays.filter { ($0 as? MKPolyline)?.title != "BreadcrumbTrail" }
            if let route = parent.manager.activeRoute {
                if !routePolylines.contains(where: { ($0 as? MKPolyline) == route.polyline }) {
                    mapView.removeOverlays(routePolylines)
                    mapView.addOverlay(route.polyline, level: .aboveRoads)

                    if let dest = parent.manager.destinationMapItem {
                        let existingPins = mapView.annotations.filter { !($0 is MKUserLocation) }
                        mapView.removeAnnotations(existingPins)

                        let pin = MKPointAnnotation()
                        pin.coordinate = dest.placemark.coordinate
                        pin.title = dest.name
                        mapView.addAnnotation(pin)
                    }
                }
            } else if !routePolylines.isEmpty && parent.manager.activeRoute == nil {
                mapView.removeOverlays(routePolylines)
                let existingPins = mapView.annotations.filter { !($0 is MKUserLocation) }
                mapView.removeAnnotations(existingPins)
            }

            // Breadcrumbs update
            if parent.manager.isRecordingTrip && parent.manager.breadcrumbs.count > 1 {
                if parent.manager.breadcrumbs.count != lastBreadcrumbCount {
                    lastBreadcrumbCount = parent.manager.breadcrumbs.count
                    let coords = parent.manager.breadcrumbs.map { $0.coordinate }
                    let breadcrumbLine = MKPolyline(coordinates: coords, count: coords.count)
                    breadcrumbLine.title = "BreadcrumbTrail"

                    if let existing = mapView.overlays.first(where: { ($0 as? MKPolyline)?.title == "BreadcrumbTrail" }) {
                        mapView.removeOverlay(existing)
                    }
                    mapView.addOverlay(breadcrumbLine, level: .aboveRoads)
                }
            } else if !parent.manager.isRecordingTrip && parent.manager.breadcrumbs.isEmpty {
                if let existing = mapView.overlays.first(where: { ($0 as? MKPolyline)?.title == "BreadcrumbTrail" }) {
                    mapView.removeOverlay(existing)
                    lastBreadcrumbCount = 0
                }
            }
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
    }
}
