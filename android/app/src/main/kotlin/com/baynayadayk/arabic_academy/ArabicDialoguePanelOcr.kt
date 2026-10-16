package com.example.arabic_academy

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.Rect
import java.io.ByteArrayOutputStream
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
    data class LineSample(
        val text: String,
        val color: String,
        val ordinal: Int,
        val image: ByteArray,
    )

    data class Result(
        val text: String,
        val detectedBlue: Int,
        val detectedOrange: Int,
        val recognizedBlue: Int,
        val recognizedOrange: Int,
        val unreadable: Int,
        val samples: List<LineSample>,
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
    private val garbage = Regex("[0-9A-Za-z\u0660-\u0669\uFFFD]")

    // Length alone is not quality. Older versions frequently picked a long,
    // nonsensical Arabic hypothesis with stray 5/7 digits.
    private fun rank(text: String, confidence: Int, band: Band): Double {
        val letters = arabicLetter.findAll(text).count()
        if (letters < 3) return -1000.0
        val numericNoise = garbage.findAll(text).count()
        val accents = diacritics.findAll(text).count()
        val widthBasedMin = max(3, (band.right - band.left) / 105)
        return confidence.coerceIn(0, 100) * 0.65 +
            min(letters, 70) * .55 +
            min(accents, 30) * .34 -
            numericNoise * 18.0 -
            max(0, widthBasedMin - letters) * 7.0
    }

    private fun lineBounds(rect: Rect, band: Band): Rect {
        // More vertical breathing room protects dots and tashkil above words.
        val padY = max(12, rect.height() / 70)
        val padX = max(14, rect.width() / 38)
        return Rect(
            (band.left - padX).coerceAtLeast(rect.left),
            (rect.top + band.top - padY).coerceAtLeast(rect.top),
            (band.right + padX + 1).coerceAtMost(rect.right),
            (rect.top + band.bottom + padY + 1).coerceAtMost(rect.bottom),
        )
    }

    private fun readLine(
        tess: TessBaseAPI, bitmap: Bitmap, pixels: IntArray,
        rect: Rect, band: Band,
    ): String {
        val bounds = lineBounds(rect, band)
        val width = bounds.width()
        val height = bounds.height()
        if (width < 30 || height < 14) return ""
        val original = Bitmap.createBitmap(
            bitmap, bounds.left, bounds.top, width, height
        )
        // Preserve faint antialiased ochre letter stems and tashkeel, which
        // become disconnected after the hard, two-tone v25 ink mask.
        val contrast = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val grayscale = IntArray(width * height)
        val bg = IntArray(3)
        val probeY = arrayOf(2, height / 2, height - 3)
        val probeX = arrayOf(2, width / 2, width - 3)
        // Pick the brightest sampled paper rather than assuming fixed yellow.
        var lightest = -1
        for (y in probeY) for (x in probeX) {
            val c = original.getPixel(x.coerceIn(0, width - 1),
                y.coerceIn(0, height - 1))
            val l = Color.red(c) + Color.green(c) + Color.blue(c)
            if (l > lightest) {
                lightest = l
                bg[0] = Color.red(c)
                bg[1] = Color.green(c)
                bg[2] = Color.blue(c)
            }
        }
        val source = IntArray(width * height)
        original.getPixels(source, 0, width, 0, 0, width, height)
        for (i in source.indices) {
            val p = source[i]
            val r = Color.red(p)
            val g = Color.green(p)
            val b = Color.blue(p)
            val dark = if (band.type == Ink.ORANGE) {
                // Ochre on yellow: green channel usually separates most.
                val greenDrop = (bg[1] - g).coerceAtLeast(0)
                val redDrop = (bg[0] - r).coerceAtLeast(0)
                val orangeHue = r > g + 7 && g > b + 6
                if (orangeHue || ink(p) == Ink.ORANGE) {
                    (greenDrop * 1.65 + redDrop * .38)
                        .toInt().coerceIn(0, 255)
                } else 0
            } else {
                // Muted blue becomes visible using complementary chroma.
                val redDrop = (bg[0] - r).coerceAtLeast(0)
                val blueTint = b >= r + 5 || ink(p) == Ink.BLUE
                if (blueTint) (redDrop * 1.5).toInt().coerceIn(0, 255)
                else 0
            }
            // Continuous grayscale (not binary) retains thin vocalization.
            val inkStrength = (dark - 9).coerceAtLeast(0)
            val gray = (255 - inkStrength * 1.65).toInt().coerceIn(0, 255)
            grayscale[i] = Color.rgb(gray, gray, gray)
        }
        contrast.setPixels(grayscale, 0, width, 0, 0, width, height)
        var best = ""
        var bestScore = -1000.0
        try {
            // Colored original, color-enhanced text on white, and a
            // high-resolution rerender are independent recognition views.
            for (sourceBitmap in listOf(contrast, original)) {
                val margin = max(12, height / 3)
                val padded = Bitmap.createBitmap(
                    width + 2 * margin, height + 2 * margin,
                    Bitmap.Config.ARGB_8888
                )
                try {
                    padded.eraseColor(Color.WHITE)
                    android.graphics.Canvas(padded).drawBitmap(
                        sourceBitmap, margin.toFloat(), margin.toFloat(), null
                    )
                    val factor = if (height < 65) 3 else 2
                    val enlarged = Bitmap.createScaledBitmap(
                        padded, padded.width * factor, padded.height * factor,
                        true
                    )
                    try {
                        // PSM_SINGLE_LINE keeps one speech turn independent.
                        tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_LINE)
                        tess.setImage(enlarged)
                        val candidate = ArabicDialogueRegion.onlyDialogueLines(
                            tess.getUTF8Text().orEmpty()
                        ).replace("\n", " ").trim()
                        val score = rank(candidate, tess.meanConfidence(), band)
                        if (score > bestScore) {
                            best = candidate
                            bestScore = score
                        }
                    } finally {
                        enlarged.recycle()
                    }
                } finally {
                    padded.recycle()
                }
            }
        } finally {
            original.recycle()
            contrast.recycle()
        }
        // Do not call a collection of random glyphs a recognized reply.
        return if (bestScore >= 21 && garbage.findAll(best).count() <= 1) {
            best
        } else ""
    }

    /** Exact scan pixels of a single line for side-by-side human verification. */
    private fun preview(bitmap: Bitmap, rect: Rect, band: Band): ByteArray {
        val selected = lineBounds(rect, band)
        val cut = Bitmap.createBitmap(
            bitmap, selected.left, selected.top,
            selected.width(), selected.height()
        )
        try {
            return ByteArrayOutputStream().use { out ->
                check(cut.compress(Bitmap.CompressFormat.PNG, 100, out))
                out.toByteArray()
            }
        } finally {
            cut.recycle()
        }
    }

    fun recognize(tess: TessBaseAPI, bitmap: Bitmap, rect: Rect): Result {
        if (rect.isEmpty()) return Result("", 0, 0, 0, 0, 0, emptyList())
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
        val samples = mutableListOf<LineSample>()
        for (band in lines) {
            val ordinal = if (band.type == Ink.BLUE) ++blueFound else ++orangeFound
            val text = readLine(tess, bitmap, pixels, rect, band)
            if (text.isBlank()) {
                unreadable++
                val label = if (band.type == Ink.BLUE) "синяя" else "оранжевая"
                // Bidirectional isolate keeps the Russian warning intact in
                // Flutter's RTL Arabic editor. No invented Arabic syllables.
                ordered.add("[\u2066Не распознана $label реплика $ordinal — проверьте PDF\u2069]")
            } else {
                if (band.type == Ink.BLUE) blueRead++ else orangeRead++
                ordered.add(text)
            }
            samples.add(LineSample(
                text, if (band.type == Ink.BLUE) "blue" else "orange",
                ordinal, preview(bitmap, rect, band)
            ))
        }
        return Result(ordered.joinToString("\n").take(100000),
            blueFound, orangeFound, blueRead, orangeRead, unreadable, samples)
    }
}
