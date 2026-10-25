package com.example.arabic_academy

import android.view.Choreographer

/** Only active during an explicitly requested diagnostic scroll sample. */
internal class ScrollVsyncProbe : Choreographer.FrameCallback {
    private val window = FrameCadenceWindow()
    private var active = false
    private var session = 0L
    private val choreographer by lazy { Choreographer.getInstance() }

    fun start(id: Long) {
        stop()
        session = id
        window.clear()
        active = true
        choreographer.postFrameCallback(this)
    }

    override fun doFrame(frameTimeNanos: Long) {
        if (!active) return
        window.add(frameTimeNanos)
        choreographer.postFrameCallback(this)
    }

    fun stop(): Map<String, Any> {
        if (active) choreographer.removeFrameCallback(this)
        active = false
        return window.snapshot() + ("session" to session)
    }
}
