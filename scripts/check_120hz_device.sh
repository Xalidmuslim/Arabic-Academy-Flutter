#!/usr/bin/env bash
# Check what Android *actually* selected after Bayna requests high refresh.
# The request is advisory; an LTPO screen can vary its mode at runtime.
# No app data is erased and no global Android display setting is modified.
set -euo pipefail
ADB="${ADB:-adb}"
PACKAGE="com.example.arabic_academy"
OUT="${REPORT_DIR:-build/performance/v31-refresh}"
mkdir -p "$OUT"

if ! "$ADB" get-state >/dev/null 2>&1; then
  echo "No connected Android phone / emulator; 120 Hz not measured." >&2
  exit 2
fi

"$ADB" shell getprop ro.product.model | tr -d '\r' > "$OUT/device_model.txt"
"$ADB" shell dumpsys display > "$OUT/display_modes.txt"
"$ADB" shell dumpsys gfxinfo "$PACKAGE" framestats > "$OUT/frame_timings.txt"
"$ADB" shell dumpsys meminfo "$PACKAGE" > "$OUT/memory.txt"
"$ADB" logcat -d -s BaynaRefreshRate:I BaynaPerf:I > "$OUT/bayna_refresh_log.txt"

echo "Device: $(cat "$OUT/device_model.txt")"
echo "User Android refresh preference (may be restricted by OEM or power saver):"
for setting in peak_refresh_rate min_refresh_rate; do
  value=$("$ADB" shell settings get system "$setting" 2>/dev/null | tr -d '\r' || true)
  echo "  $setting: ${value:-unavailable}"
done
echo "Bayna native refresh requests:"
grep -E 'requestedHz=|powerSave=' "$OUT/bayna_refresh_log.txt" || true
echo "Flutter frame timings when the opt-in performance probe is enabled:"
grep -E 'ui_p95_ms=|raster_p95_ms=|first_flutter_raster_ms=' \
  "$OUT/bayna_refresh_log.txt" || true
echo "Active/supported display modes reported by Android:"
grep -E 'refreshRate|DisplayMode|supportedModes|activeMode|mActiveMode' \
  "$OUT/display_modes.txt" | head -55 || true
echo "Reports saved under $OUT"
echo "A requested 120 Hz mode alone does NOT establish 120 rendered FPS."
echo "To verify sustained 120 FPS, interact with the app on a physical 120 Hz"
echo "screen and measure Flutter UI/raster frame timing against 8.33 ms."
