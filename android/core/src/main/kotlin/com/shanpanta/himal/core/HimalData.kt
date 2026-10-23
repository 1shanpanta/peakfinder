package com.shanpanta.himal.core

import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlinx.serialization.json.Json

/** Reads the packed files written by `tools/build-data.py`. */
object HimalData {
    private val json = Json { ignoreUnknownKeys = true }

    fun header(text: String): GridHeader = json.decodeFromString(text)

    fun peaks(text: String): List<PeakRecord> = json.decodeFromString(text)

    /** The bytes are int16 little-endian, which is what every Android and Apple device is. */
    fun grid(header: GridHeader, bytes: ByteBuffer): ElevationGrid =
        ElevationGrid(header, bytes.order(ByteOrder.LITTLE_ENDIAN).asShortBuffer())
}
