import Foundation
import CoreLocation
import Combine

/// One time-aligned GPS + vehicle telemetry sample.
/// This is the stable interchange unit for a future desktop analyzer.
struct RideSample: Codable {
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let altitudeM: Double
    let horizontalAccuracyM: Double
    let verticalAccuracyM: Double
    let gpsSpeedKmh: Double
    let courseDegrees: Double?

    let bikeSpeedKmh: Double
    let rpm: Int
    let voltageV: Double
    let motorCurrentA: Double?
    let estimatedPowerKw: Double?
    let batteryPercent: Double
    let rideMode: String
    let throttlePercent: Double
    let regenLevel: Int
    let controllerTempC: Double?
    let motorTempC: Double?
    let warningCode: Int
    let errorCode: Int
    let brakeActive: Bool
}

/// High-rate vehicle stream kept independently from GPS fixes. A desktop app
/// can align it to GPS by timestamp without duplicating map coordinates at
/// every controller poll.
struct BikeTelemetrySample: Codable {
    let timestamp: Date
    let speedKmh: Double
    let rpm: Int
    let voltageV: Double
    let motorCurrentA: Double?
    let estimatedPowerKw: Double?
    let batteryPercent: Double
    let rideMode: String
    let throttlePercent: Double
    let regenLevel: Int
    let controllerTempC: Double?
    let motorTempC: Double?
    let warningCode: Int
    let errorCode: Int
    let brakeActive: Bool
}

struct RideFile: Codable {
    struct Metadata: Codable {
        let schema: String
        let schemaVersion: Int
        let app: String
        let vehicleProfile: String
        let controllerModel: String
        let startedAt: Date
        let endedAt: Date
        let sampleCount: Int
        let telemetrySampleCount: Int
        let distanceKm: Double
    }

    let metadata: Metadata
    let samples: [RideSample]
    let telemetry: [BikeTelemetrySample]
}

final class GPSSpeedManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var speedKmh: Double = 0
    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var isActive: Bool = false
    @Published var currentLocation: CLLocation?
    @Published var trackCoordinates: [CLLocationCoordinate2D] = []
    @Published var isRecordingRide: Bool = false
    @Published var rideStartedAt: Date?
    @Published var recordedDistanceKm: Double = 0
    @Published var sampleCount: Int = 0
    @Published var latestGPXURL: URL?
    @Published var latestRideURL: URL?
    @Published var recorderStatus: String = "Ready to record"

    private let locationManager = CLLocationManager()
    private var telemetryProvider: (() -> Telemetry)?
    private var profileProvider: (() -> ControllerProfile)?
    private var samples: [RideSample] = []
    private var telemetrySamples: [BikeTelemetrySample] = []
    private var lastRecordedLocation: CLLocation?
    private var telemetryTimer: Timer?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1
        locationManager.activityType = .automotiveNavigation
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        authStatus = locationManager.authorizationStatus
    }

    func attachTelemetryProvider(
        telemetry: @escaping () -> Telemetry,
        profile: @escaping () -> ControllerProfile
    ) {
        telemetryProvider = telemetry
        profileProvider = profile
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            isActive = true
        default:
            isActive = false
        }
    }

    func stop() {
        guard !isRecordingRide else { return }
        locationManager.stopUpdatingLocation()
        isActive = false
        speedKmh = 0
    }

    func startRide() {
        samples.removeAll(keepingCapacity: true)
        telemetrySamples.removeAll(keepingCapacity: true)
        trackCoordinates.removeAll(keepingCapacity: true)
        lastRecordedLocation = nil
        recordedDistanceKm = 0
        sampleCount = 0
        latestGPXURL = nil
        latestRideURL = nil
        rideStartedAt = Date()
        isRecordingRide = true
        recorderStatus = "Recording ride…"
        startTelemetryTimer()
        start()
    }

    func stopRide() {
        guard isRecordingRide else { return }
        isRecordingRide = false
        telemetryTimer?.invalidate()
        telemetryTimer = nil
        let endedAt = Date()
        guard let startedAt = rideStartedAt, !samples.isEmpty else {
            recorderStatus = "No GPS samples recorded"
            return
        }

        do {
            let stamp = Self.fileStamp.string(from: startedAt)
            let base = "Ride-\(stamp)"
            let directory = Self.documentsDirectory()
            let rideURL = directory.appendingPathComponent("\(base).aptumride.json")
            let gpxURL = directory.appendingPathComponent("\(base).gpx")
            let profile = profileProvider?() ?? .tse72Pro
            let controller = telemetryProvider?().productModel ?? profile.controllerTypeString
            let file = RideFile(
                metadata: .init(
                    schema: "com.aptum.dashboard.ride",
                    schemaVersion: 1,
                    app: "Aptum Dashboard",
                    vehicleProfile: profile.displayName,
                    controllerModel: controller,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    sampleCount: samples.count,
                    telemetrySampleCount: telemetrySamples.count,
                    distanceKm: recordedDistanceKm
                ),
                samples: samples,
                telemetry: telemetrySamples
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(file).write(to: rideURL, options: .atomic)
            try makeGPX(name: base).write(to: gpxURL, atomically: true, encoding: .utf8)
            latestRideURL = rideURL
            latestGPXURL = gpxURL
            recorderStatus = "Saved \(samples.count) points · \(String(format: "%.2f", recordedDistanceKm)) km"
        } catch {
            recorderStatus = "Export failed: \(error.localizedDescription)"
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authStatus = manager.authorizationStatus
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            isActive = true
        } else {
            isActive = false
            if isRecordingRide {
                isRecordingRide = false
                recorderStatus = "Location permission is required"
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            guard location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= 100,
                  abs(location.timestamp.timeIntervalSinceNow) < 15 else { continue }
            currentLocation = location
            if location.speed >= 0 {
                speedKmh = (location.speed * 3.6 * 10).rounded() / 10
            }
            if isRecordingRide { append(location) }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        recorderStatus = "GPS: \(error.localizedDescription)"
    }

    private func append(_ location: CLLocation) {
        if let previous = lastRecordedLocation {
            let delta = location.distance(from: previous)
            // Reject impossible GPS jumps while retaining stationary samples.
            if delta > 1_000 { return }
            recordedDistanceKm += delta / 1_000
        }
        lastRecordedLocation = location
        trackCoordinates.append(location.coordinate)

        let telemetry = telemetryProvider?() ?? Telemetry()
        let hasDriveData = telemetry.currentA != 0 || telemetry.powerKw != 0
        samples.append(RideSample(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeM: location.altitude,
            horizontalAccuracyM: location.horizontalAccuracy,
            verticalAccuracyM: location.verticalAccuracy,
            gpsSpeedKmh: max(0, location.speed) * 3.6,
            courseDegrees: location.course >= 0 ? location.course : nil,
            bikeSpeedKmh: telemetry.speedKmh,
            rpm: telemetry.rpm,
            voltageV: telemetry.voltage,
            motorCurrentA: hasDriveData ? telemetry.currentA : nil,
            estimatedPowerKw: hasDriveData ? telemetry.powerKw : nil,
            batteryPercent: telemetry.batteryPercent,
            rideMode: telemetry.mode.rawValue,
            throttlePercent: telemetry.throttleOpen * 100,
            regenLevel: telemetry.regenLevel,
            controllerTempC: telemetry.controllerTemp != 0 ? telemetry.controllerTemp : nil,
            motorTempC: telemetry.motorTemp != 0 ? telemetry.motorTemp : nil,
            warningCode: telemetry.warningCode,
            errorCode: telemetry.errorCode,
            brakeActive: telemetry.brakeActive
        ))
        sampleCount = samples.count
    }

    private func startTelemetryTimer() {
        telemetryTimer?.invalidate()
        telemetryTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.appendTelemetry()
        }
        telemetryTimer?.fire()
    }

    private func appendTelemetry() {
        guard isRecordingRide else { return }
        let t = telemetryProvider?() ?? Telemetry()
        let hasDriveData = t.currentA != 0 || t.powerKw != 0
        telemetrySamples.append(BikeTelemetrySample(
            timestamp: Date(),
            speedKmh: t.speedKmh,
            rpm: t.rpm,
            voltageV: t.voltage,
            motorCurrentA: hasDriveData ? t.currentA : nil,
            estimatedPowerKw: hasDriveData ? t.powerKw : nil,
            batteryPercent: t.batteryPercent,
            rideMode: t.mode.rawValue,
            throttlePercent: t.throttleOpen * 100,
            regenLevel: t.regenLevel,
            controllerTempC: t.controllerTemp != 0 ? t.controllerTemp : nil,
            motorTempC: t.motorTemp != 0 ? t.motorTemp : nil,
            warningCode: t.warningCode,
            errorCode: t.errorCode,
            brakeActive: t.brakeActive
        ))
    }

    private func makeGPX(name: String) -> String {
        let points = samples.map { sample in
            let time = Self.iso.string(from: sample.timestamp)
            let course = sample.courseDegrees.map { "<course>\($0)</course>" } ?? ""
            let current = sample.motorCurrentA.map { "<aptum:motorCurrentA>\($0)</aptum:motorCurrentA>" } ?? ""
            let power = sample.estimatedPowerKw.map { "<aptum:estimatedPowerKw>\($0)</aptum:estimatedPowerKw>" } ?? ""
            return """
              <trkpt lat="\(sample.latitude)" lon="\(sample.longitude)">
                <ele>\(sample.altitudeM)</ele><time>\(time)</time><speed>\(sample.gpsSpeedKmh / 3.6)</speed>\(course)
                <extensions><aptum:bikeSpeedKmh>\(sample.bikeSpeedKmh)</aptum:bikeSpeedKmh><aptum:rpm>\(sample.rpm)</aptum:rpm><aptum:voltageV>\(sample.voltageV)</aptum:voltageV><aptum:batteryPercent>\(sample.batteryPercent)</aptum:batteryPercent><aptum:mode>\(sample.rideMode)</aptum:mode><aptum:throttlePercent>\(sample.throttlePercent)</aptum:throttlePercent><aptum:regenLevel>\(sample.regenLevel)</aptum:regenLevel>\(current)\(power)</extensions>
              </trkpt>
            """
        }.joined(separator: "\n")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Aptum Dashboard" xmlns="http://www.topografix.com/GPX/1/1" xmlns:aptum="https://aptum-dashboard.dev/schema/ride/1">
          <metadata><name>\(name)</name><time>\(Self.iso.string(from: rideStartedAt ?? Date()))</time></metadata>
          <trk><name>\(name)</name><type>e-motorcycle</type><trkseg>
        \(points)
          </trkseg></trk>
        </gpx>
        """
    }

    private static func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    private static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
