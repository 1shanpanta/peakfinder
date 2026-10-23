package com.shanpanta.himal.core

import kotlinx.serialization.Serializable

data class Viewpoint(val latitude: Double, val longitude: Double, val eyeHeight: Double)

@Serializable
data class PeakRecord(val name: String, val ele: Double, val lat: Double, val lon: Double)

data class VisiblePeak(
    val name: String,
    val elevation: Double,
    val latitude: Double,
    val longitude: Double,
    val distanceKm: Double,
    /** Degrees clockwise from true north. */
    val bearing: Double,
    /** Degrees above level to the summit, after Earth curvature and refraction. */
    val elevationAngle: Double,
) {
    val id: String get() = "$name@$latitude,$longitude"
}

class Panorama(
    val viewpoint: Viewpoint,
    val rangeKm: Double,
    /** Skyline angle in degrees above level, one value per [AZIMUTH_STEP] degrees, starting at north. */
    val skyline: FloatArray,
    /** Nearer skylines, nearest first. Each one hides less than the full skyline, which adds the far ridges. */
    val layers: List<Layer>,
    /** Visible peaks, highest first. */
    val peaks: List<VisiblePeak>,
) {
    /** Skyline of the terrain inside one distance, in degrees above level. */
    class Layer(val rangeKm: Double, val angles: FloatArray) {
        fun angle(bearing: Double): Double = interpolate(angles, bearing)
    }

    fun skylineAngle(bearing: Double): Double = interpolate(skyline, bearing)

    companion object {
        const val AZIMUTH_STEP = 0.1

        fun interpolate(values: FloatArray, bearing: Double): Double {
            val position = ((bearing % 360) + 360) % 360 / AZIMUTH_STEP
            val lower = position.toInt() % values.size
            val upper = (lower + 1) % values.size
            val fraction = position - Math.floor(position)
            return values[lower] * (1 - fraction) + values[upper] * fraction
        }
    }
}
