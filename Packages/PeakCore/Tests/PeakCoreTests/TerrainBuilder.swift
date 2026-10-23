import Foundation
@testable import PeakCore

/// A flat sea-level square of terrain that tests raise into walls and bumps.
struct TerrainBuilder {
    let header: GridHeader
    var samples: [Int16]

    init(degrees: Double, cellsPerDegree: Double, north: Double = 30, west: Double = 85) {
        let cells = Int(degrees * cellsPerDegree)
        header = GridHeader(north: north, west: west, rows: cells, cols: cells, cellsPerDegree: cellsPerDegree)
        samples = [Int16](repeating: 0, count: cells * cells)
    }

    /// Raises every cell in the row that contains `latitude`, a wall running east to west.
    mutating func raiseRow(latitude: Double, to height: Int16) {
        let row = Int((header.north - latitude) * header.cellsPerDegree)
        for col in 0..<header.cols { samples[row * header.cols + col] = height }
    }

    func build() throws -> ElevationGrid {
        try ElevationGrid(samples: samples, header: header)
    }
}

enum Place {
    static let latitude = 29.8
    static let longitude = 85.2
    /// One degree of a great circle on the engine's sphere, in metres.
    static let metersPerDegree = 6_371_008.8 * .pi / 180

    /// A point `meters` north of the viewpoint.
    static func north(_ meters: Double) -> (lat: Double, lon: Double) {
        (latitude + meters / metersPerDegree, longitude)
    }

    /// A point `meters` east of the viewpoint.
    static func east(_ meters: Double) -> (lat: Double, lon: Double) {
        (latitude, longitude + meters / (metersPerDegree * cos(latitude * .pi / 180)))
    }
}
