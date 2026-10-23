package com.shanpanta.himal.core

import java.nio.ShortBuffer
import kotlinx.serialization.Serializable

@Serializable
data class GridHeader(
    val north: Double,
    val west: Double,
    val rows: Int,
    val cols: Int,
    val cellsPerDegree: Double,
)

/**
 * Row-major int16 heights in metres, north row first.
 * Reading by absolute index leaves the buffer untouched, so many threads can read one grid.
 */
class ElevationGrid(val header: GridHeader, private val samples: ShortBuffer) {
    init {
        require(samples.capacity() == header.rows * header.cols) {
            "expected ${header.rows * header.cols} samples, got ${samples.capacity()}"
        }
    }

    /** Nearest-cell height in metres, or NaN outside the grid. */
    fun height(latitude: Double, longitude: Double): Double {
        val row = (header.north - latitude) * header.cellsPerDegree
        val col = (longitude - header.west) * header.cellsPerDegree
        if (row < 0 || col < 0 || row >= header.rows || col >= header.cols) return Double.NaN
        return samples.get(row.toInt() * header.cols + col.toInt()).toDouble()
    }
}
