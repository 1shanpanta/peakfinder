package com.shanpanta.himal

import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTransformGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val SkyTop = Color(0.33f, 0.56f, 0.82f)
private val SkyHorizon = Color(0.86f, 0.92f, 0.97f)

@Composable
fun HimalScreen(model: PanoramaViewModel) {
    BoxWithConstraints(
        Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(0f to SkyTop, 0.75f to SkyHorizon, 1f to SkyHorizon))
            .pointerInput(Unit) {
                detectTransformGestures { _, pan, zoom, _ -> model.transform(pan.x, zoom, size.width.toFloat()) }
            },
    ) {
        val density = LocalDensity.current
        val widthPixels = with(density) { maxWidth.toPx() }
        val heightPixels = with(density) { maxHeight.toPx() }
        val fieldOfView = model.visibleFieldOfView(widthPixels, heightPixels)

        if (model.usesCamera) CameraPreview(onLens = model::updateLens, modifier = Modifier.fillMaxSize())
        model.panorama?.let { panorama ->
            PanoramaCanvas(
                panorama = panorama,
                heading = model.heading,
                pitch = model.pitch,
                fieldOfView = fieldOfView,
                drawsTerrain = !model.usesCamera,
                modifier = Modifier.fillMaxSize().rotate(if (model.usesCamera) -model.roll.toFloat() else 0f),
            )
        }
        Overlay(model)
    }
}

@Composable
private fun Overlay(model: PanoramaViewModel) {
    Box(Modifier.fillMaxSize().safeDrawingPadding().padding(16.dp)) {
        Row(Modifier.fillMaxWidth().align(Alignment.TopCenter), horizontalArrangement = Arrangement.SpaceBetween) {
            RoundButton(CameraIcon, "Camera", model.usesCamera, model::toggleCamera)
            CompassDial(model.heading, model.followsCompass, model::toggleFollowsCompass, model::toggleDiagnostics)
        }
        Column(Modifier.align(Alignment.BottomCenter), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            if (model.showsDiagnostics) Diagnostics(model)
            model.panorama?.let { LocationChip(it.viewpoint) }
        }
        StatusMessage(model)
    }
}

@Composable
private fun BoxScope.StatusMessage(model: PanoramaViewModel) {
    when (val status = model.status) {
        PanoramaViewModel.Status.Loading -> Message("Loading terrain", Modifier.align(Alignment.Center))
        is PanoramaViewModel.Status.Failed -> Message(status.reason, Modifier.align(Alignment.Center))
        PanoramaViewModel.Status.Ready ->
            if (model.isDemo) Message("Demo view from Nagarkot. Himal only has Nepal.", Modifier.align(Alignment.TopCenter).padding(top = 70.dp))
    }
}

@Composable
private fun Message(text: String, modifier: Modifier) {
    Text(
        text,
        color = Color.Black,
        fontSize = 13.sp,
        fontWeight = FontWeight.Medium,
        modifier = modifier.background(Color.White.copy(alpha = 0.85f), RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 8.dp),
    )
}
