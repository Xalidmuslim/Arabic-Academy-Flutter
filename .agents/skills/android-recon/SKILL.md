---
name: android-recon
description: Audit existing Kotlin/Jetpack Compose or Flutter apps before a change. Use automatically when screen inventory, navigation mapping, app structure, existing features, data safety, or unknown regressions matter.
---

# Android recon — existing-project audit

1. Locate the authoritative project and current branch/commit. Check working tree, languages, entry points, Gradle/Flutter versions, module boundaries, release/build variants and relevant project AGENTS.md. If inaccessible, disclose the limitation; do not guess.
2. Inventory all accessible screens/routes and their states (loading, empty, offline, error, reading, settings, backward navigation). Map which composables/widgets, resources and data sources drive each UI state.
3. Preserve original content, translations, assets, license/business logic, reading preferences and saved user state. Distinguish a design-only request from feature changes.
4. Record the baseline: reproducible commands, current screenshot references, known performance metrics, current APK identity/version if available, existing tests and known defects.
5. Write a scope map of files and flows touched, constraints, external integrations, possible regressions and needed verification. Do not reverse-engineer private third-party APIs or copy licensed assets.
6. For small tasks, keep findings brief; do not create elaborate documents that delay the requested fix. Deliver evidence, uncertainties and precise next actions.
