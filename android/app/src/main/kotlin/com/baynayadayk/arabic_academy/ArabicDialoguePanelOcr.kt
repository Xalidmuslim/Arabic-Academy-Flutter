package com.example.arabic_academy

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import com.googlecode.tesseract.android.TessBaseAPI
import kotlin.math.max
import kotlin.math.min

/**
 * Geometry-first offline OCR for the two cream dialogue panels on a scanned
 * page. Detects panels and colored ink *before* asking Tesseract to read a
 * line, so failed OCR cannot silently remove its position in the transcript.
 * The local PDF pixels remain the only authoritative vocalized source.
 */
internal object ArabicDialoguePanelOcr {
    data class Result(
        val text: String,
        val detectedBlue: Int,
        val detectedOrange: Int,
        val recognizedBlue: Int,
        val recognizedOrange: Int,
        val unreadable: Int,
    )

    private enum class Ink { BLUE, ORANGE }

    private fun cream(rgb: Int): Boolean {
        val r = Color.red(rgb)
        val g = Color.green(rgb)
        val b = Color.blue(rgb)
        return r >= 185 && g >= 170 && b <= 242 &&
            r - b >= 30 && g - b >= 22 && (r - g) in -20..45
    }

    private fun ink(rgb: Int): Ink? {
        val r = Color.red(rgb)
        val g = Color.green(rgb)
        val b = Color.blue(rgb)
        if (b >= r + 10 && b >= g + 8 && min(r, g) < 205) return Ink.BLUE
        if (r >= g + 17 && g >= b + 17 && r - b >= 55 && g < 228) {
            return Ink.ORANGE
        }
        return null
    }

    /**
     * Find independent cream-colored horizontal panels in the right-side text
     * column. This works even when page-level OCR skips all blue lines, and
     * respects both (أ) and (ب) dialogues on one PDF page.
     */
    fun findPanels(bitmap: Bitmap): List<Rect> {
        val w = bitmap.width
        val h = bitmap.height
        if (w < 200 || h < 200) return emptyList()
        val sampledLeft = (w * .66).toInt()
        val sampledRight = (w * .91).toInt()
        val strideY = max(2, h / 1400)
        val strideX = max(3, (sampledRight - sampledLeft) / 22)
        val active = mutableListOf<Int>()
        for (y in 0 until h step strideY) {
            var found = 0
            var checked = 0
            for (x in sampledLeft until sampledRight step strideX) {
                if (cream(bitmap.getPixel(x, y))) found++
                checked++
            }
            if (checked > 0 && found.toDouble() / checked >= .46) active.add(y)
        }
        if (active.isEmpty()) return emptyList()
        val blocks = mutableListOf<Pair<Int, Int>>()
        var start = active.first()
        var last = start
        val allowedGap = max(strideY * 2, (h * .012).toInt())
        for (y in active.drop(1)) {
            if (y - last > allowedGap) {
                blocks.add(start to (last + strideY).coerceAtMost(h))
                start = y
            }
            last = y
        }
        blocks.add(start to (last + strideY).coerceAtMost(h))
        val minHeight = max(45, (h * .075).toInt())
        return blocks.filter { (top, bottom) ->
            bottom - top >= minHeight &&
                top > h * .065 && bottom < h * .99
        }.map { (top, bottom) ->
            Rect(
                (w * .52).toInt(),
                (top - 3).coerceAtLeast(0),
                (w * .97).toInt(),
                (bottom + 3).coerceAtMost(h),
            )
        }.take(5)
    }

    private data class Band(
        val type: Ink, val top: Int, val bottom: Int,
        val left: Int, val right: Int, val count: Int,
    )

    private fun bands(
        pixels: IntArray, bitmapWidth: Int, rect: Rect, type: Ink,
    ): List<Band> {
        val rows = rect.height()
        val amount = IntArray(rows)
        val firstX = IntArray(rows) { rect.right }
        val lastX = IntArray(rows) { rect.left }
        for (y in 0 until rows) {
            for (x in rect.left until rect.right) {
                if (ink(pixels[y * bitmapWidth + x]) == type) {
                    amount[y]++
                    firstX[y] = min(firstX[y], x)
                    lastX[y] = max(lastX[y], x)
                }
            }
        }
        val threshold = max(3, rect.width() / 160)
        val gap = max(5, (rows * .010).toInt())
        val output = mutableListOf<Band>()
        var start = -1
        var end = -1
        var left = rect.right
        var right = rect.left
        var count = 0
        fun finish() {
            if (start < 0) return
            val height = end - start + 1
            val width = right - left + 1
            if (height >= max(5, rows / 130) &&
                width >= rect.width() * .11 &&
                count >= max(40, rect.width() / 8)) {
                output.add(Band(type, start, end, left, right, count))
            }
        }
        for (y in 0..rows) {
            val present = y < rows && amount[y] >= threshold
            if (present) {
                if (start < 0) start = y
                if (end >= 0 && y - end > gap) {
                    finish()
                    start = y
                    left = rect.right
                    right = rect.left
                    count = 0
                }
                end = y
                left = min(left, firstX[y])
                right = max(right, lastX[y])
                count += amount[y]
            } else if (start >= 0 && (y - end > gap || y == rows)) {
                finish()
                start = -1
                end = -1
                left = rect.right
                right = rect.left
                count = 0
            }
        }
        return output
    }

    private val arabicLetter = Regex("[\u0621-\u064A]")
    private val diacritics = Regex("[\u064B-\u065F\u0670]")
    private val garbage = Regex("[0-9A-Za-z\uFFFD]")
    private fun rank(text: String): Double {
        val letters = arabicLetter.findAll(text).count()
        if (letters < 3) return -1000.0
        return letters * 2.0 + diacritics.findAll(text).count() * .7 -
            garbage.findAll(text).count() * 8.0
    }

    private fun readLine(
        tess: TessBaseAPI, bitmap: Bitmap, pixels: IntArray,
        rect: Rect, band: Band,
    ): String {
        val padY = max(8, rect.height() / 90)
        val padX = max(12, rect.width() / 45)
        val left = (band.left - padX).coerceAtLeast(rect.left)
        val right = (band.right + padX + 1).coerceAtMost(rect.right)
        val top = (band.top - padY).coerceAtLeast(0)
        val bottom = (band.bottom + padY + 1).coerceAtMost(rect.height())
        val width = right - left
        val height = bottom - top
        if (width < 20 || height < 10) return ""

        // A normal-color crop often reads Arabic better than a strict binary
        // mask. Compare it with color-isolated ink, keeping the best candidate.
        val original = Bitmap.createBitmap(
            bitmap, left, rect.top + top, width, height
        )
        val isolated = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val filtered = IntArray(width * height) { Color.WHITE }
        for (y in top until bottom) {
            for (x in left until right) {
                if (ink(pixels[y * bitmap.width + x]) == band.type) {
                    filtered[(y - top) * width + x - left] = Color.BLACK
                }
            }
        }
        isolated.setPixels(filtered, 0, width, 0, 0, width, height)
        var best = ""
        var bestRank = -1000.0
        try {
            for (source in listOf(original, isolated)) {
                val enlarged = Bitmap.createScaledBitmap(
                    source, width * 2, height * 2, true
                )
                try {
                    tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_LINE)
                    tess.setImage(enlarged)
                    val text = ArabicDialogueRegion.onlyDialogueLines(
                        tess.getUTF8Text().orEmpty()
                    ).replace("\n", " ").trim()
                    val score = rank(text)
                    if (score > bestRank) {
                        best = text
                        bestRank = score
                    }
                } finally {
                    enlarged.recycle()
                }
            }
        } finally {
            original.recycle()
            isolated.recycle()
        }
        return if (bestRank >= 6.0) best else ""
    }

    fun recognize(tess: TessBaseAPI, bitmap: Bitmap, rect: Rect): Result {
        if (rect.isEmpty()) return Result("", 0, 0, 0, 0, 0)
        val w = bitmap.width
        val pixels = IntArray(w * rect.height())
        bitmap.getPixels(pixels, 0, w, 0, rect.top, w, rect.height())
        val lines = (bands(pixels, w, rect, Ink.BLUE) +
            bands(pixels, w, rect, Ink.ORANGE))
            .sortedBy { it.top }
            .take(32)
        var blueFound = 0
        var orangeFound = 0
        var blueRead = 0
        var orangeRead = 0
        var unreadable = 0
        val ordered = mutableListOf<String>()
        for (band in lines) {
            val ordinal = if (band.type == Ink.BLUE) ++blueFound else ++orangeFound
            val text = readLine(tess, bitmap, pixels, rect, band)
            if (text.isBlank()) {
                unreadable++
                val label = if (band.type == Ink.BLUE) "синяя" else "оранжевая"
                ordered.add("[Не распознана $label реплика $ordinal — проверьте PDF]")
            } else {
                if (band.type == Ink.BLUE) blueRead++ else orangeRead++
                ordered.add(text)
            }
        }
        return Result(ordered.joinToString("\n").take(100000),
            blueFound, orangeFound, blueRead, orangeRead, unreadable)
    }
}
