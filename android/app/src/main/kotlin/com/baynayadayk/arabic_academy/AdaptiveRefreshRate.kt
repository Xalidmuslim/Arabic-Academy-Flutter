package com.example.arabic_academy

import android.app.Activity
import android.content.Context
import android.os.PowerManager
import android.util.Log
import kotlin.math.abs

/**
 * Window-level preference for a device's supported 90/120 Hz display mode.
 *
 * Flutter's own vsync and raster threads still determine how many frames
 * are *actually* produced. We do not change animation timing, disable
 * effects or modify the user's Android-wide screen settings.
 */
internal object AdaptiveRefreshRate {
    private const val TAG = "BaynaRefreshRate"

    @Suppress("DEPRECATION")
    fun apply(activity: Activity) {
        val display = activity.window.decorView.display
            ?: activity.windowManager.defaultDisplay
            ?: return

        val current = display.mode
        val supported = display.supportedModes.map { mode ->
            DisplayModeDescriptor(
                id = mode.modeId,
                width = mode.physicalWidth,
                height = mode.physicalHeight,
                refreshHz = mode.refreshRate,
            )
        }
        // Do not fight Android's battery saver with a 120 Hz display request.
        val powerSave = (activity.getSystemService(Context.POWER_SERVICE)
            as? PowerManager)?.isPowerSaveMode == true
        val sameResolution = supported.filter {
            it.width == current.physicalWidth &&
                it.height == current.physicalHeight
        }
        val wantedHz = RefreshRatePolicy.selectAvailableHz(
            sameResolution.map { it.refreshHz },
            powerSaving = powerSave,
        )
        val selected = RefreshRatePolicy.bestMatchingMode(
            sameResolution,
            current.physicalWidth,
            current.physicalHeight,
            wantedHz,
        )

        val old = activity.window.attributes
        val modeId = selected?.id ?: 0
        // Window hints are advisory: the system may cap refresh frequency
        // for user preference, other apps, heat, power or the display driver.
        if (old.preferredDisplayModeId == modeId &&
            abs(old.preferredRefreshRate - wantedHz) < 0.01f) {
            return
        }
        old.preferredDisplayModeId = modeId
        old.preferredRefreshRate = wantedHz
        activity.window.attributes = old

        Log.i(
            TAG,
            "requestedHz=$wantedHz supportedHz=${sameResolution.map { it.refreshHz }} " +
                "modeId=$modeId powerSave=$powerSave activeHz=${current.refreshRate}"
        )
    }
}
