package com.shanpanta.himal.core

import java.nio.ShortBuffer
import kotlin.math.abs
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertNull
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource

class PanoramaEngineTest {
    private val eye = Viewpoint(Place.LATITUDE, Place.LONGITUDE, 2.0)

    private fun peak(name: String, at: Pair<Double, Double>, ele: Double) = PeakRecord(name, ele, at.first, at.second)

    @Test
    fun peakOnFlatPlainShowsAtGeometricAngle() {
        val grid = TerrainBuilder(0.4, 1200.0).build()
        val result = PanoramaEngine.make(grid, listOf(peak("Hill", Place.north(10_000.0), 500.0)), eye, 20.0)

        val hill = result.peaks.single()
        // (500 - 2 - 6.8 m curvature drop) over 10 km is 2.81 degrees.
        assertEquals(2.81, hill.elevationAngle, 0.02)
        assertEquals(10.0, hill.distanceKm, 0.05)
        assertTrue(hill.bearing < 0.1 || hill.bearing > 359.9)
    }

    @ParameterizedTest(name = "{0}")
    @CsvSource(
        "Nagarkot to Everest, 27.7172, 85.52, 27.9880614, 86.92521, 77.4362, 141.623",
        "Pokhara to Dhaulagiri, 28.2096, 83.9856, 28.6967, 83.4875, 318.0128, 72.763",
        "Lukla to Kangchenjunga, 27.6869, 86.7314, 27.7030109, 88.1474775, 88.9387, 139.689",
    )
    fun greatCircleMatchesTheWgs84Geodesic(
        name: String, lat1: Double, lon1: Double, lat2: Double, lon2: Double, bearing: Double, km: Double,
    ) {
        // Reference numbers come from pyproj's WGS84 geodesic. A sphere is off by up to 0.15 degrees of bearing
        // and 0.3 percent of distance, which is small beside a phone compass that is often 5 degrees out.
        val (distance, radians) = PanoramaEngine.greatCircle(lat1, lon1, lat2, lon2)

        assertEquals(bearing, (Math.toDegrees(radians) + 360) % 360, 0.2, name)
        assertEquals(km, distance / 1000, km * 0.005, name)
    }

    @Test
    fun peakDueEastHasBearingNinety() {
        val grid = TerrainBuilder(0.4, 1200.0).build()
        val result = PanoramaEngine.make(grid, listOf(peak("East", Place.east(8_000.0), 400.0)), eye, 20.0)

        assertEquals(90.0, result.peaks.single().bearing, 0.1)
    }

    @Test
    fun earthCurvatureHidesADistantPeakOnAFlatPlain() {
        val grid = TerrainBuilder(2.0, 120.0, north = 31.0).build()
        val far = peak("Far", Place.north(100_000.0), 300.0)
        val near = peak("Near", Place.north(20_000.0), 300.0)
        val result = PanoramaEngine.make(grid, listOf(far, near), eye, 120.0)

        // At 100 km the surface has dropped 683 m, so a 300 m summit is below the horizon. At 20 km the drop is 27 m.
        assertEquals(listOf("Near"), result.peaks.map { it.name })
    }

    @Test
    fun aTallRidgeHidesAPeakAndALowOneDoesNot() {
        val terrain = TerrainBuilder(0.6, 1200.0, north = 30.2)
        val behind = peak("Behind", Place.north(30_000.0), 800.0)

        terrain.raiseRow(Place.north(5_000.0).first, 300)
        assertTrue(PanoramaEngine.make(terrain.build(), listOf(behind), eye, 40.0).peaks.isEmpty())

        terrain.raiseRow(Place.north(5_000.0).first, 30)
        assertEquals(listOf("Behind"), PanoramaEngine.make(terrain.build(), listOf(behind), eye, 40.0).peaks.map { it.name })
    }

    @Test
    fun nearbyLowBumpsAreIgnoredButNearbyWallsAreNot() {
        val terrain = TerrainBuilder(0.4, 1200.0)
        val behind = peak("Behind", Place.north(10_000.0), 500.0)

        terrain.raiseRow(Place.north(300.0).first, 5)
        assertEquals(listOf("Behind"), PanoramaEngine.make(terrain.build(), listOf(behind), eye, 20.0).peaks.map { it.name })

        terrain.raiseRow(Place.north(300.0).first, 40)
        assertTrue(PanoramaEngine.make(terrain.build(), listOf(behind), eye, 20.0).peaks.isEmpty())
    }

    @Test
    fun skylineFollowsARidgeInItsOwnDirectionOnly() {
        val terrain = TerrainBuilder(0.4, 1200.0)
        terrain.raiseRow(Place.north(3_000.0).first, 200)
        val result = PanoramaEngine.make(terrain.build(), emptyList(), eye, 15.0)

        // (200 - 2 - 0.6) over 3 km is 3.77 degrees to the north, and the plain is flat to the south.
        assertEquals(3.77, result.skylineAngle(0.0), 0.1)
        assertTrue(result.skylineAngle(180.0) < 0)
    }

    @Test
    fun nearerLayersLeaveOutRidgesBeyondTheirRange() {
        val terrain = TerrainBuilder(0.6, 1200.0, north = 30.2)
        terrain.raiseRow(Place.north(20_000.0).first, 600)
        val result = PanoramaEngine.make(terrain.build(), emptyList(), eye, 30.0)

        val twelveKm = result.layers.single { it.rangeKm == 12.0 }
        // The wall stands 20 km away: invisible inside 12 km, 1.7 degrees high in the full skyline.
        assertTrue(twelveKm.angles[0] < 0)
        assertTrue(result.skyline[0] > 1.5)
    }

    @Test
    fun gridReturnsTheCellUnderAPointAndNaNOutside() {
        val terrain = TerrainBuilder(0.4, 1200.0)
        terrain.raiseRow(Place.north(3_000.0).first, 123)
        val grid = terrain.build()

        assertEquals(123.0, grid.height(Place.north(3_000.0).first, Place.LONGITUDE))
        assertEquals(0.0, grid.height(Place.LATITUDE, Place.LONGITUDE))
        assertTrue(grid.height(31.0, Place.LONGITUDE).isNaN())
    }

    @Test
    fun gridRejectsAFileOfTheWrongSize() {
        val header = GridHeader(30.0, 85.0, 10, 10, 10.0)
        assertThrows<IllegalArgumentException> { ElevationGrid(header, ShortBuffer.allocate(5)) }
    }

    @Test
    fun eyeHeightIsNullOutsideTheGrid() {
        val grid = TerrainBuilder(0.4, 1200.0).build()

        assertNull(PanoramaEngine.eyeHeight(grid, 40.0, 85.2))
        assertEquals(1.7, PanoramaEngine.eyeHeight(grid, Place.LATITUDE, Place.LONGITUDE)!!, 1e-9)
        assertTrue(abs(PanoramaEngine.eyeHeight(grid, Place.LATITUDE, Place.LONGITUDE, aboveGround = 5.0)!! - 5.0) < 1e-9)
    }
}
