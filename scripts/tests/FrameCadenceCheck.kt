package com.example.arabic_academy

import kotlin.math.abs

fun main() {
    fun sample(step: Long): Map<String, Any> {
        val window = FrameCadenceWindow()
        repeat(121) { window.add(it * step) }
        return window.snapshot()
    }
    check(abs((sample(8333333L)["hz"] as Double) - 120.0) < .01)
    check(abs((sample(16666667L)["hz"] as Double) - 60.0) < .01)
    val bounded = FrameCadenceWindow(10)
    repeat(1000) { bounded.add(it * 10000000L) }
    check(bounded.snapshot()["samples"] == 10)
    bounded.add(1L)
    check(bounded.snapshot()["samples"] == 10)
    bounded.clear()
    check(bounded.snapshot()["hz"] == 0.0)
    println("Native cadence: 60/120 Hz, bounded history, stale callbacks and reset passed.")
}
