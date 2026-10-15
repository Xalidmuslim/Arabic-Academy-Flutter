package com.example.arabic_academy

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import com.googlecode.tesseract.android.TessBaseAPI
import kotlin.math.max
import kotlin.math.min

/**
 * Color-aware analysis of a privately imported Bayna Yadayk PDF page.
 *
 * The scan has a pale-yellow dialogue rectangle, blue prompts and ochre
 * answers. Detect the *background rectangle*, not the adjacent photograph.
 * Every coordinate is in page-render bitmap pixels; no pixel leaves the device.
 */
internal object ArabicDialogueColors {
    data class Recognition(val text: String, val blueLines: Int, val orangeLines: Int)
    private enum class Ink { BLUE, ORANGE }

    private fun yellow(color: Int): Boolean {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        // Cream-yellow paper: (254,250,207). White pages and garments must
        // never match. Stay tolerant to scanned shadows and JPEG compression.
        return r >= 185 && g >= 170 && b <= 242 &&
            r - b >= 30 && g - b >= 22 && r - g in -20..45
    }

    private fun ink(color: Int): Ink? {
        val r = Color.red(color)
        val g = Color.green(color)
        val b = Color.blue(color)
        // Muted ink must remain detectable, including thin vocalization.
        if (b >= r + 10 && b >= g + 8 && min(r, g) < 205) return Ink.BLUE
        if (r >= g + 17 && g >= b + 17 && r - b >= 55 && g < 228) {
            return Ink.ORANGE
        }
        return null
    }

    /**
     * Find a tall, continuous yellow column span intersecting the OCR text,
     * including its left border but excluding the neighboring illustration.
     * Fail closed when the background isn't recognizable.
     */
    fun yellowPanel(bitmap: Bitmap, textBox: Rect): Rect? {
        val width = bitmap.width
        val height = bitmap.height
        if (width < 90 || height < 90 || textBox.isEmpty()) return null
        val pixels = IntArray(width * height)
        bitmap.getPixels(pixels, 0, width, 0, 0, width, height)
        val y0 = textBox.top.coerceIn(0, height - 1)
        val y1 = textBox.bottom.coerceIn(y0 + 1, height)
        val yStep = max(2, (y1 - y0) / 360)
        val xBegin = (width * 0.12).toInt()
        val xEnd = (width * 0.995).toInt().coerceAtMost(width - 1)
        var bestStart = -1
        var bestEnd = -1
        var candidateStart = -1
        var candidateLast = -1
        var gaps = 0
        val anchor = textBox.centerX().coerceIn(0, width - 1)
        for (x in xBegin..(xEnd + 6)) {
            var yellowCount = 0
            var samples = 0
            if (x <= xEnd) {
                for (y in y0 until y1 step yStep) {
                    if (yellow(pixels[y * width + x])) yellowCount++
                    samples++
                }
            }
            val passes = x <= xEnd && samples > 0 &&
                yellowCount.toDouble() / samples >= 0.54
            if (passes) {
                if (candidateStart < 0) candidateStart = x
                candidateLast = x
                gaps = 0
            } else if (candidateStart >= 0) {
                gaps++
                if (gaps > 5 || x > xEnd) {
                    val span = candidateLast - candidateStart + 1
                    if (candidateStart <= anchor && candidateLast >= anchor &&
                        span > max(70, (width * .19).toInt()) &&
                        span > bestEnd - bestStart) {
                        bestStart = candidateStart
                        bestEnd = candidateLast
                    }
                    candidateStart = -1
                    candidateLast = -1
                    gaps = 0
                }
            }
        }
        if (bestStart < 0) return null

        val left = (bestStart + 2).coerceAtMost(bestEnd - 1)
        val right = (bestEnd - 1).coerceAtLeast(left + 1)
        // Search a little beyond the OCR bounds so blue text, omitted by a
        // previous monochrome pass, is not trimmed from the original image.
        val scanTop = (textBox.top - height * .055).toInt().coerceAtLeast(0)
        val scanBottom = (textBox.bottom + height * .055).toInt().coerceAtMost(height)
        var firstInk = height
        var lastInk = -1
        val requiredPixels = max(4, (right - left) / 135)
        for (y in scanTop until scanBottom) {
            var count = 0
            for (x in left until right step 2) {
                if (ink(pixels[y * width + x]) != null) count++
            }
            if (count >= requiredPixels) {
                firstInk = min(firstInk, y)
                lastInk = max(lastInk, y)
            }
        }
        val top = (min(textBox.top, firstInk) - height * .010)
            .toInt().coerceIn(0, height - 1)
        val bottom = (max(textBox.bottom, lastInk + 1) + height * .012)
            .toInt().coerceIn(top + 1, height)
        if (bottom - top < 26 || right - left < 60) return null

        // Trim white page margins, but never trim a row containing dialogue.
        var trimmedTop = top
        var trimmedBottom = bottom
        fun yellowCoverage(y: Int): Double {
            var count = 0
            var total = 0
            for (x in left until right step 3) {
                if (yellow(pixels[y * width + x])) count++
                total++
            }
            return if (total == 0) 0.0 else count.toDouble() / total
        }
        while (trimmedTop < trimmedBottom - 24 &&
            yellowCoverage(trimmedTop) < .43) trimmedTop++
        while (trimmedBottom > trimmedTop + 24 &&
            yellowCoverage(trimmedBottom - 1) < .43) trimmedBottom--
        return Rect(left, trimmedTop, right, trimmedBottom)
    }

    private data class Band(
        var top: Int, var bottom: Int, var left: Int, var right: Int,
        var blue: Int, var orange: Int,
    )

    /**
     * Identify colored lines by image geometry, not OCR text-line confidence:
     * Tesseract's standard page iterator sometimes omits every blue line.
     */
    fun recognizeBothColors(
        tess: TessBaseAPI,
        bitmap: Bitmap,
        selected: Rect,
    ): Recognition {
        val w = bitmap.width
        val h = bitmap.height
        if (selected.isEmpty()) return Recognition("", 0, 0)
        val pixels = IntArray(w * selected.height())
        bitmap.getPixels(pixels, 0, w, 0, selected.top, w, selected.height())
        val rowBlue = IntArray(selected.height())
        val rowOrange = IntArray(selected.height())
        val rowLeft = IntArray(selected.height()) { w }
        val rowRight = IntArray(selected.height())
        for (y in 0 until selected.height()) {
            for (x in selected.left until selected.right) {
                when (ink(pixels[y * w + x])) {
                    Ink.BLUE -> rowBlue[y]++
                    Ink.ORANGE -> rowOrange[y]++
                    null -> continue
                }
                rowLeft[y] = min(rowLeft[y], x)
                rowRight[y] = max(rowRight[y], x)
            }
        }

        val bands = mutableListOf<Band>()
        val gap = max(5, (h * .005).toInt())
        val threshold = max(3, selected.width() / 135)
        for (y in rowBlue.indices) {
            val blue = rowBlue[y]
            val orange = rowOrange[y]
            if (blue + orange < threshold) continue
            val previous = bands.lastOrNull()
            if (previous == null || y - previous.bottom > gap) {
                bands.add(Band(y, y, rowLeft[y], rowRight[y], blue, orange))
            } else {
                previous.bottom = y
                previous.left = min(previous.left, rowLeft[y])
                previous.right = max(previous.right, rowRight[y])
                previous.blue += blue
                previous.orange += orange
            }
        }
        val lines = mutableListOf<String>()
        var blueCount = 0
        var orangeCount = 0
        // A page with many tiny noise bands must not trigger unbounded OCR.
        for (band in bands.filter { it.bottom - it.top >= 4 }.take(35)) {
            val type = if (band.blue >= band.orange) Ink.BLUE else Ink.ORANGE
            val padY = max(8, (h * .005).toInt())
            val padX = max(10, (w * .008).toInt())
            val left = (band.left - padX).coerceAtLeast(selected.left)
            val right = (band.right + padX + 1).coerceAtMost(selected.right)
            val top = (band.top - padY).coerceAtLeast(0)
            val bottom = (band.bottom + padY + 1).coerceAtMost(selected.height())
            if (right - left < 25 || bottom - top < 12) continue
            val lineWidth = right - left
            val lineHeight = bottom - top
            val out = IntArray(lineWidth * lineHeight) { Color.WHITE }
            for (y in top until bottom) {
                for (x in left until right) {
                    val pixel = pixels[y * w + x]
                    if (ink(pixel) == type) {
                        out[(y - top) * lineWidth + (x - left)] = Color.BLACK
                    }
                }
            }
            val mask = Bitmap.createBitmap(
                lineWidth, lineHeight, Bitmap.Config.ARGB_8888
            )
            try {
                mask.setPixels(out, 0, lineWidth, 0, 0, lineWidth, lineHeight)
                tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_LINE)
                tess.setImage(mask)
                val result = ArabicDialogueRegion.onlyDialogueLines(
                    tess.getUTF8Text().orEmpty()
                ).trim()
                if (result.isNotEmpty()) {
                    lines.add(result)
                    if (type == Ink.BLUE) blueCount++ else orangeCount++
                }
            } finally {
                mask.recycle()
            }
        }
        return Recognition(lines.joinToString("\n").take(100000),
            blueCount, orangeCount)
    }
}
