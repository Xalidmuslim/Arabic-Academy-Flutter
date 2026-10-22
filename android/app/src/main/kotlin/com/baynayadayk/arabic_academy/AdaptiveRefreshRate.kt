package com.example.arabic_academy

import android.app.Activity
import android.content.Context
import android.os.PowerManager
import android.util.Log
import android.os.Build
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
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
            // The Flutter Surface may have been recreated while the window
            // preference stayed unchanged (e.g. resume after locking phone).
            applyFlutterSurfaceRate(activity, wantedHz)
            return
        }
        old.preferredDisplayModeId = modeId
        old.preferredRefreshRate = wantedHz
        activity.window.attributes = old
        applyFlutterSurfaceRate(activity, wantedHz)

        Log.i(
            TAG,
            "requestedHz=$wantedHz supportedHz=${sameResolution.map { it.refreshHz }} " +
                "modeId=$modeId powerSave=$powerSave activeHz=${current.refreshRate}"
        )
    }

    private fun findFlutterSurface(view: View): SurfaceView? {
        // Do not send a high-frame-rate request to a video player SurfaceView:
        // only the surface rendered by the Flutter engine belongs here.
        if (view is SurfaceView &&
            view.javaClass.name.contains("FlutterSurfaceView")) return view
        if (view is ViewGroup) {
            for (index in 0 until view.childCount) {
                findFlutterSurface(view.getChildAt(index))?.let { return it }
            }
        }
        return null
    }

    private fun applyFlutterSurfaceRate(activity: Activity, rateHz: Float) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        activity.window.decorView.post {
            val target = findFlutterSurface(activity.window.decorView) ?: return@post
            val surface = target.holder.surface
            if (!surface.isValid) return@post
            try {
                // A Surface hint complements the window preference and lets
                // Android schedule Flutter's actual scroll frames at 90/120Hz.
                // Never force a mode switch that is not seamless.
                surface.setFrameRate(
                    rateHz,
                    Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                    Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
                )
                Log.i(TAG, "flutterSurfaceRequestedHz=$rateHz")
            } catch (error: IllegalArgumentException) {
                Log.w(TAG, "Frame rate hint rejected by this display", error)
            } catch (error: IllegalStateException) {
                Log.w(TAG, "Surface not yet ready for frame rate hint", error)
            }
        }
    }
}
