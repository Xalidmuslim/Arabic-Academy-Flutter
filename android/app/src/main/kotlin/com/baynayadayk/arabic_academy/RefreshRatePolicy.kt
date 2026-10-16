package com.example.arabic_academy

import kotlin.math.abs

/**
 * Choose the highest useful display rate not exceeding the 120 Hz target.
 * Frequencies like 119.88 Hz are deliberately treated as 120 Hz.
 *
 * This is a display-policy hint, NOT a promise of 120 rendered FPS.
 * Android may impose a battery, thermal, accessibility or user-selected cap.
 */
internal object RefreshRatePolicy {
    const val targetHz = 120.0f
    private const val tolerance = 0.6f

    fun selectAvailableHz(
        rates: Collection<Float>,
        powerSaving: Boolean,
    ): Float {
        if (powerSaving) return 0f

        val valid = rates.filter { it.isFinite() && it >= 59f }
        if (valid.isEmpty()) return 0f

        val bestUpTo120 = valid.filter { it <= targetHz + tolerance }.maxOrNull()
        // Do not ask for 144/165 Hz merely because the display supports it:
        // keep thermal/battery impact bounded at approximately 120 Hz.
        val best = bestUpTo120 ?: return 0f
        return if (best >= 89f) best else 0f
    }

    fun bestMatchingMode(
        supported: Collection<DisplayModeDescriptor>,
        currentWidth: Int,
        currentHeight: Int,
        desiredHz: Float,
    ): DisplayModeDescriptor? {
        if (desiredHz < 89f) return null
        return supported
            .filter {
                it.width == currentWidth &&
                    it.height == currentHeight &&
                    abs(it.refreshHz - desiredHz) < tolerance
            }
            .minByOrNull { abs(it.refreshHz - desiredHz) }
    }
}

internal data class DisplayModeDescriptor(
    val id: Int,
    val width: Int,
    val height: Int,
    val refreshHz: Float,
)
