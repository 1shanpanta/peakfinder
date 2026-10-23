import Foundation
import Testing
@testable import PeakCore

@Suite struct PanoramaEngineTests {
    let eye = Viewpoint(latitude: Place.latitude, longitude: Place.longitude, eyeHeight: 2)

    private func peak(_ name: String, at place: (lat: Double, lon: Double), ele: Double) -> PeakRecord {
        PeakRecord(name: name, ele: ele, lat: place.lat, lon: place.lon)
    }

    @Test func peakOnFlatPlainShowsAtGeometricAngle() throws {
        let grid = try TerrainBuilder(degrees: 0.4, cellsPerDegree: 1200).build()
        let result = PanoramaEngine.make(grid: grid, peaks: [peak("Hill", at: Place.north(10_000), ele: 500)], viewpoint: eye, rangeKm: 20)

        let hill = try #require(result.peaks.first)
        // (500 - 2 - 6.8 m curvature drop) over 10 km is 2.81 degrees.
        #expect(abs(hill.elevationAngle - 2.81) < 0.02)
        #expect(abs(hill.distanceKm - 10) < 0.05)
        #expect(abs(hill.bearing) < 0.1 || abs(hill.bearing - 360) < 0.1)
    }

    @Test func peakDueEastHasBearingNinety() throws {
        let grid = try TerrainBuilder(degrees: 0.4, cellsPerDegree: 1200).build()
        let result = PanoramaEngine.make(grid: grid, peaks: [peak("East", at: Place.east(8_000), ele: 400)], viewpoint: eye, rangeKm: 20)

        #expect(abs(try #require(result.peaks.first).bearing - 90) < 0.1)
    }

    @Test func earthCurvatureHidesADistantPeakOnAFlatPlain() throws {
        let grid = try TerrainBuilder(degrees: 2, cellsPerDegree: 120, north: 31).build()
        let far = peak("Far", at: Place.north(100_000), ele: 300)
        let near = peak("Near", at: Place.north(20_000), ele: 300)
        let result = PanoramaEngine.make(grid: grid, peaks: [far, near], viewpoint: eye, rangeKm: 120)

        // At 100 km the surface has dropped 683 m, so a 300 m summit is below the horizon. At 20 km the drop is 27 m.
        #expect(result.peaks.map(\.name) == ["Near"])
    }

    @Test func aTallRidgeHidesAPeakAndALowOneDoesNot() throws {
        var terrain = TerrainBuilder(degrees: 0.6, cellsPerDegree: 1200, north: 30.2)
        let behind = peak("Behind", at: Place.north(30_000), ele: 800)

        terrain.raiseRow(latitude: Place.north(5_000).lat, to: 300)
        let hidden = PanoramaEngine.make(grid: try terrain.build(), peaks: [behind], viewpoint: eye, rangeKm: 40)
        #expect(hidden.peaks.isEmpty)

        terrain.raiseRow(latitude: Place.north(5_000).lat, to: 30)
        let shown = PanoramaEngine.make(grid: try terrain.build(), peaks: [behind], viewpoint: eye, rangeKm: 40)
        #expect(shown.peaks.map(\.name) == ["Behind"])
    }

    @Test func nearbyLowBumpsAreIgnoredButNearbyWallsAreNot() throws {
        var terrain = TerrainBuilder(degrees: 0.4, cellsPerDegree: 1200)
        let behind = peak("Behind", at: Place.north(10_000), ele: 500)

        terrain.raiseRow(latitude: Place.north(300).lat, to: 5)
        let roofs = PanoramaEngine.make(grid: try terrain.build(), peaks: [behind], viewpoint: eye, rangeKm: 20)
        #expect(roofs.peaks.map(\.name) == ["Behind"])

        terrain.raiseRow(latitude: Place.north(300).lat, to: 40)
        let wall = PanoramaEngine.make(grid: try terrain.build(), peaks: [behind], viewpoint: eye, rangeKm: 20)
        #expect(wall.peaks.isEmpty)
    }

    @Test func skylineFollowsARidgeInItsOwnDirectionOnly() throws {
        var terrain = TerrainBuilder(degrees: 0.4, cellsPerDegree: 1200)
        terrain.raiseRow(latitude: Place.north(3_000).lat, to: 200)
        let result = PanoramaEngine.make(grid: try terrain.build(), peaks: [], viewpoint: eye, rangeKm: 15)

        // (200 - 2 - 0.6) over 3 km is 3.77 degrees to the north, and the plain is flat to the south.
        #expect(abs(result.skylineAngle(atBearing: 0) - 3.77) < 0.1)
        #expect(result.skylineAngle(atBearing: 180) < 0)
    }

    @Test func gridReturnsTheCellUnderAPointAndNilOutside() throws {
        var terrain = TerrainBuilder(degrees: 0.4, cellsPerDegree: 1200)
        terrain.raiseRow(latitude: Place.north(3_000).lat, to: 123)
        let grid = try terrain.build()

        #expect(grid.height(latitude: Place.north(3_000).lat, longitude: Place.longitude) == 123)
        #expect(grid.height(latitude: Place.latitude, longitude: Place.longitude) == 0)
        #expect(grid.height(latitude: 31, longitude: Place.longitude) == nil)
    }

    @Test func gridRejectsAFileOfTheWrongSize() {
        let header = GridHeader(north: 30, west: 85, rows: 10, cols: 10, cellsPerDegree: 10)
        #expect(throws: GridError.self) { try ElevationGrid(header: header, storage: Data(count: 10)) }
    }
}
