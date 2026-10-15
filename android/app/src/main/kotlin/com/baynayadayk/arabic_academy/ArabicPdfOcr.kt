package com.example.arabic_academy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.googlecode.tesseract.android.TessBaseAPI
import java.io.File

/**
 * Arabic OCR of an owner's app-private, imported PDF using offline Tesseract 5.
 *
 * No PDF bytes, rendered page or recognized text are transmitted or uploaded.
 * A public Apache-2 Arabic LSTM model is bundled into the development APK at
 * build time and copied once into internal storage for the native engine.
 *
 * The returned transcription is UNVERIFIED; vocalization and reading order
 * must be checked by the owner before it is marked as source-accurate.
 */
internal object ArabicPdfOcr {
    private const val MODEL_BYTES = 1432056L
    private const val MODEL_ASSET = "tessdata/ara.traineddata"

    private fun modelDirectory(context: Context): File {
        val root = File(context.filesDir, "private_ocr").canonicalFile
        val models = File(root, "tessdata")
        if (!models.exists() && !models.mkdirs()) {
            error("Cannot create local OCR model directory")
        }
        val target = File(models, "ara.traineddata")
        if (!target.isFile || target.length() != MODEL_BYTES) {
            val temp = File(models, "ara.traineddata.importing")
            try {
                context.assets.open(MODEL_ASSET).use { input ->
                    temp.outputStream().use { output ->
                        input.copyTo(output)
                        output.flush()
                    }
                }
                require(temp.length() == MODEL_BYTES) {
                    "Arabic OCR model was not packaged into this APK"
                }
                if (target.exists() && !target.delete()) {
                    error("Cannot replace damaged local OCR model")
                }
                check(temp.renameTo(target)) { "Cannot install local OCR model" }
            } finally {
                if (temp.exists()) temp.delete()
            }
        }
        return root
    }

    fun recognize(context: Context, part: Int, pageIndex: Int): Map<String, Any> {
        require(part == 1 || part == 2) { "Invalid book part" }
        require(pageIndex >= 0) { "Invalid page number" }
        val privateFolder = File(context.filesDir, "private_textbooks").canonicalFile
        val pdf = File(privateFolder, "student_book_1_part_${part}.pdf").canonicalFile
        require(pdf.parentFile == privateFolder) { "Invalid book location" }
        if (!pdf.isFile) return mapOf("status" to "missing", "text" to "")
        require(pdf.length() in 5L..(400L * 1024 * 1024)) {
            "Invalid imported PDF size"
        }

        // Page images and all OCR processing remain in app memory.
        val bitmap = ParcelFileDescriptor.open(
            pdf, ParcelFileDescriptor.MODE_READ_ONLY
        ).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                require(pageIndex < renderer.pageCount) {
                    "PDF page index out of range"
                }
                renderer.openPage(pageIndex).use { page ->
                    // 2300 pixels preserves significantly more fine Arabic glyph
                    // detail than the 1150px screen preview without excessive RAM.
                    val scale = minOf(2300.0 / page.width, 3300.0 / page.height)
                    val width = (page.width * scale).toInt().coerceAtLeast(480)
                    val height = (page.height * scale).toInt().coerceAtLeast(480)
                    Bitmap.createBitmap(
                        width, height, Bitmap.Config.ARGB_8888
                    ).also { image ->
                        Canvas(image).drawColor(Color.WHITE)
                        page.render(
                            image, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                        )
                    }
                }
            }
        }

        try {
            val models = modelDirectory(context)
            val tess = TessBaseAPI()
            try {
                if (!tess.init(models.absolutePath, "ara")) {
                    error("Unable to initialize Arabic OCR engine")
                }
                tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
                tess.setImage(bitmap)
                val recognized = tess.getUTF8Text()?.trim().orEmpty().take(100000)
                return mapOf(
                    "status" to (if (recognized.isEmpty()) "empty" else "ocr"),
                    "text" to recognized,
                    "method" to "tesseract_arabic_on_device",
                    "verified" to false,
                )
            } finally {
                tess.recycle()
            }
        } finally {
            bitmap.recycle()
        }
    }
}
