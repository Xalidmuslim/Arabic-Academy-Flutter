# v51: dialogue-card raster investigation

Baseline: `fb0a714460383c6e3097acaa1175289715fce383` (GPU 50).
The user explicitly confirmed both supplied screenshots are from GPU 50.

| Screenshot mode | UI p95 | Raster p95 | Frames over 8.33 ms |
| --- | --- | --- | --- |
| Card shadows on, artwork on | 2.0 ms | 14.4 ms | 21/127 |
| Card shadows off, artwork on | 1.9 ms | 6.4 ms | 2/159 |

These are different samples, not a controlled benchmark. They identify card
shadow raster work as the leading suspect, not a proven FPS or GPU-time result.
Flutter's reported display refresh is 120 Hz; it is not delivered FPS.

## Source evidence

`SituationsScreen` already uses lazy `ListView.builder` with automatic child
repaint boundaries. Its `Panel` uses the regular, radius-22 `NeumorphicSurface`.
In GPU 50 the cached shadow is an `Image.asset` with `centerSlice`, stretched
over the whole card plus a 56 logical-pixel margin on each side.

In the pinned Flutter 3.35.7 source, `paintImage` calls `drawImageNine`.
`engine/src/flutter/impeller/display_list/nine_patch_converter.cc`,
`NinePatchConverter::DrawNinePatch`, loops over the three horizontal and three
vertical sections and issues a `DrawImageRect` for each. Its own TODO suggests
batching. Thus v50's comment promising one texture draw was incorrect for
Impeller. The centre also shades an area completely covered by the opaque card.

For a representative 330 × 430 logical-pixel card, the expanded shadow is
442 × 542. Its hidden centre is 286 × 386, or 46.1% of that rectangle.
This is geometric overdraw, not a measured 46.1% frame-time improvement.

## Change and safeguards

`CachedCardShadow` reuses the identical PNG and original edge mapping. One
textured mesh batches eight perimeter patches, omitting the covered centre.
The painter caches the mesh until size changes, uses the Flutter image cache,
removes image-stream listeners and disposes image/shader/mesh handles on teardown.
It adds no blur, saveLayer or repaint boundary. Foreground layout, images,
colours, border, corner geometry and actions remain in the existing surface.
The existing `BAYNA_CACHED_CARD_SHADOWS` opt-in remains; ordinary production
defaults retain their original live shadows and package/signing configuration.

The diagnostic HUD labels raster time accurately, removes inherited text
underlines and accepts an explicit build label (`v51`). The Android diagnostic
APK is separately installable as `com.example.arabic_academy.perf51`, with a
development signature, so it does not replace user data in another installation.

Performance contract: preserved. No content, state/storage, PDFs, navigation,
audio, artwork resolution, warm-up or Android refresh-rate policy changes.

## Verification and limits

The new draw-work regression was first run against unmodified v50 rendering:
GitHub Actions run 40137532566 failed on the expected `drawImageNine` operation.
The implementation must then pass that test, visible-pixel comparisons at 1x/3x
for both themes and emphasis modes, existing A/B/list tests, analyzer and all
Flutter regressions. APK publication is gated on those checks.

No physical Android device is connected. The test rasterizer verifies geometry
and appearance, not Android Impeller timing. Device benefit and sustained 120 FPS
remain unverified. Repeat the same dark dialogue list, artwork/card shadows on,
on the same device; collect the existing profile script's UI/raster percentiles,
janky frames and system frame presentation traces. Compare with GPU 50 after
warm-up, as well as the card-shadow-off control. Do not report display Hz as FPS.

Rollback: retain GPU 50 side-by-side, or disable `BAYNA_CACHED_CARD_SHADOWS` to
return to the existing production shadow path. No data migration is involved.
