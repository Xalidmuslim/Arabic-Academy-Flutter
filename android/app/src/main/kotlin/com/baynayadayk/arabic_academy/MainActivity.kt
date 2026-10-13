package com.example.arabic_academy

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/**
 * Android's system PdfRenderer reads a book imported into app-private storage.
 * The original scans never leave the user's device or enter our public repo.
 * Single-threaded executor prevents page/renderer races and main-thread stalls.
 */
class MainActivity : FlutterActivity() {
    private val readerExecutor = Executors.newSingleThreadExecutor()
    private var descriptor: ParcelFileDescriptor? = null
    private var renderer: PdfRenderer? = null

    private fun closeReader() {
        renderer?.close()
        renderer = null
        descriptor?.close()
        descriptor = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bayna.private_pdf")
            .setMethodCallHandler { call, result ->
                readerExecutor.execute {
                    try {
                        when (call.method) {
                            "open" -> {
                                val path = call.argument<String>("path")
                                    ?: throw IllegalArgumentException("Missing PDF path")
                                val file = File(path).canonicalFile
                                val safeDir = File(filesDir, "private_textbooks").canonicalFile
                                require(file.parentFile == safeDir && file.extension.lowercase() == "pdf") {
                                    "Only an app-private imported PDF can be opened"
                                }
                                require(file.isFile && file.length() in 5L..(400L * 1024 * 1024)) {
                                    "Imported PDF does not exist or exceeds 400MB"
                                }
                                closeReader()
                                descriptor = ParcelFileDescriptor.open(
                                    file, ParcelFileDescriptor.MODE_READ_ONLY
                                )
                                renderer = PdfRenderer(descriptor!!)
                                val pageCount = renderer!!.pageCount
                                runOnUiThread { result.success(pageCount) }
                            }
                            "render" -> {
                                val pdf = renderer ?: throw IllegalStateException(
                                    "Open an imported PDF before rendering"
                                )
                                val pageIndex = call.argument<Int>("page") ?: 0
                                require(pageIndex in 0 until pdf.pageCount) {
                                    "PDF page index out of range"
                                }
                                val targetWidth = (call.argument<Int>("width") ?: 1000)
                                    .coerceIn(480, 1500)
                                val page = pdf.openPage(pageIndex)
                                try {
                                    val height = (targetWidth.toDouble() *
                                        page.height / page.width).toInt().coerceAtLeast(1)
                                    val bitmap = Bitmap.createBitmap(
                                        targetWidth, height, Bitmap.Config.ARGB_8888
                                    )
                                    try {
                                        Canvas(bitmap).drawColor(Color.WHITE)
                                        page.render(
                                            bitmap, null, null,
                                            PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                                        )
                                        val bytes = ByteArrayOutputStream()
                                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, bytes)
                                        runOnUiThread { result.success(bytes.toByteArray()) }
                                    } finally {
                                        bitmap.recycle()
                                    }
                                } finally {
                                    page.close()
                                }
                            }
                            "close" -> {
                                closeReader()
                                runOnUiThread { result.success(null) }
                            }
                            else -> runOnUiThread { result.notImplemented() }
                        }
                    } catch (error: Exception) {
                        runOnUiThread {
                            result.error("PDF_READER_ERROR", error.message, null)
                        }
                    }
                }
            }
    }

    override fun onDestroy() {
        readerExecutor.execute { closeReader() }
        readerExecutor.shutdown()
        super.onDestroy()
    }
}
