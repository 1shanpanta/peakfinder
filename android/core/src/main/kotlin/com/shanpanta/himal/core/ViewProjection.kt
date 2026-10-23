package com.shanpanta.himal.core

/** Maps compass bearings and angles above level to screen points. */
class ViewProjection(
    val heading: Double,
    val pitch: Double,
    val fieldOfView: Double,
    val width: Double,
    val height: Double,
    /** Panorama mode puts true level at this fraction of the height. Camera mode (null) follows the phone's pitch. */
    val levelAtFraction: Double?,
) {
    val pointsPerDegree: Double get() = width / fieldOfView

    fun x(bearing: Double): Double = width / 2 + wrap(bearing - heading) * pointsPerDegree

    fun y(angle: Double): Double =
        levelAtFraction?.let { height * it - angle * pointsPerDegree } ?: (height / 2 - (angle - pitch) * pointsPerDegree)

    fun bearingAt(x: Double): Double = heading + (x - width / 2) / pointsPerDegree

    companion object {
        /** Degrees in -180..180. */
        fun wrap(degrees: Double): Double = (degrees + 540) % 360 - 180
    }
}
