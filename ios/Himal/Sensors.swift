import CoreLocation
import CoreMotion
import PeakCore

@MainActor
final class Sensors: NSObject, CLLocationManagerDelegate {
    private let locations = CLLocationManager()
    private let motion = CMMotionManager()
    private unowned let store: PanoramaStore

    init(store: PanoramaStore) {
        self.store = store
        super.init()
        locations.delegate = self
        locations.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locations.distanceFilter = 50
        locations.headingFilter = 0.5
    }

    func start() {
        locations.requestWhenInUseAuthorization()
        locations.startUpdatingLocation()
        if CLLocationManager.headingAvailable() { locations.startUpdatingHeading() }
        startTilt()
    }

    /// Gravity in device axes gives pitch and roll. The compass gives the heading, so no attitude frame is needed.
    private func startTilt() {
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30
        motion.startDeviceMotionUpdates(to: .main) { [weak self] sample, _ in
            guard let gravity = sample?.gravity else { return }
            let pose = CameraPose(gravityX: gravity.x, y: gravity.y, z: gravity.z)
            MainActor.assumeIsolated { self?.store.applyTilt(pose) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in self.store.locationUpdate(coordinate) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading heading: CLHeading) {
        let degrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        let accuracy = heading.headingAccuracy
        Task { @MainActor in self.store.applyCompass(degrees, accuracy: accuracy) }
    }

    /// Lets iOS show its figure-eight prompt when the compass needs calibrating.
    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { true }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
