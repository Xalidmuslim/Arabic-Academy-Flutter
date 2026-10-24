# Agent instructions — «Байна Ядайк» (Flutter)

**Applies to every future Codex / assistant edit in this repository.** These are project requirements, not optional suggestions. Changes must preserve the latest verified performance behavior, not regress to an older implementation.

## Non-negotiable invariants

1. **Preserve functional and visual parity.** Never rewrite Arabic or Russian materials, tashkeel, translations, lesson order, exercises, progress, audio, settings, local PDFs, user storage, original-PDF dialogue crops, pinch-to-zoom, navigation, or existing UI appearance as a shortcut to speed. Never delete 3D matte decorations, shadows or animations solely to improve metrics.
2. **Start safely.** Check HEAD/branch, working tree, CI and latest working APK; create a backup branch at the known-good SHA before substantial edits. Work on a separate feature branch; don't reset or merge automatically. Never remove a newer feature to gain performance.
3. **Cold start.** Keep the bundled catalog asynchronous and decoded using an isolate (`compute`), and avoid expensive synchronous work on the UI isolate before the first usable frame. Do not replace real content with blank/loading-delay tricks.
4. **State rebuild scope.** Preserve selective app-shell rebuilding in `lib/app.dart`: `MaterialApp` listens only to presentation settings, not every progress or learning-state notification. Keep derived lesson data memoized and correctly invalidated on writes in `lib/core/academy_state.dart`.
5. **Art/image warm-up.** Keep `BackgroundArtworkPreloader` deferred until after the first frame, low-priority and limited to nearby images, with controlled decode resolution and memory pressure. Do not preload all pages/assets or make startup wait for art. Don't introduce gratuitous composited alpha layers.
6. **PDF reading.** Preserve the bounded LRU cache `lib/services/bounded_pdf_page_cache.dart`, one-neighbor idle prefetch, shared in-flight renders, stale-result protection, source-detail quality, and low-cost pinch zoom in `textbook_reader_screen.dart` and `original_pdf_zoom_image.dart`. Parent scrolling must not steal a two-finger PDF gesture. Preserve image-only original Arabic dialogues and collapse/expand.
7. **Animations/GPU.** Keep existing transition feel and matte visual treatment. Optimize only verified excessive rebuilds/layers. Avoid blanket `RepaintBoundary`, blur, lower-resolution Arabic glyphs, and unsolicited animation/removal.
8. **Native Android release.** Keep Flutter AOT release and R8 + Android resource shrinking enabled in `android/app/build.gradle.kts`, with necessary plugin/JNI ProGuard keeps. Do not disable minification to fix a plugin; correct its keep rules.
9. **Safety, signatures and upgrade.** Preserve package ID, progress/data schema, local textbook storage and signing behavior. Never silently replace installed APK signed with another key, clear app data, or remove private PDF files. Development-signed builds must be labeled as such.

## Verification required for every related edit

- First run `python3 scripts/verify_performance_contract.py`.
- Run `flutter analyze` and relevant unit/widget/gesture/navigation tests; for a release or wider refactor run **all Flutter tests** in CI.
- Check Arabic RTL and tashkeel, lessons and exercise content, PDF rendering/cropping, zoom versus page navigation, audio, back navigation, scroll restoration, and progress retention.
- For performance claims compare a previous verified release and the candidate on the **same physical device**, or name the emulator limitation. Collect at least 5 cold + 5 warm starts, 20 navigation loops, Flutter UI/raster p50 and p95, janky frames, memory and first PDF render. Tool: `scripts/profile_android_performance.sh`. No invented FPS or gains.
- Verify R8 output, APK signature/ABI, build size and actual installation where hardware is available. Do not call a build fully regression-tested when CI was cancelled.
- Update existing tests to cover fixes; **never delete or skip tests to achieve a green result**.
- If any performance guard must change due to a justified replacement, document the old/new implementation, proof of parity, benchmarks and rollback plan in the PR. Do not weaken `scripts/verify_performance_contract.py` merely to bypass CI.

## Working protocol

When the user asks for a design/feature change, **implement it on top of all existing performance improvements**. In the PR summary explicitly state: “Performance contract: preserved / intentionally modified with evidence”, along with testing limitations. Keep these instructions with the repository so future agents see them before changing code.

## Automatic Android Development Skills

For **every** new Android/Flutter development task in this repository, read the applicable local skill instructions in `.agents/skills/` before changing application code. These skills complement the project invariants above and never override them.

- `android-recon/SKILL.md`: inspect current branch/HEAD, relevant source, routes, data, build configuration and baseline before edits.
- `android-design/SKILL.md`: apply approved visual references; preserve matte 3D graphics, source images, typography and icons.
- `android-test/SKILL.md`: reproduce bugs, add regression coverage and verify actual test/build results.
- `android-diff/SKILL.md`: compare code, UI, functionality and APK before/after without losing previous optimization or content.
- `android-performance/SKILL.md`: diagnose scroll/refresh pacing using Flutter UI/raster metrics, 8.33 ms 120 Hz budget, device traces and controlled A/B experiments.

Choose only the relevant skills for the current task; do not apply them mechanically or mistake skill installation for performance optimization. Preserve this repository's Flutter stack, user data, private PDFs, lesson order and all previously working features. Prefer minimal, testable changes on a separate branch. Claim 120 FPS only after repeatable real-device measurements, not from display refresh rate or successful CI alone.
