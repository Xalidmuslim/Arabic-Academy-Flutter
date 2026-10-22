# Bayna Yadayk — Medicine Smooth Motion v0.35

**Source reference:** \`Xalidmuslim/Prophetic-Medicine-Native\`, commit
\`9a3b7cac1f24926966578e11248f0ac0e3f02a76\` on
\`golden/medicine-smooth-2026-10-10\`. The reference was read only.

## Measured in reference source (implementation, not hardware performance)

- \`App.kt\`: \`AnimatedContent\` with \`FastOutSlowInEasing\`, general fade
  205/155 ms, horizontal slide 225/175 ms (about 1/40 screen),
  reader page turns 245/235 ms, and **no transition** for book↔reader.
- \`MainActivity.kt\`: 170 ms \`Crossfade\` for ready content; expensive work
  via \`Dispatchers.IO\` before displaying the book.
- \`MedicineHomeArtwork.kt\`: bounded, cached bitmap predecoding.
- \`Screens.kt\`/\`Reader.kt\`: \`LazyColumn\` with state and lightweight
  per-chapter 110 ms foreground fade.
- The original project and its branch have **not** been changed.

## Flutter adaptation in Bayna Yadayk

- \`lib/ui/medicine_smooth_motion.dart\`: page transition policy with
  225 ms enter and 175 ms reverse. Fade interpolates via
  \`Curves.fastOutSlowIn\`; horizontal motion is opt-in and only 1.8%
  of screen width. Reading/content routes have no horizontal motion.
- Root tabs: 205 ms fade in / 155 ms fade out; previous screen is
  deliberately excluded from the switch layout to avoid double backgrounds.
- All themes use the same unobtrusive \`PageTransitionsBuilder\`; existing
  back stack semantics, platform back and swipe handling remain intact.
- Navigation from a pushed screen to a root tab is deferred until
  the **popped route completes**, eliminating simultaneous back + tab
  transitions.
- Reduced motion from Android accessibility settings or the in-app
  \`reduceMotion\` preference disables these animations.
- Visible home artwork is prioritized by existing async idle preloading
  after the first frame (max four images, one-at-a-time).
- Existing off-isolate catalog JSON decoding, virtualized \`SliverList\`,
  \`CustomScrollView\`, widget-owned scroll positions, lightweight cards,
  and opt-in frame timing diagnostics are retained.
- No changes to copy, screen geometry, colors, fonts, images, learning
  data, lesson progression, stored preferences, or online services.

## Verification

- Run CI Flutter analyze and motion/scroll/back/animation tests.
- Build ARM64 Flutter Release APK (Android R8 and resource shrinking are
  already enabled in \`android/app/build.gradle.kts\`) and verify signing.
- Android **hardware** validation is still required to confirm smoothness:
  measure startup first-frame, UI/raster p95 in profile mode; inspect
  cold launch, quick tabs, reader, back gesture, theme/settings, repeat
  navigation and 60/120 Hz scrolling.
- Hardware FPS, cold-start milliseconds, and lack of jank are **not**
  claimed as measured by widget tests or CI.
