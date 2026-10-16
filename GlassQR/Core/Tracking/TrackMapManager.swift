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

public struct RouteStepItem: Identifiable {
    public let id = UUID()
    public let instructions: String
    public let distanceMeters: Double
    public let notice: String?
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
    @Published public var routeSteps: [RouteStepItem] = []
    @Published public var destinationMapItem: MKMapItem?
    @Published public var isCalculatingRoute: Bool = false
    @Published public var navigationNotice: String?

    // Simulation / Demo Mode
    @Published public var isSimulating: Bool = false

    private let locationManager = CLLocationManager()
    private var lastLocation: CLLocation?
    private var tripTimer: Timer?
    private var simulationTimer: Timer?
    private var previousSpeedMPS: Double = 0.0
    private var previousSpeedTimestamp: Date?
    private var simulatedHeading: Double = 45.0
    private var simulatedSpeedMPS: Double = 0.0
    private var simulatedCoord = CLLocationCoordinate2D(latitude: 11.5564, longitude: 104.9282) // Phnom Penh center

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

    // MARK: - Route Navigation (Like Google Maps)

    public func calculateRoute(to destination: MKMapItem, transportType: MKDirectionsTransportType = .automobile) {
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
        request.transportType = transportType
        request.requestsAlternateRoutes = false

        isCalculatingRoute = true
        destinationMapItem = destination

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isCalculatingRoute = false

                if let error = error {
                    self.navigationNotice = "Route error: \(error.localizedDescription)"
                    return
                }

                guard let route = response?.routes.first else {
                    self.navigationNotice = "No route found to destination."
                    return
                }

                self.activeRoute = route
                self.routeSteps = route.steps.compactMap { step in
                    guard !step.instructions.isEmpty else { return nil }
                    return RouteStepItem(
                        instructions: step.instructions,
                        distanceMeters: step.distance,
                        notice: step.notice
                    )
                }
                self.navigationNotice = nil
            }
        }
    }

    public func clearActiveRoute() {
        activeRoute = nil
        routeSteps.removeAll()
        destinationMapItem = nil
    }

    // MARK: - CLLocationManagerDelegate

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
            headingDegrees = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignored or logged gracefully
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

        // Update Top Speed
        if convertedSpeed > topSpeed {
            topSpeed = convertedSpeed
        }

        // Distance accumulator
        if let previous = lastLocation {
            let delta = location.distance(from: previous)
            if delta > 1.5 && delta < 500 { // sanity checks against GPS jumps
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
    }

    private func checkOverspeed() {
        if isSpeedLimitAlertEnabled && currentSpeed > speedLimit {
            if !isOverspeed {
                isOverspeed = true
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
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

    // MARK: - Simulated Driving Demo Mode (For Simulator & Indoors)

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
        if currentCoordinate == nil {
            currentCoordinate = simulatedCoord
        } else {
            simulatedCoord = currentCoordinate!
        }

        if !isRecordingTrip {
            startTripRecording()
        }

        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, self.isSimulating else { return }

            // Dynamic realistic speed curves (cruising between 45 and 95 km/h, occasional slowdowns)
            let targetSpeedKmh = 72.0 + sin(self.tripElapsedTime * 0.4) * 28.0 + cos(self.tripElapsedTime * 0.15) * 12.0
            let targetMPS = max(0, targetSpeedKmh / 3.6)
            self.simulatedSpeedMPS += (targetMPS - self.simulatedSpeedMPS) * 0.12

            // Curve heading slowly
            self.simulatedHeading += sin(self.tripElapsedTime * 0.25) * 3.5
            if self.simulatedHeading < 0 { self.simulatedHeading += 360 }
            if self.simulatedHeading >= 360 { self.simulatedHeading -= 360 }
            self.headingDegrees = self.simulatedHeading

            // Move coordinates forward
            let distance = self.simulatedSpeedMPS * 0.25
            let bearingRad = self.simulatedHeading * .pi / 180.0
            let earthRadius = 6378137.0
            let dLat = (distance * cos(bearingRad)) / earthRadius
            let dLon = (distance * sin(bearingRad)) / (earthRadius * cos(self.simulatedCoord.latitude * .pi / 180.0))

            self.simulatedCoord.latitude += dLat * (180.0 / .pi)
            self.simulatedCoord.longitude += dLon * (180.0 / .pi)

            let simLocation = CLLocation(
                coordinate: self.simulatedCoord,
                altitude: 28.0 + sin(self.tripElapsedTime * 0.1) * 8.0,
                horizontalAccuracy: 3.0,
                verticalAccuracy: 3.0,
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
