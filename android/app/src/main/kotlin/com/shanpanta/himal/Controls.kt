package com.shanpanta.himal

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.shanpanta.himal.core.Viewpoint
import java.util.Locale
import kotlin.math.abs
import kotlin.math.roundToInt

private val Accent = Color(0xFF299EED)
private val ControlWhite = Color.White.copy(alpha = 0.95f)

@Composable
fun RoundButton(icon: ImageVector, description: String, isActive: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(44.dp)
            .shadow(3.dp, CircleShape)
            .background(if (isActive) Accent else ControlWhite, CircleShape)
            .clickable(onClick = onClick)
            .semantics { contentDescription = description },
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = null, tint = if (isActive) Color.White else Color.Black)
    }
}

/** A white dial that turns so its blue needle keeps pointing at north, with the heading in degrees under it. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun CompassDial(heading: Double, isFollowing: Boolean, onClick: () -> Unit, onLongClick: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp),
        modifier = Modifier
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .semantics { contentDescription = "Compass, heading ${heading.roundToInt()} degrees" },
    ) {
        Box(Modifier.size(44.dp).shadow(3.dp, CircleShape).background(ControlWhite, CircleShape)) {
            Canvas(Modifier.size(44.dp)) {
                val radius = size.width / 2 - 7 * density
                val unit = density
                rotate(-heading.toFloat(), pivot = center) {
                    val north = Path().apply {
                        moveTo(center.x, center.y - radius)
                        lineTo(center.x + 6 * unit, center.y + 2 * unit)
                        lineTo(center.x - 6 * unit, center.y + 2 * unit)
                        close()
                    }
                    val south = Path().apply {
                        moveTo(center.x, center.y + radius)
                        lineTo(center.x + 6 * unit, center.y - 2 * unit)
                        lineTo(center.x - 6 * unit, center.y - 2 * unit)
                        close()
                    }
                    drawPath(south, Color.Black.copy(alpha = 0.35f))
                    drawPath(north, Accent)
                }
            }
            if (isFollowing) {
                Box(Modifier.size(9.dp).offset(x = 37.dp, y = (-2).dp).background(Accent, CircleShape))
            }
        }
        Text(
            "${heading.roundToInt() % 360}°",
            color = Color.Black,
            fontSize = 11.sp,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.background(ControlWhite, RoundedCornerShape(5.dp)).padding(horizontal = 5.dp, vertical = 1.dp),
        )
    }
}

@Composable
fun LocationChip(viewpoint: Viewpoint) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        modifier = Modifier
            .shadow(2.dp, RoundedCornerShape(9.dp))
            .background(ControlWhite, RoundedCornerShape(9.dp))
            .padding(horizontal = 9.dp, vertical = 5.dp),
    ) {
        Icon(Icons.Filled.LocationOn, contentDescription = null, tint = Color.Gray, modifier = Modifier.size(14.dp))
        Text(coordinates(viewpoint), color = Color.Black, fontSize = 11.sp, fontWeight = FontWeight.Medium)
    }
}

internal fun coordinates(viewpoint: Viewpoint): String {
    val lat = String.format(Locale.US, "%.5f°%s", abs(viewpoint.latitude), if (viewpoint.latitude >= 0) "N" else "S")
    val lon = String.format(Locale.US, "%.5f°%s", abs(viewpoint.longitude), if (viewpoint.longitude >= 0) "E" else "W")
    return "$lat, $lon ${viewpoint.eyeHeight.roundToInt()} m"
}

/** Raw sensor values, shown by a long press on the compass dial, for checking the app against a real phone. */
@Composable
fun Diagnostics(model: PanoramaViewModel) {
    val accuracy = model.compassAccuracy?.let { "level $it of 3" } ?: "none"
    val lens = model.lens
    Text(
        String.format(
            Locale.US,
            "heading %.1f°  accuracy %s\npitch %.1f°  roll %.1f°\nlens %.1f° long side, aspect %.2f\nfollowing compass %s",
            model.heading, accuracy, model.pitch, model.roll, lens.longAxisFieldOfView, lens.imageAspect,
            if (model.followsCompass) "yes" else "no",
        ),
        color = Color.White,
        fontSize = 11.sp,
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        modifier = Modifier.background(Color.Black.copy(alpha = 0.7f), RoundedCornerShape(8.dp)).padding(8.dp),
    )
}

internal val CameraIcon: ImageVector get() = Icons.Filled.CameraAlt
