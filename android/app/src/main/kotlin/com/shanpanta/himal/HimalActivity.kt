package com.shanpanta.himal

import android.Manifest
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class HimalActivity : ComponentActivity() {
    private val model: PanoramaViewModel by viewModels()
    private lateinit var sensors: Sensors

    private val permissions = registerForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        // The location listener only starts once the permission is granted.
        sensors.startLocation()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false)
        WindowInsetsControllerCompat(window, window.decorView).apply {
            hide(WindowInsetsCompat.Type.systemBars())
            systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }
        sensors = Sensors(this, model)
        if (savedInstanceState == null) model.start(intent.extras)
        setContent { HimalScreen(model) }
        permissions.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.CAMERA))
    }

    override fun onResume() {
        super.onResume()
        sensors.start()
    }

    override fun onPause() {
        sensors.stop()
        super.onPause()
    }
}
