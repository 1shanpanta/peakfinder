import Foundation

public enum PanoramaEngine {
    static let earthRadius = 6_371_000.0
    /// Atmospheric refraction bends light toward the ground, so far terrain drops less than geometry says.
    static let refraction = 0.13
    static let metersPerDegreeLatitude = 110_540.0
    static let metersPerDegreeLongitude = 111_320.0
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
            let ray = RayMarcher(sampler: sampler, viewpoint: viewpoint)
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
        let midLatitude = (viewpoint.latitude + peak.lat) / 2 * .pi / 180
        let east = (peak.lon - viewpoint.longitude) * metersPerDegreeLongitude * cos(midLatitude)
        let north = (peak.lat - viewpoint.latitude) * metersPerDegreeLatitude
        let distance = hypot(east, north)
        guard distance >= minPeakDistance, distance <= rangeMeters else { return nil }
        // Without terrain under the summit the line of sight cannot be judged.
        guard ray.sampler.height(latitude: peak.lat, longitude: peak.lon) != nil else { return nil }

        let bearing = atan2(east, north)
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
}

struct RayMarcher {
    let sampler: GridSampler
    let viewpoint: Viewpoint

    /// Steepest slope (rise over run, so the order matches angle order) seen along a ray, or -infinity if none.
    func maxSlope(bearing: Double, limit: Double) -> Double {
        cumulativeSlopes(bearing: bearing, cutoffs: [limit])[0]
    }

    /// The steepest slope within each cutoff distance, from one walk along the ray. Cutoffs rise in order.
    func cumulativeSlopes(bearing: Double, cutoffs: [Double]) -> [Double] {
        let east = sin(bearing)
        let north = cos(bearing)
        let eye = viewpoint.eyeHeight
        var best = -Double.infinity
        var results = [Double](repeating: -.infinity, count: cutoffs.count)
        var next = 0
        var distance = PanoramaEngine.stepMeters
        while let limit = cutoffs.last, distance <= limit {
            while distance > cutoffs[next] {
                results[next] = best
                next += 1
            }
            let latitude = viewpoint.latitude + distance * north / PanoramaEngine.metersPerDegreeLatitude
            let midLatitude = (viewpoint.latitude + latitude) / 2 * .pi / 180
            let longitude = viewpoint.longitude
                + distance * east / (PanoramaEngine.metersPerDegreeLongitude * cos(midLatitude))
            guard let height = sampler.height(latitude: latitude, longitude: longitude) else { break }
            let rise = height - eye
            if distance < PanoramaEngine.nearFieldMeters, rise < PanoramaEngine.nearMinRise {
                distance += PanoramaEngine.stepMeters
                continue
            }
            best = max(best, (rise - PanoramaEngine.curvatureDrop(distance)) / distance)
            distance += PanoramaEngine.stepMeters
        }
        for index in next..<cutoffs.count { results[index] = best }
        return results
    }
}
