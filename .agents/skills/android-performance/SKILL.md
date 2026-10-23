---
name: android-performance
description: Diagnose jank, non-smooth vertical scroll, startup delay, transitions or 60/90/120 Hz responsiveness in Kotlin/Compose and Flutter apps. Use when requested to optimize performance or reuse an existing smooth-motion implementation.
---

# Android performance — measure then optimize

1. Profile on a real target Android device and release/profile build when available. Determine display refresh rate and app frame rate separately; 120 Hz panel does not prove 120 FPS. Record reproducible scroll path, warmup, CPU/GPU and frame timeline. If no device, offer static hypotheses, never verified FPS claims.
2. Treat 60 Hz (~16.67 ms), 90 Hz (~11.11 ms), 120 Hz (~8.33 ms) as nominal per-frame budgets; headroom is required. Track jank percent, p90/p95 frame time and long frames using suitable profilers.
3. Native Android: check main-thread IO, bitmap decode/resize, layout/recomposition churn, LazyColumn item keys, unstable state, expensive draw, image caching, layers, transitions, baseline profiles, Macrobenchmark, startup traces and release/R8 differences. Avoid blindly copying motion values from another project.
4. Flutter: inspect timeline's UI/raster threads, shader compilation, widget rebuilds, large images, unbounded layouts, expensive list children, keepAlive costs and platform channels. Prefer proven ListView.builder/slivers and profile builds; avoid assuming R8 fixes Flutter frame issues.
5. Change one plausible bottleneck at a time, preserve working features and navigation, measure again on the same device/build/state and report before/after with methods and limitations.
6. Check cold/warm launch and smooth back navigation as separate metrics. A neat animation duration is not equivalent to smooth actual scrolling.
7. Never promise 120 FPS or claim improved smoothness without reproducible frame evidence. Provide next profiling steps when hardware or builds are missing.
