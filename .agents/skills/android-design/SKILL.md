---
name: android-design
description: Improve or review visual UI of an existing Kotlin Compose or Flutter app, match a user-approved reference, maintain typography, colors, 3D/book styling, icon assets and accessibility.
---

# Android design — grounded reference matching

1. Read the user's approved reference, actual screenshot(s), design tokens and source widgets/composables. Never describe a mockup as a code change.
2. Record design roles: background/surfaces/foreground, muted/on-surface, accent, font hierarchy, spacing, elevation, motion, status/navigation bar treatment, adaptive icons and interactive hit targets.
3. In Kotlin/Compose use existing Material3/theme and component patterns; in Flutter use ThemeData/ThemeExtension and native widgets where appropriate. Reuse components and original working resources; avoid wholesale framework replacement.
4. Compare at the same device dimensions, font scale, locale, theme and UI state. Check clipped text, overflow, contrast, tap targets, back gestures, scroll position, system bars and dynamic font sizes.
5. For book-themed apps, assess page readability, subtle paper texture, consistent chapter cards, compact margins and legible contrast. Preserve all reading content and approved page structure.
6. Change only scoped UI files and related icon resources. Verify launcher and in-app icons separately (foreground, background, mask/adaptive icon, density, manifest).
7. Deliver affected files, visible before/after differences and checks. If screenshot/device not available, mark verification pending.
