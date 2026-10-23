package com.shanpanta.himal.core

import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class ViewProjectionTest {
    private fun camera(heading: Double = 90.0, pitch: Double = 0.0, fov: Double = 40.0) =
        ViewProjection(heading, pitch, fov, 400.0, 800.0, null)

    @Test
    fun theHeadingLandsInTheMiddleOfTheScreen() = assertEquals(200.0, camera().x(90.0))

    @Test
    fun tenDegreesRightOfTheHeadingIsOneQuarterOfTheFieldAway() {
        // 40 degrees across 400 points is 10 points a degree.
        assertEquals(300.0, camera().x(100.0))
        assertEquals(100.0, camera().x(80.0))
    }

    @Test
    fun bearingsWrapAcrossNorth() {
        val view = camera(heading = 355.0)

        assertEquals(300.0, view.x(5.0), 1e-9)
        assertEquals(100.0, view.x(345.0), 1e-9)
    }

    @Test
    fun cameraModeKeepsThePitchLineInTheCentreAndHigherAnglesUp() {
        val view = camera(pitch = 5.0)

        assertEquals(400.0, view.y(5.0))
        assertEquals(390.0, view.y(6.0))
    }

    @Test
    fun panoramaModePutsLevelAtItsFractionOfTheHeight() {
        val view = ViewProjection(0.0, 40.0, 40.0, 400.0, 800.0, 0.75)

        assertEquals(600.0, view.y(0.0))
        assertEquals(570.0, view.y(3.0))
    }

    @Test
    fun aScreenColumnMapsBackToItsBearing() {
        val view = camera(heading = 350.0)

        // 100 points right of centre is 10 degrees, which carries 350 round to north.
        assertEquals(0.0, ViewProjection.wrap(view.bearingAt(300.0)), 1e-9)
        assertEquals(350.0, view.bearingAt(200.0))
    }
}

class CameraOpticsTest {
    private fun fov(aspect: Double, width: Double, height: Double) =
        CameraOptics.horizontalFieldOfView(69.4, aspect, width, height)

    @Test
    fun aWideLandscapeScreenSeesTheFullLongSideOfTheImage() {
        assertEquals(69.4, fov(4.0 / 3, 844.0, 390.0), 0.01)
        assertEquals(69.4, fov(16.0 / 9, 844.0, 390.0), 0.01)
    }

    @Test
    fun aTallPortraitScreenSeesOnlyACropOfTheShortSide() {
        // The image fills the screen height, so tan(half width) is tan(34.7 degrees) * 390 / 844. That is 35.4 degrees.
        // The image shape does not matter while the height decides the fit.
        assertEquals(35.4, fov(4.0 / 3, 390.0, 844.0), 0.2)
        assertEquals(35.4, fov(16.0 / 9, 390.0, 844.0), 0.2)
    }

    @Test
    fun aScreenAsWideAsTheImageSeesTheWholeShortSide() {
        // 4:3 short side: 2 * atan(tan(34.7 degrees) * 3 / 4) is 54.8 degrees.
        assertEquals(54.8, fov(4.0 / 3, 300.0, 400.0), 0.2)
        // 16:9 short side: 2 * atan(tan(34.7 degrees) * 9 / 16) is 42.6 degrees. A 3:4 screen is wider than 9:16.
        assertEquals(42.6, fov(16.0 / 9, 300.0, 400.0), 0.2)
    }
}

class DevicePoseTest {
    private fun rad(degrees: Double) = Math.toRadians(degrees)

    private fun pose(vararg rows: Double) = DevicePose(FloatArray(9) { rows[it].toFloat() })

    @Test
    fun anUprightPhoneFacingNorthReadsZeroEverywhere() {
        val pose = pose(1.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 1.0, 0.0)

        assertTrue(pose.bearing < 0.001 || pose.bearing > 359.999)
        assertEquals(0.0, pose.pitch, 0.001)
        assertEquals(0.0, pose.roll, 0.001)
    }

    @Test
    fun anUprightPhoneFacingEastReadsNinety() {
        val pose = pose(0.0, 0.0, -1.0, -1.0, 0.0, 0.0, 0.0, 1.0, 0.0)

        assertEquals(90.0, pose.bearing, 0.001)
        assertEquals(0.0, pose.pitch, 0.001)
    }

    @Test
    fun tiltingTheCameraUpRaisesPitchAndKeepsHeading() {
        val tilt = rad(30.0)
        val pose = pose(1.0, 0.0, 0.0, 0.0, -sin(tilt), -cos(tilt), 0.0, cos(tilt), -sin(tilt))

        assertEquals(30.0, pose.pitch, 0.001)
        assertEquals(0.0, pose.roll, 0.001)
        assertTrue(abs(pose.bearing) < 0.001 || pose.bearing > 359.999)
    }

    @Test
    fun rollingTheRightEdgeDownGivesPositiveRoll() {
        val roll = rad(20.0)
        val pose = pose(cos(roll), sin(roll), 0.0, 0.0, 0.0, -1.0, -sin(roll), cos(roll), 0.0)

        assertEquals(20.0, pose.roll, 0.001)
        assertEquals(0.0, pose.pitch, 0.001)
    }

    @Test
    fun aPhoneLyingFlatTakesItsHeadingFromTheTopEdge() {
        val pose = pose(0.0, 1.0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0)

        assertEquals(-90.0, pose.pitch, 0.001)
        assertEquals(90.0, pose.bearing, 0.001)
    }
}
