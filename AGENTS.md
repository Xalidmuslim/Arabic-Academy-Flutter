# Android Development Skills — automatic application workflow

When working on an Android or Flutter app, inspect the real repository, branch and existing functionality before making changes. Preserve content, settings, design decisions, and previous optimizations. Keep Kotlin/Compose native and Flutter in Flutter. Do not claim tested builds or 120 FPS without evidence.

Automatically select matching repository skills:
- `android-recon`: inspect screens, code, navigation and baseline.
- `android-design`: UI design, reference and icons.
- `android-test`: bugs, behavior, regression tests and APK checks.
- `android-diff`: before/after comparison and feature parity.
- `android-performance`: frame pacing, scroll, transitions, cold start.

Select only relevant skills; do not apply all five mechanically. Make minimal, reviewable changes and avoid touching other projects. If a tool/device/build is inaccessible, disclose the limitation. Never change working application code just to install or maintain these skills.


## Codex Cloud + AI-Council (without an OpenAI API key)

Read [docs/CODEX_AI_COUNCIL.md](docs/CODEX_AI_COUNCIL.md) when a task requests
programmer, arabist, tester, Codex Cloud, or AI-Council coordination.

- First inspect this repository's real branch, current commit, existing screens,
  source files, content assets, tests and CI before editing.
- For Issue #48's no-API pilot, permitted implementation scope is exclusively
  `test/widget_test.dart` and `test/content_test.dart`. Preserve existing
  tests, Flutter source, the Arabic source/diacritics, translations, user data
  and all working features. Do not change other files in that pilot.
- Work as a real programmer only after Codex Cloud has been authorized for
  this repository. Add focused regression tests, run actual
  `flutter analyze --no-fatal-infos` and `flutter test`, record full
  exit statuses and create a **draft** PR when push access is available.
- A separate reviewer task must read the complete resulting diff and real
  CI logs. A passing CI is not an independent Arabic semantic review.
- Never merge a PR, alter `main`, publish an APK, or claim device FPS without
  the owner's explicit approval and verifiable evidence.
- These files are repository instructions only: committing them cannot start
  Codex Cloud, connect GitHub accounts or grant access to private repositories.
