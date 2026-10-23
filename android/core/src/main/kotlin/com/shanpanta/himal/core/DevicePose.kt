package com.shanpanta.himal.core

import kotlin.math.asin
import kotlin.math.atan2

/**
 * Where the back camera points, taken from the rotation matrix Android's `SensorManager` produces.
 *
 * The matrix is row-major and maps device axes to world axes (x east, y north, z up), as documented for
 * `SensorManager.getRotationMatrix`. Its columns are the device axes in world terms. Device axes: x to the right
 * edge, y to the top edge, z out of the screen, so the back camera looks along -z.
 */
class DevicePose(rotation: FloatArray) {
    /** Degrees clockwise from magnetic north that the back camera faces. Flat on a table it follows the top edge. */
    val bearing: Double

    /** Degrees above level the back camera looks. Negative looks down. */
    val pitch: Double

    /** Degrees the right edge of the phone is tilted down. Zero when the phone is level. */
    val roll: Double

    init {
        require(rotation.size == 9) { "a rotation matrix has nine entries" }
        val forwardEast = -rotation[2].toDouble()
        val forwardNorth = -rotation[5].toDouble()
        val forwardUp = -rotation[8].toDouble()
        val topEast = rotation[1].toDouble()
        val topNorth = rotation[4].toDouble()
        val rightUp = rotation[6].toDouble()
        val topUp = rotation[7].toDouble()

        // Flat on a table the camera looks straight down and has no heading, so use the top edge instead.
        val flat = Math.abs(forwardUp) > 0.95
        val east = if (flat) topEast else forwardEast
        val north = if (flat) topNorth else forwardNorth
        bearing = (Math.toDegrees(atan2(east, north)) + 360) % 360
        pitch = Math.toDegrees(asin(forwardUp.coerceIn(-1.0, 1.0)))
        roll = Math.toDegrees(atan2(-rightUp, topUp))
    }
}
