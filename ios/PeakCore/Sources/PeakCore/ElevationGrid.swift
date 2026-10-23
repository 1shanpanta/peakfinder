import Foundation

public struct GridHeader: Codable, Sendable, Equatable {
    public let north: Double
    public let west: Double
    public let rows: Int
    public let cols: Int
    public let cellsPerDegree: Double

    public init(north: Double, west: Double, rows: Int, cols: Int, cellsPerDegree: Double) {
        self.north = north
        self.west = west
        self.rows = rows
        self.cols = cols
        self.cellsPerDegree = cellsPerDegree
    }
}

public enum GridError: Error {
    case sizeMismatch(expected: Int, actual: Int)
}

/// Row-major int16 heights in metres, north row first. Reads assume a little-endian host (every Apple device).
public final class ElevationGrid: Sendable {
    public let header: GridHeader
    private let storage: Data

    public init(header: GridHeader, storage: Data) throws {
        let expected = header.rows * header.cols * MemoryLayout<Int16>.size
        guard storage.count == expected else { throw GridError.sizeMismatch(expected: expected, actual: storage.count) }
        self.header = header
        self.storage = storage
    }

    public convenience init(samples: [Int16], header: GridHeader) throws {
        try self.init(header: header, storage: samples.withUnsafeBytes { Data($0) })
    }

    public convenience init(binary: URL, header headerURL: URL) throws {
        let header = try JSONDecoder().decode(GridHeader.self, from: Data(contentsOf: headerURL))
        try self.init(header: header, storage: Data(contentsOf: binary, options: .alwaysMapped))
    }

    /// Nearest-cell height, or nil outside the grid.
    public func height(latitude: Double, longitude: Double) -> Double? {
        withSamples { sampler in sampler.height(latitude: latitude, longitude: longitude) }
    }

    func withSamples<R>(_ body: (GridSampler) -> R) -> R {
        storage.withUnsafeBytes { raw in
            body(GridSampler(header: header, samples: raw.bindMemory(to: Int16.self)))
        }
    }
}

/// Read-only view whose pointer is valid only inside `withSamples`, so sharing it across threads there is safe.
struct GridSampler: @unchecked Sendable {
    let header: GridHeader
    let samples: UnsafeBufferPointer<Int16>

    @inline(__always)
    func height(latitude: Double, longitude: Double) -> Double? {
        let row = (header.north - latitude) * header.cellsPerDegree
        let col = (longitude - header.west) * header.cellsPerDegree
        guard row >= 0, col >= 0, row < Double(header.rows), col < Double(header.cols) else { return nil }
        return Double(samples[Int(row) * header.cols + Int(col)])
    }
}
