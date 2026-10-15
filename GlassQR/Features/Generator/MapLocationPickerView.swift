import SwiftUI
import MapKit
import CoreLocation

public struct MapLocationPickerView: View {
    @Binding var isPresented: Bool
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var locationName: String
    public var onLocationSelected: ((Double, Double, String) -> Void)?

    @State private var region: MKCoordinateRegion
    @State private var searchQuery: String = ""
    @State private var isSearching: Bool = false
    @State private var searchResults: [MKMapItem] = []
    @State private var reverseGeocodedAddress: String = ""
    @State private var isReverseGeocoding: Bool = false

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
        self._region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: initialLat, longitude: initialLon),
            span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Interactive Apple Map
                Map(coordinateRegion: $region)
                    .ignoresSafeArea(edges: .bottom)
                    .onChange(of: region.center.latitude) { _, _ in
                        debounceReverseGeocode()
                    }

                // Center Pin Dropper Target
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.red)
                        .shadow(color: Color.black.opacity(0.35), radius: 6, y: 4)

                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 8, height: 4)
                        .scaleEffect(1.2)
                }
                .offset(y: -19) // Anchor pin point exactly at center

                // Floating Top Search Bar & Suggestions
                VStack(spacing: 8) {
                    searchBar

                    if !searchResults.isEmpty {
                        searchSuggestionsList
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
                        applyCurrentCenter()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.cyan)
                }
            }
            .onAppear {
                reverseGeocodeCenter()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

            // Current Location Button
            Button {
                centerOnUserLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.cyan)
                    .padding(6)
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
                        .frame(width: 40, height: 40)
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.red)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(reverseGeocodedAddress.isEmpty ? "Dropped Pin" : reverseGeocodedAddress)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(String(format: "%.5f°, %.5f°", region.center.latitude, region.center.longitude))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.cyan)
                }

                Spacer()
            }

            // Apply Button
            Button {
                applyCurrentCenter()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text("Apply Dropped Pin to QR")
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

    private func applyCurrentCenter() {
        let lat = region.center.latitude
        let lon = region.center.longitude
        let name = reverseGeocodedAddress.isEmpty ? "Dropped Pin" : reverseGeocodedAddress

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
            region.center = coord
            searchQuery = ""
            searchResults.removeAll()
            reverseGeocodedAddress = item.name ?? "Selected Location"
        }
    }

    private func centerOnUserLocation() {
        locationManager.requestWhenInUseAuthorization()
        if let userCoord = locationManager.location?.coordinate {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                region.center = userCoord
                reverseGeocodeCenter()
            }
        }
    }

    private func debounceReverseGeocode() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            reverseGeocodeCenter()
        }
    }

    private func reverseGeocodeCenter() {
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
            if let p = placemarks?.first {
                let parts = [p.name, p.locality, p.administrativeArea].compactMap { $0 }
                if !parts.isEmpty {
                    DispatchQueue.main.async {
                        self.reverseGeocodedAddress = parts.joined(separator: ", ")
                    }
                }
            }
        }
    }
}
