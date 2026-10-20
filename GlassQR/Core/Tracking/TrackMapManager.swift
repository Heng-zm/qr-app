//
//  TrackMapManager.swift
//  GlassQR
//
//  High-Precision GPS Live Telemetry, Route Navigation, Speedometer Engine,
//  and Breadcrumb Recorder for GlassQR TrackMap.
//  Operates 100% offline via hardware GNSS with zero cloud latency.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI
import Combine

// MARK: - Speed Unit

public enum SpeedUnit: String, CaseIterable, Identifiable {
    case kmh = "km/h"
    case mph = "mph"

    public var id: String { rawValue }

    public func convert(speedInMetersPerSecond mps: Double) -> Double {
        let positiveMPS = max(0, mps)
        switch self {
        case .kmh:
            return positiveMPS * 3.6
        case .mph:
            return positiveMPS * 2.23694
        }
    }

    public func formatDistance(meters: Double, isKhmer: Bool = false) -> String {
        switch self {
        case .kmh:
            if meters < 1000 {
                return String(format: "%.0f %@", meters, isKhmer ? "ម៉ែត្រ" : "m")
            } else {
                return String(format: "%.2f %@", meters / 1000.0, isKhmer ? "គ.ម" : "km")
            }
        case .mph:
            let miles = meters * 0.000621371
            if miles < 0.1 {
                let feet = meters * 3.28084
                return String(format: "%.0f %@", feet, isKhmer ? "ហ្វីត" : "ft")
            } else {
                return String(format: "%.2f %@", miles, isKhmer ? "ម៉ាយ" : "mi")
            }
        }
    }
}

// MARK: - Transport Mode

public enum TransportMode: String, CaseIterable, Identifiable {
    case automobile = "Drive"
    case walking = "Walk"
    case transit = "Transit"

    public var id: String { rawValue }

    public var mkType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }

    public var icon: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking: return "figure.walk"
        case .transit: return "tram.fill"
        }
    }

    public func localizedName(isKhmer: Bool) -> String {
        switch self {
        case .automobile: return isKhmer ? "រថយន្ត" : "Drive"
        case .walking: return isKhmer ? "ដើរ" : "Walk"
        case .transit: return isKhmer ? "រថយន្តក្រុង" : "Transit"
        }
    }
}

// MARK: - GPS Breadcrumb Point

public struct TrackBreadcrumb: Identifiable, Equatable {
    public let id = UUID()
    public let coordinate: CLLocationCoordinate2D
    public let speedKmh: Double
    public let altitudeMeters: Double
    public let timestamp: Date

    public static func == (lhs: TrackBreadcrumb, rhs: TrackBreadcrumb) -> Bool {
        lhs.id == rhs.id
    }

    public var speedColor: Color {
        if speedKmh < 25 {
            return Color.cyan
        } else if speedKmh < 60 {
            return Color.green
        } else if speedKmh < 90 {
            return Color.yellow
        } else if speedKmh < 120 {
            return Color.orange
        } else {
            return Color.red
        }
    }
}

// MARK: - Navigation Step

public struct RouteStepItem: Identifiable, Equatable {
    public let id = UUID()
    public let instructions: String
    public let distanceMeters: Double
    public let notice: String?
    public let startCoordinate: CLLocationCoordinate2D?
    public let endCoordinate: CLLocationCoordinate2D?
    public let maneuverIcon: String

    public static func == (lhs: RouteStepItem, rhs: RouteStepItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - TrackMap Telemetry Manager

public final class TrackMapManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = TrackMapManager()

    // MARK: - Published Telemetry Metrics
    @Published public var currentLocation: CLLocation?
    @Published public var currentCoordinate: CLLocationCoordinate2D?
    @Published public var currentSpeed: Double = 0.0 // in active unit
    @Published public var currentSpeedMPS: Double = 0.0 // raw m/s
    @Published public var topSpeed: Double = 0.0 // in active unit
    @Published public var averageSpeed: Double = 0.0 // in active unit
    @Published public var totalDistanceMeters: Double = 0.0
    @Published public var currentAltitudeMeters: Double = 0.0
    @Published public var headingDegrees: Double = 0.0
    @Published public var accelerationG: Double = 0.0 // estimated G-force
    @Published public var isOverspeed: Bool = false
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined

    // Settings
    @Published public var unit: SpeedUnit = .kmh
    @Published public var speedLimit: Double = 80.0 // in active unit
    @Published public var isSpeedLimitAlertEnabled: Bool = true
    @Published public var isRecordingTrip: Bool = false
    @Published public var tripElapsedTime: TimeInterval = 0.0

    // Breadcrumbs & Navigation
    @Published public var breadcrumbs: [TrackBreadcrumb] = []
    @Published public var activeRoute: MKRoute?
    @Published public var alternateRoutes: [MKRoute] = []
    @Published public var selectedRouteIndex: Int = 0
    @Published public var routeSteps: [RouteStepItem] = []
    @Published public var destinationMapItem: MKMapItem?
    @Published public var isCalculatingRoute: Bool = false
    @Published public var navigationNotice: String?

    // Live Turn-by-Turn Route Tracking
    @Published public var transportMode: TransportMode = .automobile
    @Published public var currentStepIndex: Int = 0
    @Published public var distanceToNextStep: Double = 0.0 // in meters
    @Published public var distanceToDestination: Double = 0.0 // in meters
    @Published public var estimatedTimeRemaining: TimeInterval = 0.0 // in seconds
    @Published public var currentManeuverIcon: String = "arrow.up"
    @Published public var isOffRoute: Bool = false
    @Published public var hasArrivedAtDestination: Bool = false
    @Published public var routeProgressPercentage: Double = 0.0
    @Published public var routeOverviewFitTrigger: Int = 0

    // Simulation / Demo Mode
    @Published public var isSimulating: Bool = false

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var tripTimer: Timer?

    /// Cached haptics: allocating a generator per event adds latency to every buzz.
    private let notificationHaptics = UINotificationFeedbackGenerator()
    private let impactHaptics = UIImpactFeedbackGenerator(style: .medium)
    private var simulationTimer: Timer?
    private var previousSpeedMPS: Double = 0.0
    private var previousSpeedTimestamp: Date?
    private var simulatedHeading: Double = 45.0
    private var simulatedSpeedMPS: Double = 0.0
    private var simulatedCoord = CLLocationCoordinate2D(latitude: 11.5564, longitude: 104.9282) // Phnom Penh center
    private var isHeadingInitialized: Bool = false
    private var simulatedSimTime: TimeInterval = 0.0

    // Route tracking internals
    private var activeDirectionsTask: MKDirections?
    private var offRouteCount: Int = 0
    private var lastRerouteTimestamp: Date = .distantPast
    private var simulatedRouteCoords: [CLLocationCoordinate2D] = []
    private var simulatedRoutePointIndex: Int = 0

    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0 // updates every 2 meters
        locationManager.headingFilter = 2.0 // updates every 2 degrees
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = false
    }

    // MARK: - Start / Stop Telemetry

    public func startTracking() {
        let status = locationManager.authorizationStatus
        authorizationStatus = status

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        case .denied, .restricted:
            navigationNotice = "Location permission denied. Enable in iOS Settings to track GPS speed."
        @unknown default:
            break
        }
    }

    public func stopTracking() {
        guard !isSimulating else { return }
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Trip Recording Controls

    public func startTripRecording() {
        isRecordingTrip = true
        tripElapsedTime = 0.0
        totalDistanceMeters = 0.0
        topSpeed = 0.0
        averageSpeed = 0.0
        breadcrumbs.removeAll()

        tripTimer?.invalidate()
        tripTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingTrip else { return }
            self.tripElapsedTime += 1.0
            self.updateAverageSpeed()
        }
    }

    public func pauseTripRecording() {
        isRecordingTrip = false
        tripTimer?.invalidate()
        tripTimer = nil
    }

    public func resumeTripRecording() {
        isRecordingTrip = true
        tripTimer?.invalidate()
        tripTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isRecordingTrip else { return }
            self.tripElapsedTime += 1.0
            self.updateAverageSpeed()
        }
    }

    public func resetTrip() {
        isRecordingTrip = false
        tripTimer?.invalidate()
        tripTimer = nil
        tripElapsedTime = 0.0
        totalDistanceMeters = 0.0
        topSpeed = 0.0
        averageSpeed = 0.0
        breadcrumbs.removeAll()
        activeRoute = nil
        routeSteps.removeAll()
        destinationMapItem = nil
    }

    private func updateAverageSpeed() {
        guard tripElapsedTime > 2 else { return }
        let avgMPS = totalDistanceMeters / tripElapsedTime
        averageSpeed = unit.convert(speedInMetersPerSecond: avgMPS)
    }

    // MARK: - GPX Trail Export

    /// Serializes the recorded breadcrumbs as a GPX 1.1 document (ele + time per
    /// point; spec-clean for Strava / Google Earth / Garmin imports).
    /// Returns nil while nothing meaningful has been recorded yet.
    public func buildGPXDocument() -> String? {
        guard breadcrumbs.count > 1 else { return nil }

        let timeFormatter = ISO8601DateFormatter()

        var gpx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="GlassQR">
          <trk>
            <name>GlassQR Trip</name>
            <trkseg>
        """
        gpx.reserveCapacity(160 + breadcrumbs.count * 150)

        for point in breadcrumbs {
            gpx += "\n      <trkpt lat=\"\(String(format: "%.6f", point.coordinate.latitude))\" lon=\"\(String(format: "%.6f", point.coordinate.longitude))\">"
            gpx += "\n        <ele>\(String(format: "%.1f", point.altitudeMeters))</ele>"
            gpx += "\n        <time>\(timeFormatter.string(from: point.timestamp))</time>"
            gpx += "\n      </trkpt>"
        }

        gpx += "\n    </trkseg>\n  </trk>\n</gpx>"
        return gpx
    }

    // MARK: - Unit Switcher

    public func setUnit(_ newUnit: SpeedUnit) {
        let oldUnit = unit
        guard oldUnit != newUnit else { return }

        // Recalculate metrics in new unit
        currentSpeed = newUnit.convert(speedInMetersPerSecond: currentSpeedMPS)
        if newUnit == .kmh {
            speedLimit = (speedLimit * 1.60934).rounded()
            topSpeed = topSpeed * 1.60934
            averageSpeed = averageSpeed * 1.60934
        } else {
            speedLimit = (speedLimit * 0.621371).rounded()
            topSpeed = topSpeed * 0.621371
            averageSpeed = averageSpeed * 0.621371
        }
        unit = newUnit
        checkOverspeed()
    }

    // MARK: - Route Navigation & Maneuver Parsing

    public static func parseManeuverIcon(from instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("u-turn") || lower.contains("uturn") {
            return "arrow.uturn.backward"
        } else if lower.contains("sharp left") {
            return "arrow.turn.down.left"
        } else if lower.contains("sharp right") {
            return "arrow.turn.down.right"
        } else if lower.contains("slight left") || lower.contains("bear left") {
            return "arrow.up.left"
        } else if lower.contains("slight right") || lower.contains("bear right") {
            return "arrow.up.right"
        } else if lower.contains("keep left") {
            // must be tested before the generic "left" pattern
            return "arrow.left"
        } else if lower.contains("keep right") {
            return "arrow.right"
        } else if lower.contains("left") {
            return "arrow.turn.up.left"
        } else if lower.contains("right") {
            return "arrow.turn.up.right"
        } else if lower.contains("roundabout") || lower.contains("rotary") || lower.contains("traffic circle") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("ramp") || lower.contains("merge") || lower.contains("exit") {
            return "arrow.triangle.merge"
        } else if lower.contains("arrive") || lower.contains("destination") || lower.contains("reach") {
            return "flag.checkered"
        } else if lower.contains("keep left") {
            return "arrow.left"
        } else if lower.contains("keep right") {
            return "arrow.right"
        } else {
            return "arrow.up"
        }
    }

    public func calculateRoute(
        to destination: MKMapItem,
        transportType: MKDirectionsTransportType? = nil,
        mode: TransportMode? = nil,
        autoFrameOverview: Bool = true
    ) {
        if let mode = mode {
            self.transportMode = mode
        } else if let transportType = transportType {
            switch transportType {
            case .walking: self.transportMode = .walking
            case .transit: self.transportMode = .transit
            default: self.transportMode = .automobile
            }
        }

        activeDirectionsTask?.cancel()

        let sourceLocation: MKMapItem
        if let currentCoord = currentCoordinate {
            let placemark = MKPlacemark(coordinate: currentCoord)
            sourceLocation = MKMapItem(placemark: placemark)
        } else {
            sourceLocation = MKMapItem.forCurrentLocation()
        }

        let request = MKDirections.Request()
        request.source = sourceLocation
        request.destination = destination
        request.transportType = self.transportMode.mkType
        request.requestsAlternateRoutes = true

        isCalculatingRoute = true
        destinationMapItem = destination

        let directions = MKDirections(request: request)
        activeDirectionsTask = directions

        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCalculatingRoute = false

                if let error = error {
                    let nsError = error as NSError
                    if nsError.code == NSURLErrorCancelled {
                        return
                    }
                    // MapKit reports unavailable/undrawable routes (e.g. transit
                    // beyond its limits, walking distance restrictions) as
                    // DirectionsNotFound with a raw message no driver can act on.
                    if nsError.domain == MKErrorDomain && nsError.code == MKError.Code.directionsNotFound.rawValue {
                        self.navigationNotice = self.transportMode == .transit
                            ? "No transit route was found. Try Drive or Walk mode."
                            : "No route was found for this trip."
                        return
                    }
                    self.navigationNotice = "Route error: \(nsError.localizedDescription)"
                    return
                }

                guard let routes = response?.routes, !routes.isEmpty else {
                    self.navigationNotice = "No route found to destination."
                    return
                }

                self.alternateRoutes = routes
                self.selectedRouteIndex = 0
                self.applyActiveRoute(routes[0], autoFrameOverview: autoFrameOverview)
                self.navigationNotice = nil
            }
        }
    }

    public func selectRoute(at index: Int) {
        guard index >= 0 && index < alternateRoutes.count else { return }
        selectedRouteIndex = index
        applyActiveRoute(alternateRoutes[index], autoFrameOverview: false)
    }

    private func applyActiveRoute(_ route: MKRoute, autoFrameOverview: Bool) {
        self.activeRoute = route
        self.currentStepIndex = 0
        self.hasArrivedAtDestination = false
        self.isOffRoute = false
        self.offRouteCount = 0
        self.distanceToDestination = route.distance
        self.estimatedTimeRemaining = route.expectedTravelTime
        self.routeProgressPercentage = 0.0

        var steps: [RouteStepItem] = []
        // MKRoute can contain instruction-less "spacer" steps (mostly transit).
        // Fold their distances forward into the next guided step so the remaining
        // distance math in processRouteProgress stays consistent with route.distance.
        var pendingDistance: Double = 0.0
        for step in route.steps {
            let trimmed = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                pendingDistance += step.distance
                continue
            }

            let points = step.polyline.points()
            let count = step.polyline.pointCount
            let startCoord = count > 0 ? points[0].coordinate : nil
            let endCoord = count > 0 ? points[count - 1].coordinate : nil
            let icon = Self.parseManeuverIcon(from: trimmed)

            steps.append(
                RouteStepItem(
                    instructions: trimmed,
                    distanceMeters: step.distance + pendingDistance,
                    notice: step.notice,
                    startCoordinate: startCoord,
                    endCoordinate: endCoord,
                    maneuverIcon: icon
                )
            )
            pendingDistance = 0
        }
        self.routeSteps = steps

        if let first = steps.first {
            self.distanceToNextStep = first.distanceMeters
            self.currentManeuverIcon = first.maneuverIcon
        } else {
            self.distanceToNextStep = 0.0
            self.currentManeuverIcon = "arrow.up"
        }

        if autoFrameOverview {
            self.routeOverviewFitTrigger += 1
        }

        if self.isSimulating {
            self.setupSimulatedRoute(route)
        }
    }

    public func clearActiveRoute() {
        activeDirectionsTask?.cancel()
        activeDirectionsTask = nil
        activeRoute = nil
        alternateRoutes.removeAll()
        routeSteps.removeAll()
        destinationMapItem = nil
        currentStepIndex = 0
        distanceToNextStep = 0.0
        distanceToDestination = 0.0
        estimatedTimeRemaining = 0.0
        routeProgressPercentage = 0.0
        isOffRoute = false
        hasArrivedAtDestination = false
        simulatedRouteCoords.removeAll()
        simulatedRoutePointIndex = 0
    }

    public func recalculateRouteSilently() {
        guard let dest = destinationMapItem else { return }
        calculateRoute(to: dest, mode: transportMode, autoFrameOverview: false)
    }

    // MARK: - Live Turn-by-Turn Progress Tracking

    public func processRouteProgress(location: CLLocation) {
        guard let route = activeRoute, !routeSteps.isEmpty else { return }
        guard !hasArrivedAtDestination else { return }

        let userMapPoint = MKMapPoint(location.coordinate)

        // 1. Destination Arrival Check
        if let destCoord = destinationMapItem?.placemark.coordinate {
            let distToDest = location.distance(from: CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude))
            if distToDest < 28.0 || (distToDest < 45.0 && currentStepIndex >= routeSteps.count - 1) {
                hasArrivedAtDestination = true
                distanceToDestination = 0.0
                estimatedTimeRemaining = 0.0
                routeProgressPercentage = 1.0
                currentManeuverIcon = "flag.checkered"
                notificationHaptics.notificationOccurred(.success)
                return
            }
        }

        // 2. Off-Route Detection (Perpendicular Distance to Route Polyline)
        let minDistanceToPolyline = distanceToPolyline(point: userMapPoint, polyline: route.polyline)
        let offRouteThreshold: Double = (transportMode == .walking) ? 45.0 : 70.0

        if minDistanceToPolyline > offRouteThreshold && currentSpeedMPS > 1.2 {
            offRouteCount += 1
            if offRouteCount >= 3 && !isOffRoute {
                isOffRoute = true
                notificationHaptics.notificationOccurred(.warning)
                if Date().timeIntervalSince(lastRerouteTimestamp) > 10.0 {
                    lastRerouteTimestamp = Date()
                    recalculateRouteSilently()
                }
            }
        } else {
            if offRouteCount > 0 {
                offRouteCount = max(0, offRouteCount - 1)
            }
            if offRouteCount == 0 && isOffRoute {
                isOffRoute = false
            }
        }

        // 3. Current Step Advancement & Distance to Turn
        if currentStepIndex < routeSteps.count {
            let currentStep = routeSteps[currentStepIndex]

            if let endCoord = currentStep.endCoordinate {
                let distToEnd = location.distance(from: CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude))
                distanceToNextStep = distToEnd

                let advanceThreshold: Double = (currentSpeedMPS > 12.0) ? 35.0 : 25.0
                if distToEnd < advanceThreshold {
                    advanceToNextStep()
                }
            } else {
                distanceToNextStep = currentStep.distanceMeters
            }

            currentManeuverIcon = currentStep.maneuverIcon
        }

        // 4. Calculate Remaining Distance to Destination
        var remainingDist: Double = distanceToNextStep
        if currentStepIndex + 1 < routeSteps.count {
            for i in (currentStepIndex + 1)..<routeSteps.count {
                remainingDist += routeSteps[i].distanceMeters
            }
        }
        self.distanceToDestination = remainingDist

        // 5. Dynamic Journey Progress Percentage
        let totalDist = max(1.0, route.distance)
        let progress = max(0.0, min(1.0, 1.0 - (remainingDist / totalDist)))
        self.routeProgressPercentage = progress

        // 6. Dynamic ETA Calculation
        if currentSpeedMPS > 2.5 {
            let instantaneousETA = remainingDist / currentSpeedMPS
            let baselineETA = route.expectedTravelTime * (remainingDist / totalDist)
            self.estimatedTimeRemaining = instantaneousETA * 0.4 + baselineETA * 0.6
        } else {
            self.estimatedTimeRemaining = route.expectedTravelTime * (remainingDist / totalDist)
        }
    }

    private func advanceToNextStep() {
        guard currentStepIndex + 1 < routeSteps.count else { return }
        currentStepIndex += 1
        let nextStep = routeSteps[currentStepIndex]
        currentManeuverIcon = nextStep.maneuverIcon
        if let end = nextStep.endCoordinate, let cur = currentLocation {
            distanceToNextStep = cur.distance(from: CLLocation(latitude: end.latitude, longitude: end.longitude))
        } else {
            distanceToNextStep = nextStep.distanceMeters
        }
        impactHaptics.impactOccurred()
    }

    private func distanceToPolyline(point: MKMapPoint, polyline: MKPolyline) -> Double {
        let count = polyline.pointCount
        guard count > 1 else { return 0.0 }
        let points = polyline.points()

        var minDistance = Double.greatestFiniteMagnitude

        for i in 0..<(count - 1) {
            let p1 = points[i]
            let p2 = points[i + 1]

            let dx = p2.x - p1.x
            let dy = p2.y - p1.y
            let lenSq = dx * dx + dy * dy

            let closestPoint: MKMapPoint
            if lenSq == 0 {
                closestPoint = p1
            } else {
                let t = max(0.0, min(1.0, ((point.x - p1.x) * dx + (point.y - p1.y) * dy) / lenSq))
                closestPoint = MKMapPoint(x: p1.x + t * dx, y: p1.y + t * dy)
            }

            let dist = point.distance(to: closestPoint)
            if dist < minDistance {
                minDistance = dist
            }
        }

        return minDistance
    }

    // MARK: - ETA Formatting Helpers

    /// Cached: this helper runs on every telemetry tick (~30 Hz in simulation),
    /// so allocating a DateFormatter per call would churn the heap each frame.
    private static let etaClockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    public func formattedETAClock() -> String {
        guard estimatedTimeRemaining > 0 else { return "--:--" }
        let arrivalDate = Date().addingTimeInterval(estimatedTimeRemaining)
        return Self.etaClockFormatter.string(from: arrivalDate)
    }

    public func formattedDurationRemaining(isKhmer: Bool = false) -> String {
        let totalSeconds = Int(max(0, estimatedTimeRemaining))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return isKhmer ? "\(hours) ម៉ោង \(minutes) នាទី" : "\(hours) hr \(minutes) min"
        } else {
            return isKhmer ? "\(max(1, minutes)) នាទី" : "\(max(1, minutes)) min"
        }
    }

    // MARK: - CLLocationManagerDelegate
    //
    // CLLocationManager delivers delegate callbacks on the thread that created
    // it. TrackMapManager.shared is first created by SwiftUI on the main thread,
    // so every callback below — including its @Published writes — runs on main.

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isSimulating else { return }
        guard let location = locations.last else { return }

        processLocationUpdate(location)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard !isSimulating else { return }
        if newHeading.headingAccuracy >= 0 {
            let raw = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
            // When moving at speed (e.g. driving/cycling), GPS course provides superior forward vector stability.
            // When stopped or walking slowly, filtered magnetic heading smoothly guides orientation.
            if currentSpeedMPS < 1.8 {
                filterAndApplyHeading(raw, responsiveness: 0.28)
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignored or logged gracefully
    }

    // MARK: - Circular EMA Compass & Course Filter

    public func filterAndApplyHeading(_ raw: Double, responsiveness: Double = 0.28) {
        guard raw >= 0.0 && raw <= 360.0 else { return }

        if !isHeadingInitialized {
            headingDegrees = raw
            isHeadingInitialized = true
            return
        }

        var delta = (raw - headingDegrees).truncatingRemainder(dividingBy: 360.0)
        if delta > 180.0 { delta -= 360.0 }
        if delta < -180.0 { delta += 360.0 }

        // Adaptive low-pass filter:
        // - Small tremors (< 6°): Heavy damping (alpha = 0.16) to eliminate magnetic sensor jitter
        // - Medium turns (6° - 35°): Smooth tracking (alpha = responsiveness)
        // - Quick sharp turns (> 35°): Snappy tracking (alpha = 0.65) so no lag on 90° intersection turns
        let absDelta = abs(delta)
        let alpha: Double
        if absDelta > 35.0 {
            alpha = 0.65
        } else if absDelta > 6.0 {
            alpha = responsiveness
        } else {
            alpha = 0.16
        }

        var updated = headingDegrees + delta * alpha
        if updated < 0.0 { updated += 360.0 }
        if updated >= 360.0 { updated -= 360.0 }

        headingDegrees = updated
    }

    // MARK: - Core Processing Logic

    private func processLocationUpdate(_ location: CLLocation) {
        currentLocation = location
        currentCoordinate = location.coordinate
        currentAltitudeMeters = max(0, location.altitude)

        let rawSpeedMPS = max(0, location.speed)
        currentSpeedMPS = rawSpeedMPS
        let convertedSpeed = unit.convert(speedInMetersPerSecond: rawSpeedMPS)
        currentSpeed = convertedSpeed

        // Blend GPS Doppler course when moving at speed (> 1.8 m/s = ~6.5 km/h)
        if location.course >= 0.0 && rawSpeedMPS >= 1.8 {
            filterAndApplyHeading(location.course, responsiveness: 0.38)
        }

        // Update Top Speed
        if convertedSpeed > topSpeed {
            topSpeed = convertedSpeed
        }

        // Distance accumulator
        if let previous = lastLocation {
            let delta = location.distance(from: previous)
            let minDelta = isSimulating ? 0.05 : 1.2
            if delta > minDelta && delta < 500 { // sanity checks against GPS jumps
                totalDistanceMeters += delta
            }
        }
        lastLocation = location

        // Calculate Estimated Acceleration & G-Force
        let now = Date()
        if let prevTime = previousSpeedTimestamp {
            let dt = now.timeIntervalSince(prevTime)
            if dt > 0.3 {
                let dv = rawSpeedMPS - previousSpeedMPS
                let accel = dv / dt
                let g = accel / 9.80665
                accelerationG = max(-1.5, min(1.5, g))
                previousSpeedMPS = rawSpeedMPS
                previousSpeedTimestamp = now
            }
        } else {
            previousSpeedMPS = rawSpeedMPS
            previousSpeedTimestamp = now
        }

        // Append Breadcrumb if recording
        if isRecordingTrip {
            let breadcrumb = TrackBreadcrumb(
                coordinate: location.coordinate,
                speedKmh: rawSpeedMPS * 3.6,
                altitudeMeters: location.altitude,
                timestamp: now
            )
            // Throttle points to keep rendering 60fps silky smooth
            if breadcrumbs.isEmpty || (breadcrumbs.last.map { location.distance(from: CLLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude)) > 3.0 } ?? true) {
                breadcrumbs.append(breadcrumb)
            }
        }

        checkOverspeed()
        processRouteProgress(location: location)
    }

    private func checkOverspeed() {
        if isSpeedLimitAlertEnabled && currentSpeed > speedLimit {
            if !isOverspeed {
                isOverspeed = true
                notificationHaptics.notificationOccurred(.warning)
            }
        } else {
            isOverspeed = false
        }
    }

    // MARK: - Compass Cardinal Converter

    public var compassCardinal: String {
        let degrees = headingDegrees
        switch degrees {
        case 22.5..<67.5: return "NE"
        case 67.5..<112.5: return "E"
        case 112.5..<157.5: return "SE"
        case 157.5..<202.5: return "S"
        case 202.5..<247.5: return "SW"
        case 247.5..<292.5: return "W"
        case 292.5..<337.5: return "NW"
        default: return "N"
        }
    }

    public func compassCardinalKhmer() -> String {
        let degrees = headingDegrees
        switch degrees {
        case 22.5..<67.5: return "ឦសាន"
        case 67.5..<112.5: return "បូព៌ា (កើត)"
        case 112.5..<157.5: return "អាគ្នេយ៍"
        case 157.5..<202.5: return "ទក្សិណ (ត្បូង)"
        case 202.5..<247.5: return "និរតី"
        case 247.5..<292.5: return "បច្ចឹម (លិច)"
        case 292.5..<337.5: return "ពាយ័ព្យ"
        default: return "ឧត្តរ (ជើង)"
        }
    }

    // MARK: - Simulated Driving & Route Kinematics (For Simulator & Indoors)

    public func setupSimulatedRoute(_ route: MKRoute) {
        let count = route.polyline.pointCount
        guard count > 1 else { return }
        let points = route.polyline.points()
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(count)
        for i in 0..<count {
            coords.append(points[i].coordinate)
        }
        self.simulatedRouteCoords = coords
        self.simulatedRoutePointIndex = 0
        if let first = coords.first {
            self.simulatedCoord = first
            self.currentCoordinate = first
        }
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lon1 = from.longitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let lon2 = to.longitude * .pi / 180.0

        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let radians = atan2(y, x)
        var degrees = radians * 180.0 / .pi
        if degrees < 0 { degrees += 360.0 }
        return degrees
    }

    public func toggleSimulation() {
        if isSimulating {
            stopSimulation()
        } else {
            startSimulation()
        }
    }

    public func startSimulation() {
        isSimulating = true
        simulatedSpeedMPS = 0.0
        simulatedHeading = 35.0
        simulatedSimTime = 0.0

        if let route = activeRoute, simulatedRouteCoords.isEmpty {
            setupSimulatedRoute(route)
        }

        if currentCoordinate == nil {
            currentCoordinate = simulatedCoord
        } else if simulatedRouteCoords.isEmpty {
            simulatedCoord = currentCoordinate!
        }

        if !isRecordingTrip {
            // A paused trip survives simulation start — only a fresh trip begins recording.
            if tripElapsedTime > 0 {
                resumeTripRecording()
            } else {
                startTripRecording()
            }
        }

        simulationTimer?.invalidate()
        let tickInterval: TimeInterval = 0.033 // High-refresh 30Hz simulation loop for 60fps tracking
        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isSimulating else { return }

            self.simulatedSimTime += tickInterval

            // Mode A: Realistic Route-Following Navigation Simulation
            if !self.simulatedRouteCoords.isEmpty && self.simulatedRoutePointIndex < self.simulatedRouteCoords.count - 1 {
                let nextTarget = self.simulatedRouteCoords[self.simulatedRoutePointIndex + 1]
                let fromLoc = CLLocation(latitude: self.simulatedCoord.latitude, longitude: self.simulatedCoord.longitude)
                let toLoc = CLLocation(latitude: nextTarget.latitude, longitude: nextTarget.longitude)
                let distToSegmentEnd = fromLoc.distance(from: toLoc)

                // Realistic transport speed
                let cruiseSpeedKmh: Double
                switch self.transportMode {
                case .walking: cruiseSpeedKmh = 5.2
                case .transit: cruiseSpeedKmh = 38.0 + sin(self.simulatedSimTime * 0.4) * 8.0
                case .automobile: cruiseSpeedKmh = 58.0 + sin(self.simulatedSimTime * 0.3) * 12.0
                }
                let targetMPS = max(0.5, cruiseSpeedKmh / 3.6)
                self.simulatedSpeedMPS += (targetMPS - self.simulatedSpeedMPS) * 0.08

                let stepDistance = self.simulatedSpeedMPS * tickInterval
                let targetBearing = self.calculateBearing(from: self.simulatedCoord, to: nextTarget)
                self.filterAndApplyHeading(targetBearing, responsiveness: 0.38)

                if distToSegmentEnd <= stepDistance || distToSegmentEnd < 1.0 {
                    self.simulatedCoord = nextTarget
                    self.simulatedRoutePointIndex += 1
                } else {
                    let fraction = stepDistance / distToSegmentEnd
                    self.simulatedCoord.latitude += (nextTarget.latitude - self.simulatedCoord.latitude) * fraction
                    self.simulatedCoord.longitude += (nextTarget.longitude - self.simulatedCoord.longitude) * fraction
                }

                let simLocation = CLLocation(
                    coordinate: self.simulatedCoord,
                    altitude: 28.0 + sin(self.simulatedSimTime * 0.08) * 4.0,
                    horizontalAccuracy: 2.5,
                    verticalAccuracy: 2.5,
                    course: self.headingDegrees,
                    speed: self.simulatedSpeedMPS,
                    timestamp: Date()
                )
                self.processLocationUpdate(simLocation)
                return
            }

            // Mode B: Free-Drive Kinematics Simulator (When no route is active)
            let targetSpeedKmh = 70.0 + sin(self.simulatedSimTime * 0.35) * 25.0 + cos(self.simulatedSimTime * 0.12) * 10.0
            let targetMPS = max(0, targetSpeedKmh / 3.6)
            self.simulatedSpeedMPS += (targetMPS - self.simulatedSpeedMPS) * 0.035

            self.simulatedHeading += sin(self.simulatedSimTime * 0.22) * 0.45
            if self.simulatedHeading < 0 { self.simulatedHeading += 360.0 }
            if self.simulatedHeading >= 360.0 { self.simulatedHeading -= 360.0 }
            self.headingDegrees = self.simulatedHeading

            let distance = self.simulatedSpeedMPS * tickInterval
            let bearingRad = self.simulatedHeading * .pi / 180.0
            let earthRadius = 6378137.0
            let dLat = (distance * cos(bearingRad)) / earthRadius
            let dLon = (distance * sin(bearingRad)) / (earthRadius * cos(self.simulatedCoord.latitude * .pi / 180.0))

            self.simulatedCoord.latitude += dLat * (180.0 / .pi)
            self.simulatedCoord.longitude += dLon * (180.0 / .pi)

            let simLocation = CLLocation(
                coordinate: self.simulatedCoord,
                altitude: 28.0 + sin(self.simulatedSimTime * 0.08) * 8.0,
                horizontalAccuracy: 2.5,
                verticalAccuracy: 2.5,
                course: self.simulatedHeading,
                speed: self.simulatedSpeedMPS,
                timestamp: Date()
            )

            self.processLocationUpdate(simLocation)
        }
    }

    public func stopSimulation() {
        isSimulating = false
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulatedSimTime = 0.0
        currentSpeed = 0.0
        currentSpeedMPS = 0.0
    }

    // MARK: - Export Trip & Geo-QR Generation

    public func exportTripSummary() -> String {
        let distStr = unit.formatDistance(meters: totalDistanceMeters)
        let hours = Int(tripElapsedTime) / 3600
        let minutes = (Int(tripElapsedTime) % 3600) / 60
        let seconds = Int(tripElapsedTime) % 60
        let timeStr = String(format: "%02d:%02d:%02d", hours, minutes, seconds)

        return """
        GlassQR TrackMap Telemetry:
        • Total Distance: \(distStr)
        • Duration: \(timeStr)
        • Top Speed: \(String(format: "%.1f", topSpeed)) \(unit.rawValue)
        • Average Speed: \(String(format: "%.1f", averageSpeed)) \(unit.rawValue)
        • Final Altitude: \(String(format: "%.0f", currentAltitudeMeters)) m
        """
    }

    public func generateGeoQRData() -> String {
        guard let coord = currentCoordinate else {
            return "https://maps.apple.com/?ll=11.5564,104.9282&q=Phnom+Penh"
        }
        return "https://maps.apple.com/?ll=\(coord.latitude),\(coord.longitude)&q=TrackMap+Pin"
    }
}
