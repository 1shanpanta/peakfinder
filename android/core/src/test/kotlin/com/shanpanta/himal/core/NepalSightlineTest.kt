package com.shanpanta.himal.core

import java.io.File
import java.io.RandomAccessFile
import java.nio.channels.FileChannel
import kotlin.math.abs
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertFalse
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Assumptions.assumeTrue
import org.junit.jupiter.api.Test

/** Real Nepal data, run only where `tools/build-data.py` has been run. Sightlines are well-known facts. */
class NepalSightlineTest {
    private val data = File(System.getProperty("himal.data") ?: "shared/data")
    private val demFile = File(data, "nepal-dem.i16")

    private fun panorama(lat: Double, lon: Double, eye: Double? = null): Panorama {
        assumeTrue(demFile.exists(), "run tools/build-data.py to pack the Nepal data")
        val header = HimalData.header(File(data, "nepal-dem.json").readText())
        val bytes = RandomAccessFile(demFile, "r").use { it.channel.map(FileChannel.MapMode.READ_ONLY, 0, it.length()) }
        val grid = HimalData.grid(header, bytes)
        val peaks = HimalData.peaks(File(data, "nepal-peaks.json").readText())
        val height = eye ?: PanoramaEngine.eyeHeight(grid, lat, lon)!!
        return PanoramaEngine.make(grid, peaks, Viewpoint(lat, lon, height))
    }

    @Test
    fun everestShowsFromNagarkotDueEastNorthEast() {
        val everest = panorama(27.7172, 85.52, 2175.0).peaks.first { it.name == "Mount Everest" }

        // WGS84 geodesic from pyproj: 77.44 degrees, 141.62 km.
        assertEquals(77.44, everest.bearing, 0.15)
        assertEquals(141.62, everest.distanceKm, 0.8)
    }

    @Test
    fun langtangLirungStandsDueNorthOfNagarkot() {
        val langtang = panorama(27.7172, 85.52, 2175.0).peaks.first { it.name == "Langtang Lirung" }

        assertTrue(abs(langtang.bearing - 359.7) < 1 || langtang.bearing < 1)
    }

    @Test
    fun machapuchareDominatesPokharaAndEverestIsNotInSight() {
        val names = panorama(28.2096, 83.9856).peaks.map { it.name }

        assertTrue(names.any { it.lowercase().contains("machapuchare") || it.lowercase().contains("fishtail") })
        assertFalse(names.contains("Mount Everest"))
    }

    @Test
    fun aValleyFloorSeesFarFewerPeaksThanAHillTop() {
        val valley = panorama(27.6710, 85.4298)
        val hillTop = panorama(27.7172, 85.52, 2175.0)

        assertTrue(valley.peaks.size < hillTop.peaks.size)
    }
}
