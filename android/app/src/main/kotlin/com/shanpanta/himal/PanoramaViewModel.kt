package com.shanpanta.himal

import android.app.Application
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.shanpanta.himal.core.CameraOptics
import com.shanpanta.himal.core.DevicePose
import com.shanpanta.himal.core.HimalData
import com.shanpanta.himal.core.ElevationGrid
import com.shanpanta.himal.core.PanoramaEngine
import com.shanpanta.himal.core.Panorama
import com.shanpanta.himal.core.PeakRecord
import com.shanpanta.himal.core.Viewpoint
import java.io.FileInputStream
import java.nio.channels.FileChannel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class NepalData(val grid: ElevationGrid, val peaks: List<PeakRecord>)

/** What the camera optics need to know about the running camera. */
data class CameraLens(
    /** Field of view in degrees along the long side of the image. */
    val longAxisFieldOfView: Double,
    /** Long side over short side of the preview image. */
    val imageAspect: Double,
)

class PanoramaViewModel(application: Application) : AndroidViewModel(application) {
    sealed interface Status {
        data object Loading : Status
        data object Ready : Status
        data class Failed(val reason: String) : Status
    }

    var status by mutableStateOf<Status>(Status.Loading)
        private set
    var panorama by mutableStateOf<Panorama?>(null)
        private set
    var isDemo by mutableStateOf(false)
        private set

    /** A typical phone main camera until the real one reports in. */
    var lens by mutableStateOf(CameraLens(69.4, 4.0 / 3))
        private set

    var heading by mutableDoubleStateOf(78.0)
        private set
    var pitch by mutableDoubleStateOf(0.0)
        private set
    var roll by mutableDoubleStateOf(0.0)
        private set
    var fieldOfView by mutableDoubleStateOf(28.0)
        private set
    var usesCamera by mutableStateOf(false)
        private set
    var followsCompass by mutableStateOf(false)
        private set
    var showsDiagnostics by mutableStateOf(false)
        private set

    /** The sensor accuracy constant of the compass, or null before the first reading. */
    var compassAccuracy by mutableStateOf<Int?>(null)
        private set

    private var data: NepalData? = null
    private var requested: Pair<Double, Double>? = null
    private var computedFor: Pair<Double, Double>? = null
    private var isComputing = false

    /** A viewpoint given at launch stays, so an emulator run is not moved by its own fake GPS. */
    private var isPinned = false

    /** Degrees to add to a magnetic heading to get a true one. */
    private var declination = 0.0

    fun start(launchExtras: Bundle?) {
        applyLaunchExtras(launchExtras)
        viewModelScope.launch {
            try {
                data = withContext(Dispatchers.IO) { loadData() }
                refresh()
            } catch (error: Exception) {
                status = Status.Failed(error.message ?: error.toString())
            }
        }
        viewModelScope.launch {
            delay(4_000)
            if (requested == null) useDemoViewpoint()
        }
    }

    fun locationUpdate(location: Location, magneticDeclination: Double) {
        declination = magneticDeclination
        if (isPinned) return
        isDemo = false
        requested = location.latitude to location.longitude
        refresh()
    }

    fun applyPose(pose: DevicePose) {
        if (followsCompass) heading = blend(heading, (pose.bearing + declination + 360) % 360, 0.35)
        if (usesCamera) {
            pitch += (pose.pitch - pitch) * 0.25
            roll += (pose.roll - roll) * 0.25
        }
    }

    fun updateCompassAccuracy(accuracy: Int) {
        compassAccuracy = accuracy
    }

    fun updateLens(newLens: CameraLens) {
        lens = newLens
    }

    fun toggleCamera() {
        usesCamera = !usesCamera
        if (usesCamera) followsCompass = true
    }

    fun toggleFollowsCompass() {
        followsCompass = !followsCompass
    }

    fun toggleDiagnostics() {
        showsDiagnostics = !showsDiagnostics
    }

    /** A drag or pinch. [panPixels] is the horizontal drag and [zoom] is 1 for no pinch. */
    fun transform(panPixels: Float, zoom: Float, widthPixels: Float) {
        if (panPixels != 0f) {
            followsCompass = false
            val pointsPerDegree = widthPixels / visibleFieldOfView(widthPixels, 0f)
            heading = ((heading - panPixels / pointsPerDegree) % 360 + 360) % 360
        }
        if (zoom != 1f && !usesCamera) fieldOfView = (fieldOfView / zoom).coerceIn(8.0, 100.0)
    }

    fun visibleFieldOfView(widthPixels: Float, heightPixels: Float): Double {
        if (!usesCamera) return fieldOfView
        return CameraOptics.horizontalFieldOfView(
            lens.longAxisFieldOfView, lens.imageAspect, widthPixels.toDouble(), heightPixels.toDouble(),
        )
    }

    private fun useDemoViewpoint() {
        isDemo = true
        requested = DEMO_VIEWPOINT
        refresh()
    }

    private fun refresh() {
        val loaded = data ?: return
        val target = requested ?: return
        if (isComputing) return
        computedFor?.let { done -> if (distanceMeters(done, target) < RECOMPUTE_DISTANCE) return }
        isComputing = true
        viewModelScope.launch {
            var shown = target
            var result = withContext(Dispatchers.Default) { render(loaded, shown) }
            if (result == null) {
                shown = DEMO_VIEWPOINT
                isDemo = true
                result = withContext(Dispatchers.Default) { render(loaded, shown) }
            }
            panorama = result
            computedFor = shown
            status = if (result == null) Status.Failed("No terrain under the viewpoint") else Status.Ready
            isComputing = false
        }
    }

    private fun render(loaded: NepalData, at: Pair<Double, Double>): Panorama? {
        val eye = PanoramaEngine.eyeHeight(loaded.grid, at.first, at.second) ?: return null
        val started = System.nanoTime()
        val panorama = PanoramaEngine.make(loaded.grid, loaded.peaks, Viewpoint(at.first, at.second, eye))
        Log.i("Himal", "panorama with ${panorama.peaks.size} peaks in ${(System.nanoTime() - started) / 1_000_000} ms")
        return panorama
    }

    private fun loadData(): NepalData {
        val assets = getApplication<Application>().assets
        val header = HimalData.header(assets.open("nepal-dem.json").bufferedReader().use { it.readText() })
        val peaks = HimalData.peaks(assets.open("nepal-peaks.json").bufferedReader().use { it.readText() })
        // The terrain is stored uncompressed in the APK, so it maps straight from there and never enters the heap.
        val bytes = assets.openFd("nepal-dem.i16").use { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.use {
                it.map(FileChannel.MapMode.READ_ONLY, descriptor.startOffset, descriptor.length)
            }
        }
        return NepalData(HimalData.grid(header, bytes), peaks)
    }

    /** Lets an emulator run start from a known view: `--ed lat 27.7 --ed lon 85.5 --ed heading 78 --ez camera true`. */
    private fun applyLaunchExtras(extras: Bundle?) {
        extras ?: return
        if (extras.containsKey("lat") && extras.containsKey("lon")) {
            requested = extras.getDouble("lat") to extras.getDouble("lon")
            isPinned = true
        }
        if (extras.containsKey("heading")) heading = extras.getDouble("heading")
        if (extras.containsKey("fov")) fieldOfView = extras.getDouble("fov")
        usesCamera = extras.getBoolean("camera", false)
    }

    private fun distanceMeters(a: Pair<Double, Double>, b: Pair<Double, Double>): Double {
        val result = FloatArray(1)
        Location.distanceBetween(a.first, a.second, b.first, b.second, result)
        return result[0].toDouble()
    }

    private fun blend(current: Double, target: Double, amount: Double): Double {
        val delta = (target - current + 540) % 360 - 180
        return (current + delta * amount + 360) % 360
    }

    private companion object {
        /** The hill-top viewpoint used before a position arrives and outside Nepal. */
        val DEMO_VIEWPOINT = 27.7172 to 85.5200
        const val RECOMPUTE_DISTANCE = 150.0
    }
}
