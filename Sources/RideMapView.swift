import SwiftUI
import MapKit

struct RideMapView: View {
    @EnvironmentObject var ble: DunenBLEManager
    @EnvironmentObject var gps: GPSSpeedManager
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 12) {
                    mapCard
                        .frame(maxWidth: .infinity)
                    ridePanel(compact: true)
                        .frame(width: min(330, geometry.size.width * 0.40))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        mapCard.frame(height: 390)
                        ridePanel(compact: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 82)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ride").font(.largeTitle.weight(.heavy))
                Text(gps.isRecordingRide ? "Recording GPS + bike telemetry" : "OpenStreetMap ride recorder")
                    .font(.caption)
                    .foregroundStyle(gps.isRecordingRide ? .red : .cyan)
            }
            Spacer()
            ConnectionPill()
        }
    }

    private var mapCard: some View {
        ZStack(alignment: .bottomLeading) {
            OSMMapView(
                currentLocation: gps.currentLocation,
                track: gps.trackCoordinates,
                followUser: gps.isRecordingRide
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))

            LinearGradient(
                colors: [.clear, .black.opacity(0.62)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 22))

            HStack(spacing: 14) {
                mapMetric(value: speedText, unit: settings.speedUnit.rawValue, label: "GPS")
                mapMetric(value: String(format: "%.0f", ble.telemetry.batteryPercent), unit: "%", label: "BATTERY")
                mapMetric(value: powerText, unit: "kW", label: "POWER")
                Spacer(minLength: 0)
                Link(destination: URL(string: "https://www.openstreetmap.org/copyright")!) {
                    Text("© OpenStreetMap")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(12)
        }
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.cyan.opacity(0.22)))
        .shadow(color: .cyan.opacity(0.08), radius: 12)
    }

    @ViewBuilder
    private func ridePanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 9 : 12) {
            if compact { header }

            GlassCard(glow: gps.isRecordingRide) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(gps.isRecordingRide ? "RIDE IN PROGRESS" : "RIDE RECORDER")
                                .font(.caption.weight(.heavy))
                                .tracking(1.1)
                                .foregroundStyle(gps.isRecordingRide ? .red : .cyan)
                            Text(gps.recorderStatus)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        Spacer()
                        if gps.isRecordingRide {
                            Circle().fill(.red).frame(width: 10, height: 10)
                                .shadow(color: .red, radius: 6)
                        }
                    }

                    HStack {
                        stat(String(format: "%.2f", gps.recordedDistanceKm), "km", "DISTANCE")
                        stat("\(gps.sampleCount)", "pts", "SAMPLES")
                        stat(durationText, "", "DURATION")
                    }

                    Button {
                        if gps.isRecordingRide {
                            gps.stopRide()
                            ble.stopRideRecording()
                        } else {
                            ble.startRideRecording()
                            gps.startRide()
                        }
                    } label: {
                        Label(gps.isRecordingRide ? "Stop & Save Ride" : "Start Ride", systemImage: gps.isRecordingRide ? "stop.fill" : "record.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(gps.isRecordingRide ? .red : .cyan)
                    .controlSize(.large)
                }
            }

            GlassCard {
                VStack(spacing: 10) {
                    metricRow("GPS speed", "\(speedText) \(settings.speedUnit.rawValue)")
                    metricRow("Bike speed", String(format: "%.1f km/h", ble.telemetry.speedKmh))
                    metricRow("Mode", ble.telemetry.mode.title)
                    metricRow("Battery", String(format: "%.0f%% · %.1f V", ble.telemetry.batteryPercent, ble.telemetry.voltage))
                    metricRow("Power", powerText == "—" ? "—" : "\(powerText) kW")
                    metricRow("Motor current", currentText == "—" ? "—" : "\(currentText) A")
                    metricRow("Regen", ble.telemetry.regenLevel > 0 ? "Level \(ble.telemetry.regenLevel)" : "Auto")
                }
            }

            if let gpx = gps.latestGPXURL, let ride = gps.latestRideURL {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Export Ride").font(.headline)
                        Text("GPX works with mapping apps. Aptum Ride JSON keeps every GPS point together with bike telemetry for desktop analysis.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            ShareLink(item: gpx) {
                                Label("GPX", systemImage: "map")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.cyan)

                            ShareLink(item: ride) {
                                Label("Ride Data", systemImage: "waveform.path.ecg")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            if gps.authStatus == .denied || gps.authStatus == .restricted {
                Text("Enable Location for Aptum Dashboard in iPhone Settings to record rides.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var hasDriveData: Bool { ble.isDemoMode || ble.liveFrameCount > 0 }
    private var powerText: String { hasDriveData ? String(format: "%.1f", ble.telemetry.powerKw) : "—" }
    private var currentText: String { hasDriveData ? String(format: "%.0f", ble.telemetry.currentA) : "—" }
    private var speedText: String {
        let value = settings.speedUnit == .kmh ? gps.speedKmh : gps.speedKmh * 0.621371
        return String(format: "%.0f", value)
    }
    private var durationText: String {
        let seconds = Int(ble.rideStats.durationSeconds)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    private func mapMetric(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.headline.weight(.bold)).monospacedDigit()
                Text(unit).font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.7))
            }
            Text(label).font(.system(size: 7, weight: .heavy)).tracking(0.7).foregroundStyle(.white.opacity(0.6))
        }
        .foregroundStyle(.white)
    }

    private func stat(_ value: String, _ unit: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title3.weight(.bold)).monospacedDigit()
                Text(unit).font(.caption2).foregroundStyle(.secondary)
            }
            Text(label).font(.system(size: 8, weight: .bold)).tracking(0.5).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
        .font(.caption)
    }
}

/// MapKit-backed OpenStreetMap tile renderer with a live route polyline.
struct OSMMapView: UIViewRepresentable {
    let currentLocation: CLLocation?
    let track: [CLLocationCoordinate2D]
    let followUser: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true
        map.pointOfInterestFilter = .excludingAll
        let tiles = MKTileOverlay(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png")
        tiles.canReplaceMapContent = true
        tiles.maximumZ = 19
        map.addOverlay(tiles, level: .aboveLabels)
        context.coordinator.tileOverlay = tiles
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        let routeOverlays = map.overlays.filter { $0 is MKPolyline }
        map.removeOverlays(routeOverlays)
        if track.count > 1 {
            let line = MKPolyline(coordinates: track, count: track.count)
            map.addOverlay(line, level: .aboveLabels)
        }

        map.removeAnnotations(map.annotations)
        if let location = currentLocation {
            let marker = MKPointAnnotation()
            marker.coordinate = location.coordinate
            marker.title = "Current location"
            map.addAnnotation(marker)
            if !context.coordinator.didSetInitialRegion || followUser {
                map.setRegion(
                    MKCoordinateRegion(
                        center: location.coordinate,
                        latitudinalMeters: 1_200,
                        longitudinalMeters: 1_200
                    ),
                    animated: context.coordinator.didSetInitialRegion
                )
                context.coordinator.didSetInitialRegion = true
            }
        } else if !context.coordinator.didSetInitialRegion {
            map.setRegion(
                MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 51.0, longitude: 19.0),
                    span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
                ),
                animated: false
            )
            context.coordinator.didSetInitialRegion = true
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var tileOverlay: MKTileOverlay?
        var didSetInitialRegion = false

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tiles = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tiles)
            }
            if let line = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: line)
                renderer.strokeColor = UIColor.systemCyan
                renderer.lineWidth = 5
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let id = "ride-position"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation
            view.markerTintColor = .systemCyan
            view.glyphImage = UIImage(systemName: "location.fill")
            view.canShowCallout = false
            return view
        }
    }
}
