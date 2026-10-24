---
name: android-diff
description: Compare Android or Flutter app changes to approved screenshots, working builds and required features. Use for design accuracy, unexpected unchanged UI, APK discrepancy, functional parity and regression reviews.
---

# Android diff — visual and behavioral regression

1. Select a known baseline: approved reference (for target design), last working same-app build (for regression), or current production version (for functionality). Never conflate three comparisons.
2. For screenshots use equal viewport, density, font scale, locale, theme, scroll position and content. Compare layout and typography; do not ignore color when color matching is required. Allow deliberate redesigns only with explicit scope.
3. Compare screen by screen, including dialog states, launcher icon, app bar, navigation bar, reader pages and settings. Check geometry, clipping, unreadable small text, blank images, unintentional white icon backgrounds.
4. Make a feature ledger (unchanged/changed/broken/not checked). For changed flows compare navigation, persisted settings, back button, gestures, scroll and transitions.
5. If the user reports 'nothing changed', inspect selected branch/commit, APK timestamp/version, variant, installed package name, resource packaging, cache behavior and device installation path before changing UI again.
6. Output a concise discrepancy report with grounded screenshots/logs where available and prioritized fixes. Numeric similarity is a helper metric, not a claim of quality or exact match.
