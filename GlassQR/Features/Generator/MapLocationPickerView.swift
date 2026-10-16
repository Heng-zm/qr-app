//
//  MapLocationPickerView.swift
//  GlassQR
//
//  Interactive Apple Maps Pin Dropper & Geocoding Studio
//  Supports tap-to-drop, long-press drop, draggable markers, satellite view,
//  and instant reverse geocoding with zero rate-limit churn.
//

import SwiftUI
import MapKit
import CoreLocation

public struct MapLocationPickerView: View {
    @Binding var isPresented: Bool
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var locationName: String
    public var onLocationSelected: ((Double, Double, String) -> Void)?

    @State private var droppedCoordinate: CLLocationCoordinate2D?
    @State private var region: MKCoordinateRegion
    @State private var mapType: MKMapType = .standard
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [MKMapItem] = []
    @State private var reverseGeocodedAddress: String = ""
    @State private var isReverseGeocoding: Bool = false
    @State private var geocodeTask: Task<Void, Never>? = nil

    private let locationManager = CLLocationManager()

    public init(
        isPresented: Binding<Bool>,
        latitude: Binding<Double>,
        longitude: Binding<Double>,
        locationName: Binding<String>,
        onLocationSelected: ((Double, Double, String) -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self._latitude = latitude
        self._longitude = longitude
        self._locationName = locationName
        self.onLocationSelected = onLocationSelected

        let initialLat = latitude.wrappedValue != 0 ? latitude.wrappedValue : 37.3346
        let initialLon = longitude.wrappedValue != 0 ? longitude.wrappedValue : -122.0090
        let initialCoord = CLLocationCoordinate2D(latitude: initialLat, longitude: initialLon)

        self._droppedCoordinate = State(initialValue: initialCoord)
        self._region = State(initialValue: MKCoordinateRegion(
            center: initialCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Interactive Apple Map with Tap/Long-Press Marker Dropping
                DroppableMapViewRepresentable(
                    droppedCoordinate: $droppedCoordinate,
                    region: $region,
                    mapType: mapType,
                    onMarkerDropped: { newCoordinate in
                        reverseGeocode(coordinate: newCoordinate)
                    }
                )
                .ignoresSafeArea(edges: .bottom)

                // Floating Map Controls Toolbar (Right Edge)
                VStack {
                    Spacer().frame(height: 68)
                    floatingMapControls
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Floating Top Search Bar, Suggestions & Guide
                VStack(spacing: 8) {
                    searchBar

                    if !searchResults.isEmpty {
                        searchSuggestionsList
                    } else {
                        guidePill
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // Bottom Floating Glass Control Card
                bottomLocationCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
            }
            .navigationTitle("Drop Apple Map Pin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        applyCurrentLocation()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.cyan)
                }
            }
            .onAppear {
                if let initial = droppedCoordinate {
                    reverseGeocode(coordinate: initial)
                }
            }
            .onDisappear {
                geocodeTask?.cancel()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Guide Pill

    private var guidePill: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.cyan)
            Text("Tap or hold anywhere to drop marker • Drag pin to adjust")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Floating Map Controls (Map Type, Location, Center)

    private var floatingMapControls: some View {
        VStack(spacing: 10) {
            // Satellite / Hybrid / Standard Map Type Toggle
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    mapType = (mapType == .standard) ? .hybrid : .standard
                }
            } label: {
                Image(systemName: mapType == .standard ? "globe.americas.fill" : "map.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(mapType == .hybrid ? Color.yellow : Color.white)
            }
            .buttonStyle(.glassCircle)
            .help(mapType == .standard ? "Switch to Satellite Aerial" : "Switch to Standard Map")

            // Current User GPS Location
            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.cyan)
            }
            .buttonStyle(.glassCircle)
            .help("Center on My Location")

            // Center on Dropped Marker Pin
            if droppedCoordinate != nil {
                Button {
                    centerOnDroppedMarker()
                } label: {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.glassCircle)
                .help("Center on Dropped Marker")
            }

            // Drop Marker at Map Center
            Button {
                dropMarkerAtCenter()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.green)
            }
            .buttonStyle(.glassCircle)
            .help("Drop Marker at Center")
        }
        .padding(.trailing, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Search place, address or city...", text: $searchQuery)
                .font(.system(size: 14, weight: .medium, design: .rounded))
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
                        .foregroundStyle(.secondary)
                }
            }

            // Current Location Quick Button
            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.cyan)
                    .padding(5)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private var searchSuggestionsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(searchResults.prefix(4), id: \.self) { item in
                Button {
                    selectSearchItem(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.cyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "Location")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                            if let subtitle = item.placemark.title {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                Divider()
                    .background(Color.white.opacity(0.1))
            }
        }
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    // MARK: - Bottom Dropped Pin Details Card

    private var bottomLocationCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(reverseGeocodedAddress.isEmpty ? "Dropped Marker Pin" : reverseGeocodedAddress)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if isReverseGeocoding {
                            ProgressView()
                                .scaleEffect(0.65)
                                .tint(.cyan)
                        }
                    }

                    if let coord = droppedCoordinate {
                        Text(String(format: "%.5f°, %.5f°", coord.latitude, coord.longitude))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.cyan)
                    } else {
                        Text("Tap map to drop pin")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if droppedCoordinate != nil {
                    Button {
                        withAnimation {
                            droppedCoordinate = nil
                            reverseGeocodedAddress = ""
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Color.white.opacity(0.08)))
                    }
                    .help("Remove Dropped Marker")
                }
            }

            // Apply Button
            Button {
                applyCurrentLocation()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(droppedCoordinate != nil ? "Apply Dropped Pin to QR" : "Drop Pin at Center & Apply")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 48)
            }
            .buttonStyle(.glassProminent)
        }
        .padding(16)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 22))
    }

    // MARK: - Actions & Geocoding

    private func applyCurrentLocation() {
        let coord = droppedCoordinate ?? region.center
        let lat = coord.latitude
        let lon = coord.longitude
        let name = reverseGeocodedAddress.isEmpty ? (locationName.isEmpty ? "Dropped Pin" : locationName) : reverseGeocodedAddress

        latitude = lat
        longitude = lon
        locationName = name

        onLocationSelected?(lat, lon, name)
        isPresented = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        request.region = region

        let search = MKLocalSearch(request: request)
        search.start { response, _ in
            if let items = response?.mapItems {
                withAnimation {
                    searchResults = items
                }
            }
        }
    }

    private func selectSearchItem(_ item: MKMapItem) {
        let coord = item.placemark.coordinate
        withAnimation(.easeInOut(duration: 0.5)) {
            droppedCoordinate = coord
            region.center = coord
            searchQuery = ""
            searchResults.removeAll()
            reverseGeocodedAddress = item.name ?? item.placemark.title ?? "Selected Location"
        }
        reverseGeocode(coordinate: coord)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func centerOnUserLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let userCoord = locationManager.location?.coordinate {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                droppedCoordinate = userCoord
                region.center = userCoord
            }
            reverseGeocode(coordinate: userCoord)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func centerOnDroppedMarker() {
        if let coord = droppedCoordinate {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                region.center = coord
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func dropMarkerAtCenter() {
        let center = region.center
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            droppedCoordinate = center
        }
        reverseGeocode(coordinate: center)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        geocodeTask?.cancel()
        geocodeTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            isReverseGeocoding = true

            do {
                let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
                await MainActor.run {
                    self.isReverseGeocoding = false
                    if let p = placemarks.first {
                        let parts = [p.name, p.thoroughfare, p.locality, p.administrativeArea].compactMap { $0 }
                        if !parts.isEmpty {
                            self.reverseGeocodedAddress = parts.joined(separator: ", ")
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isReverseGeocoding = false
                }
            }
        }
    }
}

// MARK: - Native Interactive Droppable MapKit Representable

struct DroppableMapViewRepresentable: UIViewRepresentable {
    @Binding var droppedCoordinate: CLLocationCoordinate2D?
    @Binding var region: MKCoordinateRegion
    var mapType: MKMapType
    var onMarkerDropped: ((CLLocationCoordinate2D) -> Void)?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.mapType = mapType

        // Tap gesture to drop or move marker
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(tapGesture)

        // Long press gesture to drop marker
        let longPressGesture = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.45
        mapView.addGestureRecognizer(longPressGesture)

        // Initial annotation if coordinate exists
        if let coord = droppedCoordinate {
            let annotation = DroppedPinAnnotation(coordinate: coord, title: "Dropped Marker")
            mapView.addAnnotation(annotation)
            mapView.selectAnnotation(annotation, animated: true)
        }

        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if mapView.mapType != mapType {
            mapView.mapType = mapType
        }

        // Synchronize external region changes
        let latDiff = abs(mapView.region.center.latitude - region.center.latitude)
        let lonDiff = abs(mapView.region.center.longitude - region.center.longitude)
        if latDiff > 0.0001 || lonDiff > 0.0001 {
            mapView.setRegion(region, animated: true)
        }

        // Synchronize dropped marker annotation
        let existingPins = mapView.annotations.compactMap { $0 as? DroppedPinAnnotation }
        if let coord = droppedCoordinate {
            if let pin = existingPins.first {
                let pinLatDiff = abs(pin.coordinate.latitude - coord.latitude)
                let pinLonDiff = abs(pin.coordinate.longitude - coord.longitude)
                if pinLatDiff > 0.00001 || pinLonDiff > 0.00001 {
                    UIView.animate(withDuration: 0.25) {
                        pin.coordinate = coord
                    }
                }
            } else {
                let newPin = DroppedPinAnnotation(coordinate: coord, title: "Dropped Marker")
                mapView.addAnnotation(newPin)
                mapView.selectAnnotation(newPin, animated: true)
            }
        } else {
            if !existingPins.isEmpty {
                mapView.removeAnnotations(existingPins)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: DroppableMapViewRepresentable

        init(_ parent: DroppableMapViewRepresentable) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            triggerMarkerDrop(at: coordinate, in: mapView)
        }

        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began, let mapView = gesture.view as? MKMapView else { return }
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            triggerMarkerDrop(at: coordinate, in: mapView)
        }

        private func triggerMarkerDrop(at coordinate: CLLocationCoordinate2D, in mapView: MKMapView) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            DispatchQueue.main.async {
                self.parent.droppedCoordinate = coordinate
                self.parent.onMarkerDropped?(coordinate)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let pinAnnotation = annotation as? DroppedPinAnnotation else { return nil }

            let identifier = "DroppedPinMarker"
            let markerView: MKMarkerAnnotationView
            if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView {
                dequeued.annotation = pinAnnotation
                markerView = dequeued
            } else {
                markerView = MKMarkerAnnotationView(annotation: pinAnnotation, reuseIdentifier: identifier)
                markerView.canShowCallout = true
                markerView.animatesWhenAdded = true
                markerView.isDraggable = true
                markerView.markerTintColor = .systemRed
                markerView.glyphImage = UIImage(systemName: "mappin")
            }
            return markerView
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            if newState == .ending, let annotation = view.annotation {
                triggerMarkerDrop(at: annotation.coordinate, in: mapView)
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - Dropped Pin MapKit Annotation

final class DroppedPinAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    var subtitle: String?

    init(coordinate: CLLocationCoordinate2D, title: String? = "Dropped Marker", subtitle: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        super.init()
    }
}
