package com.shanpanta.himal.core

import java.nio.ShortBuffer
import kotlin.math.cos

/** A flat sea-level square of terrain that tests raise into walls and bumps. */
class TerrainBuilder(degrees: Double, cellsPerDegree: Double, north: Double = 30.0, west: Double = 85.0) {
    private val cells = (degrees * cellsPerDegree).toInt()
    val header = GridHeader(north, west, cells, cells, cellsPerDegree)
    private val samples = ShortArray(cells * cells)

    /** Raises every cell in the row that contains [latitude], a wall running east to west. */
    fun raiseRow(latitude: Double, height: Int) {
        val row = ((header.north - latitude) * header.cellsPerDegree).toInt()
        for (col in 0 until header.cols) samples[row * header.cols + col] = height.toShort()
    }

    fun build() = ElevationGrid(header, ShortBuffer.wrap(samples.copyOf()))
}

object Place {
    const val LATITUDE = 29.8
    const val LONGITUDE = 85.2

    /** One degree of a great circle on the engine's sphere, in metres. */
    private val metersPerDegree = PanoramaEngine.EARTH_RADIUS * Math.PI / 180

    /** A point [meters] north of the viewpoint, as latitude and longitude. */
    fun north(meters: Double) = (LATITUDE + meters / metersPerDegree) to LONGITUDE

    /** A point [meters] east of the viewpoint, as latitude and longitude. */
    fun east(meters: Double) = LATITUDE to (LONGITUDE + meters / (metersPerDegree * cos(Math.toRadians(LATITUDE))))
}
