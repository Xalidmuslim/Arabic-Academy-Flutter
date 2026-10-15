package com.example.arabic_academy

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
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

    /**
     * Auto-detect the relevant conversation on a scan before the final OCR.
     *
     * Detects Arabic text-line bounding boxes, separates independent dialogue
     * blocks by vertical whitespace, and restricts the second OCR pass to the
     * selected block. A d2 page hint can be two pages later than the first
     * scan containing both (a)/(b) conversations; in this case also inspect
     * the earlier page and choose its second block if identified.
     *
     * This is heuristic layout analysis, NOT a source-accuracy guarantee.
     */
    fun recognizeDialogue(
        context: Context,
        part: Int,
        pageIndex: Int,
        dialogueSlot: Int,
    ): Map<String, Any> {
        require(part == 1 || part == 2) { "Invalid book part" }
        require(pageIndex >= 0) { "Invalid page index" }
        require(dialogueSlot in 1..2) { "Invalid dialogue slot" }
        val privateFolder = File(context.filesDir, "private_textbooks").canonicalFile
        val pdf = File(privateFolder, "student_book_1_part_${part}.pdf").canonicalFile
        require(pdf.parentFile == privateFolder) { "Invalid book location" }
        if (!pdf.isFile) {
            return mapOf("status" to "missing", "text" to "", "page_index" to pageIndex)
        }
        require(pdf.length() in 5L..(400L * 1024 * 1024)) { "Invalid PDF size" }

        val root = modelDirectory(context)
        val tess = TessBaseAPI()
        try {
            check(tess.init(root.absolutePath, "ara")) {
                "Unable to initialize offline Arabic OCR engine"
            }
            return ParcelFileDescriptor.open(
                pdf, ParcelFileDescriptor.MODE_READ_ONLY
            ).use { descriptor ->
                PdfRenderer(descriptor).use { renderer ->
                    require(pageIndex < renderer.pageCount) {
                        "PDF page index out of range"
                    }
                    // Only one previous page is checked for a second dialogue.
                    // We never upload or index an entire textbook.
                    val indexes = if (dialogueSlot == 2 && pageIndex >= 2) {
                        listOf(pageIndex - 2, pageIndex)
                    } else {
                        listOf(pageIndex)
                    }
                    for (candidateIndex in indexes) {
                        val bitmap = renderer.openPage(candidateIndex).use { page ->
                            val scale = minOf(2300.0 / page.width, 3300.0 / page.height)
                            val width = (page.width * scale).toInt().coerceAtLeast(480)
                            val height = (page.height * scale).toInt().coerceAtLeast(480)
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
                        try {
                            tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_AUTO)
                            tess.setImage(bitmap)
                            // Recognition must occur before iterating text-line boxes.
                            tess.getUTF8Text()
                            val lines = mutableListOf<ArabicDialogueRegion.Line>()
                            val iterator = tess.getResultIterator()
                            if (iterator != null) {
                                try {
                                    iterator.begin()
                                    do {
                                        val text = iterator.getUTF8Text(
                                            TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                                        )?.trim().orEmpty()
                                        val box = iterator.getBoundingRect(
                                            TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                                        )
                                        val confidence = iterator.confidence(
                                            TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                                        )
                                        if (text.isNotEmpty() && box != null) {
                                            lines.add(
                                                ArabicDialogueRegion.Line(text, box, confidence)
                                            )
                                        }
                                    } while (iterator.next(
                                        TessBaseAPI.PageIteratorLevel.RIL_TEXTLINE
                                    ))
                                } finally {
                                    iterator.delete()
                                }
                            }
                            val selection = ArabicDialogueRegion.choose(
                                lines, bitmap.width, bitmap.height, dialogueSlot
                            )
                            val region = selection.crop ?: continue
                            // Do not confuse the first dialogue on a previous
                            // page with the requested second one.
                            if (candidateIndex != pageIndex &&
                                selection.groupsOnPage < 2) {
                                continue
                            }
                            tess.setPageSegMode(TessBaseAPI.PageSegMode.PSM_SINGLE_BLOCK)
                            tess.setRectangle(region)
                            val broadText = ArabicDialogueRegion.onlyDialogueLines(
                                tess.getUTF8Text().orEmpty()
                            )
                            // First preserve the actual source pixels. This is
                            // the cream-yellow text panel only, not its photo.
                            val visual = ArabicPdfCrop.fromDetectedText(bitmap, region)
                            // Next isolate muted blue and orange glyph pixels.
                            // Segment rows independently of page-level Tesseract
                            // text-line boxes, which often drop the blue prompts.
                            val colored = ArabicDialogueColors.recognizeBothColors(
                                tess, bitmap, visual.rect
                            )
                            val combinedText = if (colored.blueLines > 0 &&
                                colored.orangeLines > 0) {
                                colored.text
                            } else if (colored.text.isBlank()) {
                                broadText
                            } else {
                                // Keep colored lines when standard OCR sees fewer
                                // lines; otherwise retain its unmasked fallback.
                                val coloredCount = colored.text.lines().size
                                val broadCount = broadText.lines().size
                                if (broadCount > coloredCount) broadText
                                else colored.text
                            }
                            return@use mapOf(
                                "status" to (if (combinedText.isBlank()) "empty" else "ocr"),
                                "text" to combinedText,
                                "page_index" to candidateIndex,
                                "auto_selected" to true,
                                "detected_blocks" to selection.groupsOnPage,
                                "crop" to visual.coordinates,
                                "image_png" to visual.imagePng,
                                "yellow_detected" to visual.yellowDetected,
                                "blue_lines" to colored.blueLines,
                                "orange_lines" to colored.orangeLines,
                                "review_required" to true,
                                "method" to "tesseract_arabic_color_separated_dialogue"
                            )
                        } finally {
                            bitmap.recycle()
                        }
                    }
                    mapOf(
                        "status" to "empty",
                        "text" to "",
                        "page_index" to pageIndex,
                        "auto_selected" to false,
                        "detected_blocks" to 0,
                        "review_required" to true,
                    )
                }
            }
        } finally {
            tess.recycle()
        }
    }

}
