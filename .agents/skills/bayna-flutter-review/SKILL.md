---
name: bayna-flutter-review
description: Review Bayna Yadayk Flutter/Dart changes using a narrow ECC-inspired checklist while preserving the app's audited performance, content, and design contracts.
---

# Bayna Yadayk — Flutter review (adapted from ECC)

Source for review methodology: https://github.com/affaan-m/ECC/tree/main/agents/flutter-reviewer.md and https://github.com/affaan-m/ECC/tree/main/skills/flutter-dart-code-review (MIT). This is a project-specific adaptation, not an installation of the entire ECC plugin.

## Scope and priority

Read repository `AGENTS.md` first. Its invariants override generic review suggestions. Never rewrite course Arabic, translations, audio, original PDF content, user progress/storage, images, matte 3D appearance, navigation or approved transitions just to satisfy a review checklist.

Review the exact git diff and at least the immediate caller/callee context. Report only actionable findings with a path, evidence, severity (critical/high/medium), impact and narrow fix. Avoid styling noise and do not claim performance gains without frame timings.

## Checks for changed Flutter code

1. **State and lifecycle:** ValueListenable scopes, listener cleanup, timers and subscriptions, mounted after await, stale async results, correct cache invalidation; `AcademyApp` must not rebuild because of lesson progress.
2. **Scrolling/rendering:** lazy slivers for long lists, stable keys for changing lists, unintended work in build, excess opacity/saveLayer/offscreen compositing, image decode size matching cache keys, unexpected redraws. Preserve matte depth and artwork.
3. **Image preload:** post-frame and idle-only execution, bounded count and decode size, pause during scrolling, cleanup of scheduled timers on dispose; never gate the first usable frame.
4. **Reader/gestures:** one-neighbor bounded PDF prefetch, 3-page/12 MiB cache and stale-result defense; two-finger zoom must not become parent page swipe. Never reduce Arabic PDF legibility.
5. **Security and data:** inspect changed code for accidentally committed keys, plaintext sensitive data, unguarded async navigation, insecure Android exported components. Never commit keys/keystores.
6. **Accessibility/content:** readable Arabic RTL/tashkeel, focus and touch-target reachability (including floating navigation), Russian locale, reduced-motion preference.
7. **Tests and Android:** a failing regression test first for behavior changes; `flutter analyze --no-pub`, focused tests, full suite for wide refactors, R8/resource shrinking and development-key labeling. GitHub Actions cancellation is **not** test success.

## Fast review commands (use repository's existing toolchain)

```bash
python3 scripts/verify_performance_contract.py
python3 scripts/verify_assets.py
python3 scripts/verify_native_config.py
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --concurrency=2 test/background_artwork_preloader_test.dart test/neumorphic_dashboard_test.dart test/navigation_back_test.dart test/scroll_isolation_test.dart test/app_shell_performance_test.dart test/pdf_page_cache_test.dart test/pdf_zoom_test.dart
```

For any FPS/120Hz claim require on-device profile: five cold and five warm launches, twenty navigation loops, frame timing UI/raster p50/p95, janky frames and memory using `scripts/profile_android_performance.sh`; report missing measurements explicitly.

Output: `Evidence → Impact → Minimal change → Regression test → Validation status`. If there are no verified defects, say so. Do not propose blanket RepaintBoundary or disabling animations as a substitute for measurement.
