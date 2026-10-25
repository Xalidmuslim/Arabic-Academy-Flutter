package com.example.arabic_academy

import java.util.ArrayDeque
import kotlin.math.roundToInt

/** Observed callback intervals, never inferred from display Hz or draw cost. */
internal class FrameCadenceWindow(private val capacity: Int = 300) {
    private val times = ArrayDeque<Long>()

    fun clear() = times.clear()

    fun add(timeNanos: Long) {
        if (times.isNotEmpty() && timeNanos <= times.peekLast()) return
        times.addLast(timeNanos)
        if (times.size > capacity) times.removeFirst()
    }

    fun snapshot(): Map<String, Any> {
        if (times.size < 2) return mapOf("samples" to times.size, "hz" to 0.0)
        val values = times.toList()
        val intervals = values.zipWithNext { a, b -> b - a }.sorted()
        val total = values.last() - values.first()
        fun percentile(fraction: Double) =
            intervals[((intervals.size - 1) * fraction).roundToInt()] / 1e6
        return mapOf(
            "samples" to values.size,
            "hz" to (values.size - 1) * 1e9 / total,
            "intervalP50Ms" to percentile(.50),
            "intervalP95Ms" to percentile(.95),
        )
    }
}
