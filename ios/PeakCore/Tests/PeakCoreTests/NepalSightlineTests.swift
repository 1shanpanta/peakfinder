import Foundation
import Testing
@testable import PeakCore

private let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("shared/data")
private let dataPresent = FileManager.default.fileExists(atPath: resources.appendingPathComponent("nepal-dem.i16").path)

/// Real Nepal data, run only where `tools/build-data.py` has been run. Sightlines are well-known facts.
@Suite(.enabled(if: dataPresent)) struct NepalSightlineTests {
    private func panorama(lat: Double, lon: Double, eye: Double? = nil) throws -> Panorama {
        let grid = try ElevationGrid(binary: resources.appendingPathComponent("nepal-dem.i16"),
                                     header: resources.appendingPathComponent("nepal-dem.json"))
        let peaks = try JSONDecoder().decode([PeakRecord].self, from: Data(contentsOf: resources.appendingPathComponent("nepal-peaks.json")))
        let height = try eye ?? #require(PanoramaEngine.eyeHeight(grid: grid, latitude: lat, longitude: lon))
        return PanoramaEngine.make(grid: grid, peaks: peaks, viewpoint: Viewpoint(latitude: lat, longitude: lon, eyeHeight: height))
    }

    @Test func everestShowsFromNagarkotDueEastNorthEast() throws {
        let result = try panorama(lat: 27.7172, lon: 85.52, eye: 2175)
        let everest = try #require(result.peaks.first { $0.name == "Mount Everest" })

        // WGS84 geodesic from pyproj: 77.44 degrees, 141.62 km.
        #expect(abs(everest.bearing - 77.44) < 0.15)
        #expect(abs(everest.distanceKm - 141.62) < 0.8)
    }

    @Test func langtangLirungStandsDueNorthOfNagarkot() throws {
        let result = try panorama(lat: 27.7172, lon: 85.52, eye: 2175)
        let langtang = try #require(result.peaks.first { $0.name == "Langtang Lirung" })

        #expect(abs(langtang.bearing - 359.7) < 1 || abs(langtang.bearing) < 1)
    }

    @Test func machapuchareDominatesPokharaAndEverestIsNotInSight() throws {
        let result = try panorama(lat: 28.2096, lon: 83.9856)

        #expect(result.peaks.contains { $0.name.lowercased().contains("machapuchare") || $0.name.lowercased().contains("fishtail") })
        #expect(!result.peaks.contains { $0.name == "Mount Everest" })
    }

    @Test func aValleyFloorSeesFarFewerPeaksThanAHillTop() throws {
        let valley = try panorama(lat: 27.6710, lon: 85.4298)
        let hillTop = try panorama(lat: 27.7172, lon: 85.52, eye: 2175)

        #expect(valley.peaks.count < hillTop.peaks.count)
    }
}
