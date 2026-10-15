package com.example.arabic_academy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import java.io.ByteArrayOutputStream
import kotlin.math.ceil
import kotlin.math.floor
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

    private fun sourcePdf(context: Context, part: Int): File? {
        require(part == 1 || part == 2) { "Invalid book part" }
        val folder = File(context.filesDir, "private_textbooks").canonicalFile
        val pdf = File(folder, "student_book_1_part_${part}.pdf").canonicalFile
        require(pdf.parentFile == folder) { "Invalid book location" }
        if (!pdf.isFile) return null
        require(pdf.length() in 5L..(400L * 1024 * 1024)) {
            "Invalid imported PDF size"
        }
        return pdf
    }

    private fun renderPage(pdf: File, pageIndex: Int, desiredWidth: Int): Bitmap {
        require(pageIndex >= 0) { "Invalid page number" }
        return ParcelFileDescriptor.open(
            pdf, ParcelFileDescriptor.MODE_READ_ONLY
        ).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                require(pageIndex < renderer.pageCount) {
                    "PDF page index out of range"
                }
                renderer.openPage(pageIndex).use { page ->
                    val scale = minOf(
                        desiredWidth.toDouble() / page.width,
                        3600.0 / page.height
                    )
                    val width = (page.width * scale).toInt().coerceAtLeast(400)
                    val height = (page.height * scale).toInt().coerceAtLeast(400)
                    Bitmap.createBitmap(
                        width, height, Bitmap.Config.ARGB_8888
                    ).also { image ->
                        Canvas(image).drawColor(Color.WHITE)
                        page.render(
                            image, null, null,
                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                        )
                    }
                }
            }
        }
    }

    /**
     * A temporary preview exactly matching the page crop coordinate system.
     * No scan image is persisted to disk or sent over the network.
     */
    fun preview(
        context: Context,
        part: Int,
        pageIndex: Int,
        requestedWidth: Int
    ): Map<String, Any> {
        val source = sourcePdf(context, part)
            ?: return mapOf("status" to "missing")
        val bitmap = renderPage(source, pageIndex, requestedWidth.coerceIn(600, 1400))
        try {
            val output = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 90, output)
            val bytes = output.toByteArray()
            require(bytes.size <= 18 * 1024 * 1024) {
                "PDF preview too large for the phone"
            }
            return mapOf(
                "status" to "ok",
                "width" to bitmap.width,
                "height" to bitmap.height,
                "bytes" to bytes
            )
        } finally {
            bitmap.recycle()
        }
    }

    fun recognize(
        context: Context,
        part: Int,
        pageIndex: Int,
        region: List<Double>? = null
    ): Map<String, Any> {
        val source = sourcePdf(context, part)
            ?: return mapOf("status" to "missing", "text" to "")

        // OCR never sees page surroundings if the student picked a region.
        // Crop coordinates are relative to the complete original page bitmap.
        val bitmap = renderPage(source, pageIndex, 2700)
        var selected: Bitmap? = null
        try {
            if (region != null) {
                require(region.size == 4 && region.all { it.isFinite() }) {
                    "Invalid dialogue crop rectangle"
                }
                val (left, top, right, bottom) = region
                require(left >= 0.0 && top >= 0.0 &&
                        right <= 1.0 && bottom <= 1.0 &&
                        right - left >= 0.025 && bottom - top >= 0.025) {
                    "OCR region must be inside the page"
                }

                val x = floor(left * bitmap.width).toInt()
                    .coerceIn(0, bitmap.width - 1)
                val y = floor(top * bitmap.height).toInt()
                    .coerceIn(0, bitmap.height - 1)
                val r = ceil(right * bitmap.width).toInt()
                    .coerceIn(x + 1, bitmap.width)
                val b = ceil(bottom * bitmap.height).toInt()
                    .coerceIn(y + 1, bitmap.height)
                selected = Bitmap.createBitmap(bitmap, x, y, r - x, b - y)
            }

            val models = modelDirectory(context)
            val tess = TessBaseAPI()
            try {
                if (!tess.init(models.absolutePath, "ara")) {
                    error("Unable to initialize Arabic OCR engine")
                }
                tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
                tess.setImage(selected ?: bitmap)
                val recognized = tess.getUTF8Text()?.trim().orEmpty().take(100000)
                return mapOf(
                    "status" to (if (recognized.isEmpty()) "empty" else "ocr"),
                    "text" to recognized,
                    "method" to if (region == null) "tesseract_arabic_on_device"
                                 else "tesseract_arabic_selected_region",
                    "verified" to false,
                )
            } finally {
                tess.recycle()
            }
        } finally {
            selected?.recycle()
            bitmap.recycle()
        }
    }
}
