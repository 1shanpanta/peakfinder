import Foundation

public enum PanoramaEngine {
    static let earthRadius = 6_371_008.8
    /// Atmospheric refraction bends light toward the ground, so far terrain drops less than geometry says.
    static let refraction = 0.13
    static let stepMeters = 80.0
    /// Within this range, ground rising less than `nearMinRise` above the eye is roofs and trees, not a ridge.
    /// Copernicus is a surface model, and a Kathmandu street of 12 m buildings otherwise walls off 2 degrees of sky.
    static let nearFieldMeters = 2_000.0
    static let nearMinRise = 25.0
    static let minPeakDistance = 500.0
    static let visibilityToleranceDegrees = 0.1
    static let layerCutoffsMeters = [4_000.0, 12_000, 30_000, 70_000]

    public static func eyeHeight(grid: ElevationGrid, latitude: Double, longitude: Double, aboveGround: Double = 1.7) -> Double? {
        grid.height(latitude: latitude, longitude: longitude).map { $0 + aboveGround }
    }

    public static func make(grid: ElevationGrid, peaks: [PeakRecord], viewpoint: Viewpoint, rangeKm: Double = 170) -> Panorama {
        grid.withSamples { sampler in
            let rangeMeters = rangeKm * 1000
            let table = DistanceTable(maxMeters: rangeMeters)
            // The marcher holds raw pointers into the table, so the table must live to the end of this call.
            return withExtendedLifetime(table) {
                build(ray: RayMarcher(sampler: sampler, viewpoint: viewpoint, table: table),
                      peaks: peaks, viewpoint: viewpoint, rangeKm: rangeKm)
            }
        }
    }

    private static func build(ray: RayMarcher, peaks: [PeakRecord], viewpoint: Viewpoint, rangeKm: Double) -> Panorama {
        let rangeMeters = rangeKm * 1000
        let count = Int((360 / Panorama.azimuthStep).rounded())

        // Skyline of everything inside each cutoff, nearest first, so far ridges can be drawn paler.
        let cutoffs = layerCutoffsMeters.filter { $0 < rangeMeters } + [rangeMeters]
        var angles = [[Float]](repeating: [Float](repeating: -90, count: count), count: cutoffs.count)
        let rows = slopeRows(ray: ray, count: count, cutoffs: cutoffs)
        for (index, slopes) in rows.enumerated() {
            for layer in cutoffs.indices where slopes[layer].isFinite {
                angles[layer][index] = Float(atan(slopes[layer]) * 180 / .pi)
            }
        }
        let layers = zip(cutoffs, angles).dropLast().map { Panorama.Layer(rangeKm: $0 / 1000, angles: $1) }

        let visible = peaks.compactMap { visiblePeak($0, ray: ray, viewpoint: viewpoint, rangeMeters: rangeMeters) }
        return Panorama(
            viewpoint: viewpoint, rangeKm: rangeKm, skyline: angles[angles.count - 1], layers: Array(layers),
            peaks: visible.sorted { $0.elevation > $1.elevation }
        )
    }

    /// One row per azimuth, holding the steepest slope inside each cutoff.
    static func slopeRows(ray: RayMarcher, count: Int, cutoffs: [Double]) -> [[Double]] {
        var rows = [[Double]](repeating: [], count: count)
        rows.withUnsafeMutableBufferPointer { out in
            nonisolated(unsafe) let slots = out
            DispatchQueue.concurrentPerform(iterations: count) { index in
                let bearing = Double(index) * Panorama.azimuthStep * .pi / 180
                slots[index] = ray.cumulativeSlopes(bearing: bearing, cutoffs: cutoffs)
            }
        }
        return rows
    }

    static func visiblePeak(_ peak: PeakRecord, ray: RayMarcher, viewpoint: Viewpoint, rangeMeters: Double) -> VisiblePeak? {
        let (distance, bearing) = greatCircle(
            fromLatitude: viewpoint.latitude, longitude: viewpoint.longitude, toLatitude: peak.lat, longitude: peak.lon
        )
        guard distance >= minPeakDistance, distance <= rangeMeters else { return nil }
        // Without terrain under the summit the line of sight cannot be judged.
        guard ray.sampler.height(latitude: peak.lat, longitude: peak.lon) != nil else { return nil }

        let summit = atan((peak.ele - viewpoint.eyeHeight - curvatureDrop(distance)) / distance) * 180 / .pi
        // Stop short of the summit so its own slope does not hide it.
        let margin = min(max(0.02 * distance, 300), 1500)
        let blocking = ray.maxSlope(bearing: bearing, limit: distance - margin)
        if blocking.isFinite, summit < atan(blocking) * 180 / .pi - visibilityToleranceDegrees { return nil }

        return VisiblePeak(
            name: peak.name, elevation: peak.ele, latitude: peak.lat, longitude: peak.lon,
            distanceKm: distance / 1000, bearing: (bearing * 180 / .pi + 360).truncatingRemainder(dividingBy: 360),
            elevationAngle: summit
        )
    }

    static func curvatureDrop(_ distance: Double) -> Double {
        (1 - refraction) * distance * distance / (2 * earthRadius)
    }

    /// Haversine distance in metres and initial bearing in radians clockwise from north.
    static func greatCircle(
        fromLatitude lat1: Double, longitude lon1: Double, toLatitude lat2: Double, longitude lon2: Double
    ) -> (distance: Double, bearing: Double) {
        let phi1 = lat1 * .pi / 180, phi2 = lat2 * .pi / 180
        let deltaPhi = phi2 - phi1, deltaLambda = (lon2 - lon1) * .pi / 180
        let a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        let distance = 2 * earthRadius * asin(min(1, a.squareRoot()))
        let bearing = atan2(sin(deltaLambda) * cos(phi2), cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda))
        return (distance, bearing)
    }
}

/// The sample distances along every ray, with the trigonometry that depends only on distance worked out once.
///
/// The values sit in raw memory, not arrays. Every thread reads them for every sample, and the reference counting
/// on a shared array would make those threads queue behind one another.
final class DistanceTable: @unchecked Sendable {
    let count: Int
    let meters: UnsafeMutablePointer<Double>
    let sinAngle: UnsafeMutablePointer<Double>
    let cosAngle: UnsafeMutablePointer<Double>
    let curvatureDrop: UnsafeMutablePointer<Double>

    init(maxMeters: Double) {
        count = Int(maxMeters / PanoramaEngine.stepMeters)
        meters = .allocate(capacity: count)
        sinAngle = .allocate(capacity: count)
        cosAngle = .allocate(capacity: count)
        curvatureDrop = .allocate(capacity: count)
        for index in 0..<count {
            let distance = PanoramaEngine.stepMeters * Double(index + 1)
            meters[index] = distance
            sinAngle[index] = sin(distance / PanoramaEngine.earthRadius)
            cosAngle[index] = cos(distance / PanoramaEngine.earthRadius)
            curvatureDrop[index] = PanoramaEngine.curvatureDrop(distance)
        }
    }

    deinit {
        meters.deallocate()
        sinAngle.deallocate()
        cosAngle.deallocate()
        curvatureDrop.deallocate()
    }
}

/// Holds raw pointers into a `DistanceTable`, so the table must outlive it.
struct RayMarcher: @unchecked Sendable {
    let sampler: GridSampler
    private let count: Int
    private let meters: UnsafePointer<Double>
    private let sinAngle: UnsafePointer<Double>
    private let cosAngle: UnsafePointer<Double>
    private let curvatureDrop: UnsafePointer<Double>
    private let eye: Double
    private let latitude: Double
    private let longitude: Double
    private let sinLatitude: Double
    private let cosLatitude: Double

    init(sampler: GridSampler, viewpoint: Viewpoint, table: DistanceTable) {
        self.sampler = sampler
        count = table.count
        meters = UnsafePointer(table.meters)
        sinAngle = UnsafePointer(table.sinAngle)
        cosAngle = UnsafePointer(table.cosAngle)
        curvatureDrop = UnsafePointer(table.curvatureDrop)
        eye = viewpoint.eyeHeight
        latitude = viewpoint.latitude
        longitude = viewpoint.longitude
        sinLatitude = sin(viewpoint.latitude * .pi / 180)
        cosLatitude = cos(viewpoint.latitude * .pi / 180)
    }

    /// Steepest slope (rise over run, so the order matches angle order) seen along a ray, or -infinity if none.
    func maxSlope(bearing: Double, limit: Double) -> Double {
        cumulativeSlopes(bearing: bearing, cutoffs: [limit])[0]
    }

    /// Exact great-circle positions are costly, so only every `anchorStride` samples gets one. The samples between
    /// are linear in latitude and longitude, which is off by well under a centimetre over 640 m.
    private static let anchorStride = 8

    /// Latitude and longitude in degrees where a great circle leaving the viewpoint at `bearing` is after `index` steps.
    private func destination(_ index: Int, sinBearing: Double, cosBearing: Double) -> (latitude: Double, longitude: Double) {
        let sinDestination = sinLatitude * cosAngle[index] + cosLatitude * sinAngle[index] * cosBearing
        let longitudeShift = atan2(
            sinBearing * sinAngle[index] * cosLatitude, cosAngle[index] - sinLatitude * sinDestination
        )
        return (asin(sinDestination) * 180 / .pi, longitude + longitudeShift * 180 / .pi)
    }

    /// The steepest slope within each cutoff distance, from one walk along the great circle. Cutoffs rise in order.
    func cumulativeSlopes(bearing: Double, cutoffs: [Double]) -> [Double] {
        let sinBearing = sin(bearing)
        let cosBearing = cos(bearing)
        var best = -Double.infinity
        var results = [Double](repeating: -.infinity, count: cutoffs.count)
        let limit = cutoffs[cutoffs.count - 1]
        var next = 0
        var nextCutoff = cutoffs[0]
        // Position 0 m is the viewpoint, one step before index 0.
        var from = (index: -1, latitude: latitude, longitude: longitude)
        var to = from
        for index in 0..<count {
            let distance = meters[index]
            if distance > limit { break }
            while distance > nextCutoff {
                results[next] = best
                next += 1
                nextCutoff = cutoffs[next]
            }
            if index > to.index {
                from = to
                let anchor = min(index + Self.anchorStride - 1, count - 1)
                let position = destination(anchor, sinBearing: sinBearing, cosBearing: cosBearing)
                to = (anchor, position.latitude, position.longitude)
            }
            let fraction = Double(index - from.index) / Double(to.index - from.index)
            guard let height = sampler.height(
                latitude: from.latitude + (to.latitude - from.latitude) * fraction,
                longitude: from.longitude + (to.longitude - from.longitude) * fraction
            ) else { break }
            let rise = height - eye
            if distance < PanoramaEngine.nearFieldMeters, rise < PanoramaEngine.nearMinRise { continue }
            best = max(best, (rise - curvatureDrop[index]) / distance)
        }
        for index in next..<cutoffs.count { results[index] = best }
        return results
    }
}
