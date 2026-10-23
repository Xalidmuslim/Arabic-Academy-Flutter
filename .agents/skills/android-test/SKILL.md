---
name: android-test
description: Test or fix bugs in native Android Kotlin Compose and Flutter apps. Use on behavior changes, lifecycle bugs, crashes, navigation issues, permissions, persistence and after app code modifications.
---

# Android test — proof over assertion

1. Capture the actual reproduction path: build/version, device/Android API or Flutter channel, steps, expected and observed behavior. Keep potential issues separate from reproduced bugs.
2. Check existing tests first; add a failing regression test where practical before fixing a reproduced bug. Avoid rewriting unrelated behavior.
3. Kotlin: use existing JUnit, Compose UI Test, UI Automator/instrumentation when applicable; run appropriate Gradle tasks, lint and release checks. Flutter: flutter analyze, flutter test, integration_test where configured. Do not claim commands executed unless logs exist.
4. Cover back/forward navigation, rotation or process recreation when relevant, state restoration, loading, errors, dark/light themes, long Arabic/Russian text, low connectivity, persistence and accessibility.
5. Classify severity by reproducible impact (data loss/security/core flow; blocking; workaround; cosmetic). Each bug report includes steps, evidence, root cause, changed code and regression test.
6. Verify actual output artifact before calling an APK ready. Record package/application ID, versionCode, build variant, signing expectations and install compatibility if checked.
7. Summarize tested/pass/fail/not-run honestly and remaining risks. Do not substitute a green compile for on-device functional verification.
