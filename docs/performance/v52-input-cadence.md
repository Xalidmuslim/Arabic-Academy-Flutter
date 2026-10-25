# v52: persistent scroll judder with low draw times

Baseline: GPU 51, commit 7a6f155bfb7e018efc5d87e6db4c79071acd6f64.
The user reports judder remains after repeated scrolling and shadow toggles.

| Card shadows | Illustration shadows | UI p95 ms | Raster p95 ms | Above 8.33 ms |
| --- | --- | --- | --- | --- |
| on | on | 1.5 | 2.3 | 0/121 |
| on | off | 1.7 | 16.9 | 62/161 |
| off | off | 2.6 | 4.6 | 0/122 |
| off | on | 1.8 | 8.5 | 8/122 |
| on | off | 2.4 | 7.6 | 2/123 |
| on | on | 3.8 | 5.6 | 1/167 |
| off | off | 3.6 | 4.8 | 1/178 |

These are screenshots of different windows, not a controlled benchmark.
The switches remove shadows, not card contents or illustration decoding.
They do not exclude every possible image-related cost. The earlier dark-theme
GPU 50 screenshots are not a matched comparison with this light-theme run.

## Verified issues and selected experiment

1. The old HUD measured UI/raster workload and display Hz, without measuring
   produced-frame intervals. A 2 ms draw time is compatible with a 60 Hz frame
   cadence. v52 measures frame-start intervals during each scroll only.
2. The old collector cleared arrays on mode changes but accepted late batches
   drawn before the change. The new regression failed on unmodified v51 in
   Actions run 40172246863: old 30 ms raster frames became the new mode's report.
   v52 filters by scroll start/end timestamps and resets the window for each
   gesture/mode; idle periods, previous routes and pre-toggle frames are excluded.
3. Flutter touch resampling is disabled by default and was never enabled here.
   The v52 diagnostic APK opts into Android touch resampling, using Flutter's
   default sampling offset and unchanged scroll physics. A touch icon toggles
   synchronized/raw input in the SAME build and resets measurements.
   This is a hypothesis for perceived judder, not a proven device fix.
4. The native refresh hint was only retried from resume/focus. If the surface was
   not valid then, it was skipped with no surface-created callback. v52 retries
   at actual Flutter surface creation, caches a successful request until surface
   destruction, and uses the Android-11 two-argument API on API 30.
   Window/display hints remain advisory and capped by the existing policy.

The diagnostic native Choreographer probe runs only during scrolling, stops on
pause/destruction, and keeps at most 300 timestamps. Its callback cadence and
Flutter's produced-frame cadence distinguish an app scheduling cap from slow
Flutter work. Neither is compositor presentation FPS. It may influence Android's
active vsync policy, so system presentation traces remain the final evidence.

## Validation

Tests cover 60/120 Hz cadence with identical draw costs; late/duplicate/idle
timings; bounded history; native callback statistics; interpolated input at
120 Hz; and real two-finger PDF viewer zoom under resampling. Existing full
Flutter regression, artwork, geometry, navigation, startup and content checks
remain required. The candidate APK is separately installed as perf52 and
development-signed; production signing and all user storage stay unchanged.

Performance contract: preserved. Matte 3D, cached shadows, images, text,
content, progress, PDF cache/gestures, audio and approved transitions are kept.
Production touch resampling remains opt-in until same-device A/B verification.

No Android device is connected. No sustained 120 FPS, OEM cap or perceptual
improvement has been verified. On the same light-theme dialogue list, fling,
release and wait for the panel to update; compare synchronized/raw touch with
all shadows on. Android vsync near 60, Flutter near 60 and low UI/raster work
suggest a scheduling constraint; Android near 120 with Flutter near 60 suggests
a Flutter/pipeline issue. Confirm actual presentation via Perfetto/SurfaceFlinger.

Primary references:
- https://api.flutter.dev/flutter/gestures/GestureBinding/resamplingEnabled.html
- https://developer.android.com/reference/android/view/SurfaceHolder.Callback
- https://developer.android.com/reference/android/view/Surface
