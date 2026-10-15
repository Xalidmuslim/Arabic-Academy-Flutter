package com.example.arabic_academy

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Rect
import android.os.Build
import android.Manifest
import android.content.pm.PackageManager
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
    private var reminderPermissionResult: MethodChannel.Result? = null
    private val reminderPermissionRequest = 9127

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == reminderPermissionRequest) {
            val result = reminderPermissionResult
            reminderPermissionResult = null
            result?.success(
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            )
        }
    }


    private fun closeReader() {
        renderer?.close()
        renderer = null
        descriptor?.close()
        descriptor = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "bayna.study_reminders").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
                                == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else if (reminderPermissionResult != null) {
                            result.error("BUSY", "Permission request pending", null)
                        } else {
                            reminderPermissionResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                reminderPermissionRequest
                            )
                        }
                    }
                    "schedule" -> {
                        val dates = call.argument<List<Long>>("instants")
                            ?: throw IllegalArgumentException("Missing schedule")
                        StudyReminderScheduler.schedule(this, dates)
                        result.success(true)
                    }
                    "cancel" -> {
                        StudyReminderScheduler.cancel(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("STUDY_REMINDER_ERROR", error.message, null)
            }
        }
        // Android limits system-gesture exclusions to a small edge area.
        // Exclude only the right-hand center of the PDF viewport, not the
        // full gesture edge or global Android navigation.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bayna.reader_gesture")
            .setMethodCallHandler { call, result ->
                if (call.method != "excludeRightEdge") {
                    result.notImplemented()
                } else {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        val enabled = call.argument<Boolean>("enabled") == true
                        val view = window.decorView
                        view.post {
                            val density = resources.displayMetrics.density
                            val strip = (20 * density).toInt()
                            val height = (170 * density).toInt()
                            val middle = view.height / 2
                            val exclusion = if (enabled && view.width > strip && middle > 0) {
                                listOf(Rect(view.width - strip, middle - height / 2,
                                    view.width, middle + height / 2))
                            } else emptyList()
                            view.systemGestureExclusionRects = exclusion
                        }
                    }
                    result.success(null)
                }
            }
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
                            "ocrArabicDialogue" -> {
                                val part = call.argument<Int>("part") ?: 1
                                val page = call.argument<Int>("page") ?: 0
                                val slot = call.argument<Int>("dialogueSlot") ?: 1
                                val recognition = ArabicPdfOcr.recognizeDialogue(
                                    this@MainActivity, part, page, slot
                                )
                                runOnUiThread { result.success(recognition) }
                            }
                            "ocrArabicPage" -> {
                                // Offline recognition: only locally imported PDF,
                                // model bundled at build, no network activity.
                                val part = call.argument<Int>("part") ?: 1
                                val page = call.argument<Int>("page") ?: 0
                                val recognized = ArabicPdfOcr.recognize(
                                    this@MainActivity, part, page
                                )
                                runOnUiThread { result.success(recognized) }
                            }
                            "extractText" -> {
                                // Read only the local imported PDF for this user's book.
                                // The extraction is never sent to a backend or cached in APK assets.
                                val part = call.argument<Int>("part") ?: 1
                                require(part == 1 || part == 2) { "Invalid book part" }
                                val pageIndex = call.argument<Int>("page") ?: 0
                                val safeDir = File(filesDir, "private_textbooks").canonicalFile
                                val book = File(safeDir, "student_book_1_part_${part}.pdf").canonicalFile
                                require(book.parentFile == safeDir) { "Invalid PDF location" }
                                if (!book.isFile) {
                                    runOnUiThread {
                                        result.success(mapOf("status" to "missing", "text" to ""))
                                    }
                                } else if (Build.VERSION.SDK_INT < 35) {
                                    runOnUiThread {
                                        result.success(mapOf("status" to "unsupported", "text" to ""))
                                    }
                                } else {
                                    val content = ParcelFileDescriptor.open(
                                        book, ParcelFileDescriptor.MODE_READ_ONLY
                                    ).use { handle ->
                                        PdfRenderer(handle).use { pdf ->
                                            require(pageIndex in 0 until pdf.pageCount) {
                                                "PDF page index out of range"
                                            }
                                            pdf.openPage(pageIndex).use { page ->
                                                page.textContents
                                                    .map { it.text.trim() }
                                                    .filter { it.isNotEmpty() }
                                                    .joinToString("\n")
                                            }
                                        }
                                    }
                                    val limited = content.take(100000)
                                    runOnUiThread {
                                        result.success(mapOf(
                                            "status" to (if (limited.isEmpty()) "empty" else "ok"),
                                            "text" to limited
                                        ))
                                    }
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
