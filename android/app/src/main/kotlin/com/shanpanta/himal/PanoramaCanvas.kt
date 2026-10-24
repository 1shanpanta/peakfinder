package com.shanpanta.himal

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.withTransform
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.sp
import com.shanpanta.himal.core.Panorama
import com.shanpanta.himal.core.ViewProjection
import com.shanpanta.himal.core.VisiblePeak
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

private const val LABEL_TILT_DEGREES = -62f
private const val LABEL_SPACING_DP = 30f

/** Draws the ridges, skyline and tilted peak labels for one view direction. */
@Composable
fun PanoramaCanvas(
    panorama: Panorama,
    heading: Double,
    pitch: Double,
    fieldOfView: Double,
    /** True draws the shaded ridges of the flat panorama. False draws only the outline over the camera. */
    drawsTerrain: Boolean,
    modifier: Modifier = Modifier,
) {
    val measurer = rememberTextMeasurer()
    Canvas(modifier) {
        val view = ViewProjection(
            heading, pitch, fieldOfView, size.width.toDouble(), size.height.toDouble(),
            if (drawsTerrain) levelFraction(panorama, fieldOfView) else null,
        )
        if (drawsTerrain) drawRidges(panorama, view)
        drawSkyline(panorama, view, drawsTerrain)
        drawLabels(measurer, panorama, view, fieldOfView)
    }
}

/**
 * Puts the tallest skyline in any direction near mid-screen, so labels have sky above them and the ridges
 * get the rest of the height. It depends on the whole circle, not the visible slice, so panning does not jump.
 */
private fun DrawScope.levelFraction(panorama: Panorama, fieldOfView: Double): Double {
    val tallest = max(panorama.skyline.max().toDouble(), 0.0)
    return min(0.82, 0.52 + tallest * (size.width / fieldOfView) / size.height)
}

private class Ridge(val profile: (Double) -> Double, val rangeKm: Double)

/** Far ridges first, each nearer one drawn darker over it. Each ridge is paler at its crest, as if in haze. */
private fun DrawScope.drawRidges(panorama: Panorama, view: ViewProjection) {
    val ridges = listOf(Ridge(panorama::skylineAngle, panorama.rangeKm)) +
        panorama.layers.reversed().map { layer -> Ridge({ bearing -> layer.angle(bearing) }, layer.rangeKm) }
    ridges.forEachIndexed { index, ridge ->
        val depth = index.toDouble() / max(ridges.size - 1, 1)
        val edge = outline(softened(ridge.profile, spread(ridge.rangeKm)), view)
        val crest = edge.getBounds().top
        val area = Path().apply {
            addPath(edge)
            lineTo(view.width.toFloat() + 2, view.height.toFloat())
            lineTo(-2f, view.height.toFloat())
            close()
        }
        val haze = Brush.verticalGradient(
            colors = listOf(crestColor(depth), baseColor(depth)),
            startY = crest,
            endY = min(view.height.toFloat(), crest + view.height.toFloat() * 0.4f),
        )
        drawPath(area, haze)
    }
}

/** Averages a few nearby bearings. Near terrain comes from coarse cells and shows as steps, which this rounds off. */
private fun softened(profile: (Double) -> Double, spread: Double): (Double) -> Double {
    if (spread == 0.0) return profile
    val offsets = doubleArrayOf(-1.0, -0.5, 0.0, 0.5, 1.0).map { it * spread }
    return { bearing -> offsets.sumOf { profile(bearing + it) } / offsets.size }
}

private fun spread(rangeKm: Double): Double = when {
    rangeKm <= 4 -> 0.5
    rangeKm <= 12 -> 0.3
    rangeKm <= 30 -> 0.15
    else -> 0.0
}

private fun DrawScope.drawSkyline(panorama: Panorama, view: ViewProjection, drawsTerrain: Boolean) {
    drawPath(
        outline(panorama::skylineAngle, view),
        Color.Black.copy(alpha = if (drawsTerrain) 0.55f else 0.85f),
        style = Stroke(width = (if (drawsTerrain) 1f else 1.6f) * density),
    )
}

private fun outline(profile: (Double) -> Double, view: ViewProjection): Path {
    val path = Path()
    val step = 2.0
    var x = -step
    var first = true
    while (x <= view.width + step) {
        val point = Offset(x.toFloat(), view.y(profile(view.bearingAt(x))).toFloat())
        if (first) path.moveTo(point.x, point.y) else path.lineTo(point.x, point.y)
        first = false
        x += step
    }
    return path
}

private fun DrawScope.drawLabels(measurer: TextMeasurer, panorama: Panorama, view: ViewProjection, fieldOfView: Double) {
    val placed = mutableListOf<Double>()
    val reach = fieldOfView / 2 + 12
    for (peak in panorama.peaks) {
        if (abs(ViewProjection.wrap(peak.bearing - view.heading)) >= reach) continue
        val x = view.x(peak.bearing)
        if (placed.any { abs(it - x) < LABEL_SPACING_DP * density }) continue
        placed += x

        val foot = view.y(peak.elevationAngle)
        val top = min(foot, view.y(panorama.skylineAngle(peak.bearing))) - 22 * density
        drawLine(Color.Black.copy(alpha = 0.7f), Offset(x.toFloat(), foot.toFloat()), Offset(x.toFloat(), top.toFloat()), strokeWidth = 0.8f * density)
        drawPill(measurer, peak, Offset(x.toFloat(), top.toFloat()))
    }
}

private fun DrawScope.drawPill(measurer: TextMeasurer, peak: VisiblePeak, origin: Offset) {
    val text = measurer.measure(label(peak))
    val height = 22 * density
    val topLeft = Offset(-11 * density, -height)
    val pill = Size(text.size.width + 18 * density, height)
    withTransform({
        translate(origin.x, origin.y)
        rotate(LABEL_TILT_DEGREES, Offset.Zero)
    }) {
        drawRoundRect(Color.White.copy(alpha = 0.95f), topLeft, pill, CornerRadius(6 * density))
        drawRoundRect(Color.Black.copy(alpha = 0.2f), topLeft, pill, CornerRadius(6 * density), Stroke(0.5f * density))
        drawText(text, topLeft = Offset(topLeft.x + 9 * density, topLeft.y + (height - text.size.height) / 2))
    }
}

private fun label(peak: VisiblePeak): AnnotatedString = buildAnnotatedString {
    withStyle(SpanStyle(fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = Color.Black)) { append(peak.name) }
    withStyle(SpanStyle(fontSize = 9.5.sp, fontWeight = FontWeight.SemiBold, color = Color.Black.copy(alpha = 0.6f))) {
        append(" " + String.format(Locale.US, "%,d", peak.elevation.toInt()))
    }
}

private val FAR_RIDGE = Triple(0.68, 0.78, 0.89)
private val NEAR_RIDGE = Triple(0.10, 0.14, 0.19)
private val HORIZON_HAZE = Triple(0.86, 0.92, 0.97)
private val SHADE = Triple(0.03, 0.05, 0.08)

private fun mix(a: Triple<Double, Double, Double>, b: Triple<Double, Double, Double>, amount: Double) = Triple(
    a.first + (b.first - a.first) * amount,
    a.second + (b.second - a.second) * amount,
    a.third + (b.third - a.third) * amount,
)

private fun Triple<Double, Double, Double>.toColor() = Color(first.toFloat(), second.toFloat(), third.toFloat())

/** Depth 0 is the farthest ridge, pale and hazy. Depth 1 is the nearest, dark. */
private fun ridge(depth: Double) = mix(FAR_RIDGE, NEAR_RIDGE, depth)

/** The top of a far ridge fades toward the horizon haze. A near ridge keeps its own colour. */
internal fun crestColor(depth: Double): Color = mix(ridge(depth), HORIZON_HAZE, 0.5 * (1 - depth)).toColor()

/** The foot of a near ridge sinks toward black, so the nearest ground is not one flat block. */
internal fun baseColor(depth: Double): Color = mix(ridge(depth), SHADE, 0.35 * depth).toColor()
