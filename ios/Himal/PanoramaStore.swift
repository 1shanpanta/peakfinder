import CoreLocation
import Observation
import PeakCore
import SwiftUI

struct NepalData: Sendable {
    let grid: ElevationGrid
    let peaks: [PeakRecord]

    enum LoadError: Error { case missingResource(String) }

    static func load() throws -> NepalData {
        func url(_ name: String, _ ext: String) throws -> URL {
            guard let found = Bundle.main.url(forResource: name, withExtension: ext) else {
                throw LoadError.missingResource("\(name).\(ext)")
            }
            return found
        }
        let grid = try ElevationGrid(binary: url("nepal-dem", "i16"), header: url("nepal-dem", "json"))
        let peaks = try JSONDecoder().decode([PeakRecord].self, from: Data(contentsOf: url("nepal-peaks", "json")))
        return NepalData(grid: grid, peaks: peaks)
    }
}

@MainActor @Observable
final class PanoramaStore {
    enum Status: Equatable {
        case loading
        case ready
        case failed(String)
    }

    /// The hill-top viewpoint used before a position arrives and outside Nepal.
    static let demoViewpoint = CLLocationCoordinate2D(latitude: 27.7172, longitude: 85.5200)
    private static let recomputeDistance = 150.0

    private(set) var status = Status.loading
    private(set) var panorama: Panorama?
    private(set) var isDemo = false
    /// A typical iPhone main camera until the real one reports in.
    private(set) var lens = CameraLens(longAxisFieldOfView: 69.4, imageAspect: 16.0 / 9)

    var heading = 78.0
    var pitch = 0.0
    var roll = 0.0
    var fieldOfView = 28.0
    var usesCamera = false
    var followsCompass = false
    var showsDiagnostics = false
    /// Degrees of error the compass reports for itself, or nil before the first reading.
    private(set) var compassAccuracy: Double?

    /// A viewpoint given at launch stays, so a simulator run is not moved by its own fake GPS.
    private var isPinned = false
    private var data: NepalData?
    private var requested: CLLocationCoordinate2D?
    private var computedFor: CLLocationCoordinate2D?
    private var isComputing = false
    @ObservationIgnored private lazy var sensors = Sensors(store: self)

    func start() {
        applyLaunchArguments()
        sensors.start()
        Task {
            do {
                data = try await Task.detached { try NepalData.load() }.value
                refresh()
            } catch {
                status = .failed("\(error)")
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(4))
            if requested == nil { useDemoViewpoint() }
        }
    }

    func locationUpdate(_ coordinate: CLLocationCoordinate2D) {
        guard !isPinned else { return }
        isDemo = false
        requested = coordinate
        refresh()
    }

    func applyCompass(_ degrees: Double, accuracy: Double) {
        compassAccuracy = accuracy
        guard followsCompass else { return }
        heading = Self.blend(heading, toward: degrees, by: 0.35)
    }

    func applyTilt(_ pose: CameraPose) {
        guard usesCamera else { return }
        pitch += (pose.pitch - pitch) * 0.25
        roll += (pose.roll - roll) * 0.25
    }

    func setLens(_ lens: CameraLens) {
        self.lens = lens
    }

    func toggleCamera() {
        usesCamera.toggle()
        if usesCamera { followsCompass = true }
    }

    func panHeading(to value: Double) {
        followsCompass = false
        heading = (value.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    func visibleFieldOfView(screen: CGSize) -> Double {
        guard usesCamera else { return fieldOfView }
        return CameraOptics.horizontalFieldOfView(
            longAxisFieldOfView: lens.longAxisFieldOfView, imageAspect: lens.imageAspect,
            screenWidth: screen.width, screenHeight: screen.height
        )
    }

    private func useDemoViewpoint() {
        isDemo = true
        requested = Self.demoViewpoint
        refresh()
    }

    private func refresh() {
        guard let data, let target = requested, !isComputing else { return }
        if let done = computedFor, Self.meters(from: done, to: target) < Self.recomputeDistance { return }
        isComputing = true
        Task {
            var shown = target
            var result = await Self.render(data: data, at: target)
            if result == nil {
                shown = Self.demoViewpoint
                isDemo = true
                result = await Self.render(data: data, at: shown)
            }
            panorama = result
            computedFor = shown
            status = result == nil ? .failed("No terrain under the viewpoint") : .ready
            isComputing = false
        }
    }

    private nonisolated static func render(data: NepalData, at coordinate: CLLocationCoordinate2D) async -> Panorama? {
        await Task.detached(priority: .userInitiated) {
            guard let eye = PanoramaEngine.eyeHeight(grid: data.grid, latitude: coordinate.latitude, longitude: coordinate.longitude) else {
                return nil
            }
            let viewpoint = Viewpoint(latitude: coordinate.latitude, longitude: coordinate.longitude, eyeHeight: eye)
            return PanoramaEngine.make(grid: data.grid, peaks: data.peaks, viewpoint: viewpoint)
        }.value
    }

    private static func meters(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func blend(_ current: Double, toward target: Double, by amount: Double) -> Double {
        let delta = (target - current + 540).truncatingRemainder(dividingBy: 360) - 180
        return (current + delta * amount + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Lets a simulator run start from a known view: `-lat 27.7 -lon 85.5 -heading 78 -fov 40 -camera 1`.
    private func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        func value(_ key: String) -> Double? { defaults.object(forKey: key) == nil ? nil : defaults.double(forKey: key) }
        if let latitude = value("lat"), let longitude = value("lon") {
            requested = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            isPinned = true
        }
        heading = value("heading") ?? heading
        fieldOfView = value("fov") ?? fieldOfView
        usesCamera = defaults.bool(forKey: "camera")
    }
}
