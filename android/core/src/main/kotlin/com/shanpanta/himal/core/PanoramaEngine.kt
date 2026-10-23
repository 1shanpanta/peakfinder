package com.shanpanta.himal.core

import java.util.stream.IntStream
import kotlin.math.asin
import kotlin.math.atan
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.sqrt

object PanoramaEngine {
    const val EARTH_RADIUS = 6_371_008.8

    /** Atmospheric refraction bends light toward the ground, so far terrain drops less than geometry says. */
    private const val REFRACTION = 0.13
    internal const val STEP_METERS = 80.0

    /**
     * Within this range, ground rising less than [NEAR_MIN_RISE] above the eye is roofs and trees, not a ridge.
     * Copernicus is a surface model, and a Kathmandu street of 12 m buildings otherwise walls off 2 degrees of sky.
     */
    internal const val NEAR_FIELD_METERS = 2_000.0
    internal const val NEAR_MIN_RISE = 25.0
    private const val MIN_PEAK_DISTANCE = 500.0
    private const val VISIBILITY_TOLERANCE_DEGREES = 0.1
    private val LAYER_CUTOFFS_METERS = doubleArrayOf(4_000.0, 12_000.0, 30_000.0, 70_000.0)

    fun eyeHeight(grid: ElevationGrid, latitude: Double, longitude: Double, aboveGround: Double = 1.7): Double? {
        val ground = grid.height(latitude, longitude)
        return if (ground.isNaN()) null else ground + aboveGround
    }

    fun make(grid: ElevationGrid, peaks: List<PeakRecord>, viewpoint: Viewpoint, rangeKm: Double = 170.0): Panorama {
        val rangeMeters = rangeKm * 1000
        val ray = RayMarcher(grid, viewpoint, DistanceTable(rangeMeters))
        val count = Math.round(360 / Panorama.AZIMUTH_STEP).toInt()

        // Skyline of everything inside each cutoff, nearest first, so far ridges can be drawn paler.
        val cutoffs = LAYER_CUTOFFS_METERS.filter { it < rangeMeters }.toDoubleArray() + rangeMeters
        val rows = arrayOfNulls<DoubleArray>(count)
        IntStream.range(0, count).parallel().forEach { index ->
            val bearing = Math.toRadians(index * Panorama.AZIMUTH_STEP)
            rows[index] = ray.cumulativeSlopes(bearing, cutoffs)
        }
        val angles = Array(cutoffs.size) { FloatArray(count) { -90f } }
        for (index in 0 until count) {
            val slopes = rows[index]!!
            for (layer in cutoffs.indices) {
                if (slopes[layer].isFinite()) angles[layer][index] = Math.toDegrees(atan(slopes[layer])).toFloat()
            }
        }
        val layers = (0 until cutoffs.size - 1).map { Panorama.Layer(cutoffs[it] / 1000, angles[it]) }

        val visible = peaks.mapNotNull { visiblePeak(it, ray, viewpoint, rangeMeters) }
        return Panorama(viewpoint, rangeKm, angles.last(), layers, visible.sortedByDescending { it.elevation })
    }

    private fun visiblePeak(peak: PeakRecord, ray: RayMarcher, viewpoint: Viewpoint, rangeMeters: Double): VisiblePeak? {
        val (distance, bearing) = greatCircle(viewpoint.latitude, viewpoint.longitude, peak.lat, peak.lon)
        if (distance < MIN_PEAK_DISTANCE || distance > rangeMeters) return null
        // Without terrain under the summit the line of sight cannot be judged.
        if (ray.grid.height(peak.lat, peak.lon).isNaN()) return null

        val summit = Math.toDegrees(atan((peak.ele - viewpoint.eyeHeight - curvatureDrop(distance)) / distance))
        // Stop short of the summit so its own slope does not hide it.
        val margin = min(max(0.02 * distance, 300.0), 1500.0)
        val blocking = ray.cumulativeSlopes(bearing, doubleArrayOf(distance - margin))[0]
        if (blocking.isFinite() && summit < Math.toDegrees(atan(blocking)) - VISIBILITY_TOLERANCE_DEGREES) return null

        return VisiblePeak(
            name = peak.name, elevation = peak.ele, latitude = peak.lat, longitude = peak.lon,
            distanceKm = distance / 1000, bearing = (Math.toDegrees(bearing) + 360) % 360, elevationAngle = summit,
        )
    }

    internal fun curvatureDrop(distance: Double): Double = (1 - REFRACTION) * distance * distance / (2 * EARTH_RADIUS)

    /** Haversine distance in metres and initial bearing in radians clockwise from north. */
    fun greatCircle(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Pair<Double, Double> {
        val phi1 = Math.toRadians(lat1)
        val phi2 = Math.toRadians(lat2)
        val deltaPhi = phi2 - phi1
        val deltaLambda = Math.toRadians(lon2 - lon1)
        val a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2)
        val distance = 2 * EARTH_RADIUS * asin(min(1.0, sqrt(a)))
        val bearing = atan2(sin(deltaLambda) * cos(phi2), cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda))
        return distance to bearing
    }
}

/** The sample distances along every ray, with the trigonometry that depends only on distance worked out once. */
internal class DistanceTable(maxMeters: Double) {
    val count = (maxMeters / PanoramaEngine.STEP_METERS).toInt()
    val meters = DoubleArray(count) { PanoramaEngine.STEP_METERS * (it + 1) }
    val sinAngle = DoubleArray(count) { sin(meters[it] / PanoramaEngine.EARTH_RADIUS) }
    val cosAngle = DoubleArray(count) { cos(meters[it] / PanoramaEngine.EARTH_RADIUS) }
    val curvatureDrop = DoubleArray(count) { PanoramaEngine.curvatureDrop(meters[it]) }
}

internal class RayMarcher(val grid: ElevationGrid, viewpoint: Viewpoint, private val table: DistanceTable) {
    private val eye = viewpoint.eyeHeight
    private val latitude = viewpoint.latitude
    private val longitude = viewpoint.longitude
    private val sinLatitude = sin(Math.toRadians(latitude))
    private val cosLatitude = cos(Math.toRadians(latitude))

    /**
     * The steepest slope within each cutoff distance, from one walk along the great circle. Cutoffs rise in order.
     * A slope is rise over run, so the order matches angle order. A cutoff with no ground in it gives -infinity.
     */
    fun cumulativeSlopes(bearing: Double, cutoffs: DoubleArray): DoubleArray {
        val sinBearing = sin(bearing)
        val cosBearing = cos(bearing)
        val limit = cutoffs.last()
        val results = DoubleArray(cutoffs.size) { Double.NEGATIVE_INFINITY }
        var best = Double.NEGATIVE_INFINITY
        var next = 0
        var nextCutoff = cutoffs[0]
        // Position 0 m is the viewpoint, one step before index 0.
        var fromIndex = -1
        var fromLat = latitude
        var fromLon = longitude
        var toIndex = -1
        var toLat = latitude
        var toLon = longitude
        for (index in 0 until table.count) {
            val distance = table.meters[index]
            if (distance > limit) break
            while (distance > nextCutoff) {
                results[next] = best
                next += 1
                nextCutoff = cutoffs[next]
            }
            if (index > toIndex) {
                fromIndex = toIndex
                fromLat = toLat
                fromLon = toLon
                toIndex = min(index + ANCHOR_STRIDE - 1, table.count - 1)
                val sinDestination = sinLatitude * table.cosAngle[toIndex] + cosLatitude * table.sinAngle[toIndex] * cosBearing
                toLat = Math.toDegrees(asin(sinDestination))
                toLon = longitude + Math.toDegrees(
                    atan2(sinBearing * table.sinAngle[toIndex] * cosLatitude, table.cosAngle[toIndex] - sinLatitude * sinDestination),
                )
            }
            val fraction = (index - fromIndex).toDouble() / (toIndex - fromIndex)
            val height = grid.height(fromLat + (toLat - fromLat) * fraction, fromLon + (toLon - fromLon) * fraction)
            if (height.isNaN()) break
            val rise = height - eye
            if (distance < PanoramaEngine.NEAR_FIELD_METERS && rise < PanoramaEngine.NEAR_MIN_RISE) continue
            best = max(best, (rise - table.curvatureDrop[index]) / distance)
        }
        for (index in next until cutoffs.size) results[index] = best
        return results
    }

    private companion object {
        /**
         * Exact great-circle positions are costly, so only every ANCHOR_STRIDE samples gets one. The samples between
         * are linear in latitude and longitude, which is off by well under a centimetre over 640 m.
         */
        const val ANCHOR_STRIDE = 8
    }
}
