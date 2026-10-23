package com.shanpanta.himal.core

import kotlin.math.atan
import kotlin.math.max
import kotlin.math.tan

object CameraOptics {
    /**
     * Horizontal field of view in degrees of a screen that shows the camera image filled to the screen.
     *
     * [longAxisFieldOfView] is the camera's field of view along the long side of the image, and [imageAspect] is
     * long side over short side (4/3 for a full sensor, 16/9 for 1080p video). The filled image loses the part
     * that overflows the screen, so a tall portrait screen sees less than the full short side.
     */
    fun horizontalFieldOfView(longAxisFieldOfView: Double, imageAspect: Double, screenWidth: Double, screenHeight: Double): Double {
        val landscape = screenWidth >= screenHeight
        val imageWidth = if (landscape) imageAspect else 1.0
        val imageHeight = if (landscape) 1.0 else imageAspect
        val scale = max(screenWidth / imageWidth, screenHeight / imageHeight)
        val visibleUnits = screenWidth / scale
        val tangentPerUnit = tan(Math.toRadians(longAxisFieldOfView / 2)) / (imageAspect / 2)
        return Math.toDegrees(2 * atan(visibleUnits / 2 * tangentPerUnit))
    }
}
