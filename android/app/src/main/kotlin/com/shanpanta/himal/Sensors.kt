package com.shanpanta.himal

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.GeomagneticField
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.view.Surface
import android.view.WindowManager
import androidx.core.content.ContextCompat
import com.shanpanta.himal.core.DevicePose

/** Feeds the compass pose and the position into the view model. Call [start] and [stop] with the screen. */
class Sensors(private val context: Context, private val model: PanoramaViewModel) : SensorEventListener, LocationListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val locationManager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val rotation = FloatArray(9)
    private val remapped = FloatArray(9)

    /** The rotation vector sensor fuses the gyroscope, accelerometer and magnetometer, and is relative to magnetic north. */
    fun start() {
        sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        startLocation()
    }

    @SuppressLint("MissingPermission")
    fun startLocation() {
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        if (!granted) return
        for (provider in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
            if (!locationManager.isProviderEnabled(provider)) continue
            locationManager.getLastKnownLocation(provider)?.let(::onLocationChanged)
            locationManager.requestLocationUpdates(provider, 2_000L, 50f, this)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        locationManager.removeUpdates(this)
    }

    override fun onSensorChanged(event: SensorEvent) {
        SensorManager.getRotationMatrixFromVector(rotation, event.values)
        // The matrix is in the phone's natural axes. Remapping makes them follow the screen, so roll and the
        // camera direction stay right when the screen is turned sideways.
        val (axisX, axisY) = when (displayRotation()) {
            Surface.ROTATION_90 -> SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
            Surface.ROTATION_180 -> SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
            Surface.ROTATION_270 -> SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
            else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
        }
        SensorManager.remapCoordinateSystem(rotation, axisX, axisY, remapped)
        model.applyPose(DevicePose(remapped))
    }

    override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
        model.updateCompassAccuracy(accuracy)
    }

    override fun onLocationChanged(location: Location) {
        val field = GeomagneticField(
            location.latitude.toFloat(), location.longitude.toFloat(), location.altitude.toFloat(), System.currentTimeMillis(),
        )
        model.locationUpdate(location, field.declination.toDouble())
    }

    // Android 10 and older call these, and the interface has no default for them there.
    @Deprecated("Required below Android 11")
    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

    override fun onProviderEnabled(provider: String) {}

    override fun onProviderDisabled(provider: String) {}

    @Suppress("DEPRECATION")
    private fun displayRotation(): Int =
        (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).defaultDisplay.rotation
}
