package com.example.arabic_academy

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RefreshRatePolicyTest {
    @Test
    fun selectsNative120HzWhenSupported() {
        val selected = RefreshRatePolicy.selectAvailableHz(
            listOf(60f, 90f, 119.88f, 144f),
            powerSaving = false,
        )
        assertEquals(119.88f, selected, 0.01f)
    }

    @Test
    fun selects90HzOnDevicesWithout120Hz() {
        val selected = RefreshRatePolicy.selectAvailableHz(
            listOf(60f, 89.91f),
            powerSaving = false,
        )
        assertEquals(89.91f, selected, 0.01f)
    }

    @Test
    fun preservesAndroidDefaultOn60HzOnlyOrBatterySaver() {
        assertEquals(
            0f,
            RefreshRatePolicy.selectAvailableHz(listOf(60f), false),
            0.01f,
        )
        assertEquals(
            0f,
            RefreshRatePolicy.selectAvailableHz(listOf(60f, 120f), true),
            0.01f,
        )
        assertEquals(
            0f,
            RefreshRatePolicy.selectAvailableHz(listOf(144f), false),
            0.01f,
        )
    }

    @Test
    fun rejectsInvalidRates() {
        assertEquals(
            0f,
            RefreshRatePolicy.selectAvailableHz(
                listOf(Float.NaN, Float.POSITIVE_INFINITY, -1f), false
            ),
            0.01f,
        )
    }

    @Test
    fun prefersModeWithSamePhysicalResolutionToAvoidModeSizeSwitch() {
        val selected = RefreshRatePolicy.bestMatchingMode(
            listOf(
                DisplayModeDescriptor(1, 1080, 2400, 60f),
                DisplayModeDescriptor(2, 1440, 3200, 120f),
                DisplayModeDescriptor(3, 1080, 2400, 119.88f),
            ),
            currentWidth = 1080,
            currentHeight = 2400,
            desiredHz = 119.88f,
        )
        assertEquals(3, selected?.id)
    }

    @Test
    fun doesNotForceUnsupportedResolutionOrRefreshMode() {
        val modes = listOf(DisplayModeDescriptor(1, 1440, 3200, 120f))
        assertNull(RefreshRatePolicy.bestMatchingMode(modes, 1080, 2400, 120f))
    }
}
