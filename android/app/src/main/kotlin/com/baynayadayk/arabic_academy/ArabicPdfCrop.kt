package com.example.arabic_academy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Renders a visual crop of a learner's own private PDF without OCR text
 * substitution. The original image, letters, and tashkeel remain unchanged.
 *
 * Crops exist only in Android memory, never in distributable assets or cloud.
 */
internal object ArabicPdfCrop {
    private fun normalizedRect(width: Int, height: Int, crop: List<Double>): Rect {
        require(crop.size == 4 && crop.all { it.isFinite() && it in 0.0..1.0 }) {
            "Invalid normalized dialogue crop"
        }
        require(crop[2] - crop[0] >= 0.08 && crop[3] - crop[1] >= 0.06) {
            "Dialogue crop is too small or reversed"
        }
        val left = (crop[0] * width).toInt().coerceIn(0, width - 1)
        val top = (crop[1] * height).toInt().coerceIn(0, height - 1)
        val right = (crop[2] * width).toInt().coerceIn(left + 1, width)
        val bottom = (crop[3] * height).toInt().coerceIn(top + 1, height)
        return Rect(left, top, right, bottom)
    }

    private fun encode(bitmap: Bitmap, crop: Rect): ByteArray {
        val cut = Bitmap.createBitmap(bitmap, crop.left, crop.top, crop.width(), crop.height())
        return try {
            ByteArrayOutputStream().use { stream ->
                check(cut.compress(Bitmap.CompressFormat.PNG, 100, stream)) {
                    "Cannot encode original PDF crop"
                }
                stream.toByteArray()
            }
        } finally {
            cut.recycle()
        }
    }

    /**
     * OCR boundaries cover only right-column words. For the visual fragment,
     * also include the adjacent original picture on the left, with a modest
     * vertical margin. Users can refine these heuristic bounds themselves.
     */
    fun fromDetectedText(bitmap: Bitmap, textBox: Rect): Pair<List<Double>, ByteArray> {
        val width = bitmap.width
        val height = bitmap.height
        val left = if (textBox.left > width * 0.42) {
            (width * 0.055).toInt()
        } else {
            (textBox.left - width * 0.03).toInt().coerceAtLeast(0)
        }
        val right = (textBox.right + width * 0.03).toInt().coerceAtMost(width)
        val top = (textBox.top - height * 0.055).toInt().coerceAtLeast(0)
        val bottom = (textBox.bottom + height * 0.045).toInt().coerceAtMost(height)
        val rect = Rect(left, top, right, bottom)
        require(rect.width() > 0 && rect.height() > 0) { "Empty PDF region" }
        val crop = listOf(
            left.toDouble() / width,
            top.toDouble() / height,
            right.toDouble() / width,
            bottom.toDouble() / height
        )
        return crop to encode(bitmap, rect)
    }

    /** Re-render saved or manually adjusted bounds from the same local PDF. */
    fun render(context: Context, part: Int, pageIndex: Int, crop: List<Double>): ByteArray {
        require(part == 1 || part == 2) { "Invalid book part" }
        require(pageIndex >= 0) { "Invalid page index" }
        val safeDir = File(context.filesDir, "private_textbooks").canonicalFile
        val pdf = File(safeDir, "student_book_1_part_${part}.pdf").canonicalFile
        require(pdf.parentFile == safeDir && pdf.isFile &&
            pdf.length() in 5L..(400L * 1024 * 1024)) { "Missing private PDF" }

        return ParcelFileDescriptor.open(pdf, ParcelFileDescriptor.MODE_READ_ONLY).use { handle ->
            PdfRenderer(handle).use { reader ->
                require(pageIndex < reader.pageCount) { "PDF page index out of range" }
                reader.openPage(pageIndex).use { page ->
                    val scale = minOf(1900.0 / page.width, 2800.0 / page.height)
                    val width = (page.width * scale).toInt().coerceAtLeast(480)
                    val height = (page.height * scale).toInt().coerceAtLeast(480)
                    val bounds = normalizedRect(width, height, crop)
                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    try {
                        Canvas(bitmap).drawColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        encode(bitmap, bounds)
                    } finally {
                        bitmap.recycle()
                    }
                }
            }
        }
    }
}
