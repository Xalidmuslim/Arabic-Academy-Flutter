package com.example.arabic_academy

import android.graphics.Rect
import kotlin.math.max

/**
 * Page-layout selection for locally imported learner textbooks. Pure Kotlin:
 * native OCR produces text-line bounds; this selects only Arabic dialogue
 * sections, never blindly returns the page header, picture captions or both
 * independent conversations as a single "original dialogue".
 *
 * Coordinates are page-bitmap pixels. Individual lines are untrusted OCR;
 * a human must still check words and diacritics against their own book.
 */
internal object ArabicDialogueRegion {
    data class Line(val text: String, val bounds: Rect, val confidence: Float)
    data class Selection(
        val crop: Rect?,
        val groupsOnPage: Int,
        val lineCount: Int,
    )

    private val arabic = Regex("[\\u0621-\\u064A]")
    private val harakat = Regex("[\\u064B-\\u065F\\u0670\\u0640]")
    private val separators = Regex("""[\\s،,؛.:!؟"'()«»٠-٩۰-۹]""")

    internal fun isInstruction(text: String): Boolean {
        val normalized = text.replace(harakat, "")
            .replace(separators, "")
            .replace('أ', 'ا').replace('إ', 'ا').replace('آ', 'ا')
            .replace('ى', 'ي')
        return normalized.contains("الحوار") ||
            normalized.contains("انظرو") ||
            normalized.contains("استمع") ||
            normalized.contains("الوحده") ||
            normalized.contains("الدرس") ||
            normalized.contains("كتابالطالب") ||
            normalized.contains("العرض")
    }

    internal fun onlyDialogueLines(text: String): String {
        return text.lineSequence()
            .map { it.trim() }
            .filter { line ->
                arabic.findAll(line).count() >= 3 &&
                    !isInstruction(line) &&
                    !line.contains("http", ignoreCase = true)
            }
            .joinToString("\n")
            .take(100000)
    }

    fun choose(
        lines: List<Line>,
        width: Int,
        height: Int,
        dialogueSlot: Int,
    ): Selection {
        if (width < 1 || height < 1) return Selection(null, 0, 0)
        val candidates = lines.filter { line ->
            val box = line.bounds
            box.width() > 0 &&
                box.height() > 0 &&
                box.top >= height * 0.14 &&
                box.bottom <= height * 0.98 &&
                box.left >= 0 && box.right <= width &&
                arabic.findAll(line.text).count() >= 3 &&
                !isInstruction(line.text) &&
                line.confidence >= 4f
        }
        // Most Bayna Yadayk dialogue pages have illustration(s) on the left
        // and Arabic conversations in the right-hand text panel.
        val column = candidates.filter {
            it.bounds.left >= width * 0.48 &&
                it.bounds.right >= width * 0.73
        }
        val text = if (column.size >= 3) column else candidates
        if (text.size < 2) return Selection(null, 0, text.size)
        val sorted = text.sortedBy { it.bounds.centerY() }
        val distances = sorted.zipWithNext { a, b ->
            b.bounds.top - a.bounds.bottom
        }.filter { it > 0 }.sorted()
        val typical = if (distances.isEmpty) 0 else distances[distances.size / 2]
        val minGap = max((height * 0.052).toInt(), typical * 3)
        val groups = mutableListOf<MutableList<Line>>()
        for (line in sorted) {
            if (groups.isEmpty() ||
                line.bounds.top - groups.last().last().bounds.bottom > minGap) {
                groups.add(mutableListOf(line))
            } else {
                groups.last().add(line)
            }
        }
        val sections = groups.filter { it.size >= 2 }
        // Fail closed: if layout analysis cannot isolate a contiguous text
        // block, never return all lines from an unsegmented full page.
        if (sections.isEmpty()) return Selection(null, 0, text.size)
        if (sections.size == 1) {
            val only = sections.first()
            val verticalSpan = only.maxOf { it.bounds.bottom } -
                only.minOf { it.bounds.top }
            if (verticalSpan > height * 0.70) {
                return Selection(null, 1, only.size)
            }
        }
        val position = (dialogueSlot - 1).coerceIn(0, sections.size - 1)
        val selected = sections[position]
        val left = (selected.minOf { it.bounds.left } -
            width * 0.022).toInt().coerceAtLeast(0)
        val right = (selected.maxOf { it.bounds.right } +
            width * 0.020).toInt().coerceAtMost(width)
        val top = (selected.minOf { it.bounds.top } -
            height * 0.015).toInt().coerceAtLeast(0)
        val bottom = (selected.maxOf { it.bounds.bottom } +
            height * 0.020).toInt().coerceAtMost(height)
        return if (right - left < 24 || bottom - top < 24) {
            Selection(null, sections.size, selected.size)
        } else {
            Selection(Rect(left, top, right, bottom), sections.size, selected.size)
        }
    }
}
