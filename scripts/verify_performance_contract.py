#!/usr/bin/env python3
"""Fail CI if core v29/v30 performance safeguards are accidentally removed.

Structural guard only: benchmarks + Flutter tests remain necessary.
If an optimization is legitimately replaced, update this policy and AGENTS.md
with explicit parity evidence; never delete an assertion merely to pass CI.
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent

# These signatures intentionally describe architecture rather than exact
# whitespace, widget layout or user-facing text. Cosmetic UI edits are allowed.
REQUIRED = {
    "lib/core/bundled_catalog.dart": (
        "return compute<",
        "_decodeAndMergeCatalog",
    ),
    "lib/app.dart": (
        "ValueListenableBuilder<_AppPresentation>",
        "_readPresentation(",
        "_presentation.dispose()",
    ),
    "lib/core/academy_state.dart": (
        "_allLessonsSnapshot",
        "_allLessonsSnapshot = null",
    ),
    "lib/ui/background_artwork_preloader.dart": (
        "addPostFrameCallback",
        "Priority.idle",
        # v37 replaces the original fixed 2-image batch with a bounded
        # configurable batch. Check the upper bound AND idle/scroll safety,
        # not the obsolete v29 literal which now incorrectly fails v37.
        "widget.artworkPaths.take(",
        "widget.maxImages.clamp(0, 9).toInt()",
        "while (mounted && _scrolling)",
        "_pauseTimer?.cancel()",
    ),
    "lib/features/learning/textbook_reader_screen.dart": (
        "BoundedPdfPageCache(",
        "_pageCache.keepNear(",
        "_scheduleNeighborPrefetch(",
        "animation: _zoom",
    ),
    "lib/services/bounded_pdf_page_cache.dart": (
        "class BoundedPdfPageCache",
        "maximumPages = 3",
        "maximumBytes = 12 * 1024 * 1024",
        "void clear()",
    ),
    "lib/ui/original_art.dart": (
        "opacity: const AlwaysStoppedAnimation<double>(0.25)",
    ),
    "lib/core/performance_probe.dart": (
        "waitUntilFirstFrameRasterized",
        "addTimingsCallback",
    ),
    "android/app/build.gradle.kts": (
        "isMinifyEnabled = true",
        "isShrinkResources = true",
        "proguard-rules.pro",
    ),
    "scripts/profile_android_performance.sh": (
        "for i in 1 2 3 4 5",
        "20 FULL cycles",
    ),
    "test/pdf_page_cache_test.dart": (
        "BoundedPdfPageCache",
        "clearing book ignores stale results",
    ),
    "test/original_dialogue_test.dart": (
        "lesson-original-dialogue-toggle",
    ),
}

problems = []
for relative, patterns in REQUIRED.items():
    source = ROOT / relative
    if not source.is_file():
        problems.append(f"Missing performance-critical file: {relative}")
        continue
    text = source.read_text(encoding="utf-8")
    for pattern in patterns:
        if pattern not in text:
            problems.append(f"{relative}: missing performance invariant {pattern!r}")

if problems:
    print("PERFORMANCE CONTRACT VIOLATED")
    for item in problems:
        print(f"  - {item}")
    print("Read AGENTS.md before removing or replacing these safeguards.")
    sys.exit(1)

print(f"Performance contract OK ({len(REQUIRED)} guarded files).")
print("This static check does NOT prove startup/FPS performance; device benchmarks still required.")
