# Flutter widget-runtime visual validation

These captures are **Flutter widget tester engine renders, not Android/device
screenshots**. They do not establish Android startup, plugin/device integration,
or production frame timing. The software emulator's SystemUI/Quickstep ANRs were
not representative app measurements; its `android-debug-first.png` has been
removed from acceptance evidence.

Run after the UI coordinator has finished edits and dependencies are available:

```bash
source /workspace/academy-env.sh
bash scripts/run_visual_acceptance.sh
```

The script pins Flutter 3.35.7, uses `--no-pub`, includes actual test assets, and
never launches an emulator or native build. A fresh timestamped directory under
`docs/screenshots/flutter-tester/` contains engine PNGs, each case's diagnostics,
`flutter-test.log`, `run.json`, and a hash-indexed `summary.json`.
`latest.json` points to the latest run and states whether the full matrix passed.
Optional Flutter test filters are supported after `--`, for example:

```bash
bash scripts/run_visual_acceptance.sh -- --plain-name 'visual ru-320-2x home'
```

A filtered success cannot claim the whole matrix passed. Running ordinary
`flutter test --no-pub test/visual_acceptance_test.dart` executes the layout
regressions without writing screenshots. The test exports PNGs only when
`VISUAL_ACCEPTANCE_DIR` is set; the script manages that destination.

The harness loads bundled assets through `rootBundle`, assembles the same 15
lessons and 22 grammar topics as `main.dart`, and starts fresh mock local
preferences for each case. Product `AcademyState`, theme, widgets, local searches,
and actual bundled Arabic text are used. No mock lesson/statistic is substituted.
`FontLoader` loads Manrope, NotoNaskhArabic and MaterialIcons into the real tester
engine. Production shadows are enabled; the theme selects Android widget styling.
The backend is explicitly unconfigured, so local visual validation makes no
online-role, purchase, microphone, speech or notification claim.

Four profiles exercise each screen: Russian and Arabic/RTL at 390×844, plus
Russian and Arabic/RTL at 320×800 with **2× text scaling**. Device pixel ratio and
PNG capture pixel ratio are 1; dimensions describe logical tester pixels. Tests
assert inherited text direction and scaling. Animations are disabled in the
capture MediaQuery; screen settings otherwise retain their defaults.

The 13 scenarios cover home, courses, lesson introduction, a real grammar
ExerciseRunner, dictionary, grammar, progress, settings, local teacher dashboard,
and an editor populated from the real first lesson. Additional routes cover the
lesson dialogue, first dictionary entry, and first grammar topic's
examples/table/exercises. Screens mount directly in a production-themed
MaterialApp; the local teacher view is reached through the actual demo-role menu.
The exercise adds only a neutral Scaffold/ListView host around ExerciseRunner.

Each scenario captures its initial frame, first vertical scroll when available,
and end. Every lazy vertical row is visited in increments below one viewport;
failure to reach the end within 80 steps fails the case. Framework diagnostics,
including RenderFlex overflow, remain logged and make the test fail. Case JSONs
identify viewport, locale, screen and scroll phase. Failed captures are diagnostic
material, not accepted baselines. This is a runtime/layout regression matrix,
not a byte-for-byte golden comparison or proof that every translation is complete.
Missed hit-test warnings are fatal. Detail targets are scrolled into view before
taps, and assertions confirm dictionary/grammar detail routes actually opened.

Review the actual PNGs for font shaping, Arabic vowels, legibility, artwork,
spacing and clipping. Report product defects to the UI coordinator with the
case name, case JSON and capture; keep fixes outside this harness's write scope.
Do not composite screenshots, crop reference images, paint replacement UI, or
label tester output as device evidence. Generated reports include source and
screenshot hashes so the rendered working tree can be identified.
Source, assets, the dependency lock and harness are hashed before the run and
compared afterward. A source change during capture prevents complete-matrix
acceptance and makes the runner exit unsuccessfully; rerun after coordination.
Layout success leaves `visual_review` pending until the PNGs are inspected.
Variable-font weights must come from product TextStyle.fontVariations; the harness
uses the unchanged bundled font binaries and never patches their weight axes.
