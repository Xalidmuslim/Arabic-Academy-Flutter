#!/usr/bin/env bash
# Five cold + five warm launches, 20 navigation cycles, Flutter raster/UI
# profile markers and Android graphics/memory snapshots on a connected device.
# IMPORTANT: no pm clear, uninstall or backup deletion.
# Baseline: REPORT_DIR=build/perf/v29 bash scripts/profile_android_performance.sh
# Candidate: REPORT_DIR=build/perf/v30 bash scripts/profile_android_performance.sh
set -euo pipefail

ADB="${ADB:-adb}"
PACKAGE="com.example.arabic_academy"
ACTIVITY="$PACKAGE/.MainActivity"
REPORT_DIR="${REPORT_DIR:-build/performance}"
mkdir -p "$REPORT_DIR"
COLD="$REPORT_DIR/cold_start_ms.txt"
WARM="$REPORT_DIR/warm_start_ms.txt"
: > "$COLD"
: > "$WARM"

"$ADB" get-state >/dev/null || {
  echo "ERROR: no connected Android device/emulator. No measurements taken." >&2
  exit 2
}

MODEL=$("$ADB" shell getprop ro.product.model | tr -d '\r')
VERSION=$("$ADB" shell getprop ro.build.version.release | tr -d '\r')
EMULATOR=$("$ADB" shell getprop ro.kernel.qemu | tr -d '\r')
KIND="physical Android device"
if [[ "$EMULATOR" == "1" ]]; then KIND="Android emulator"; fi
printf 'Device: %s | Android: %s | Type: %s\n' "$MODEL" "$VERSION" "$KIND" |
  tee "$REPORT_DIR/device.txt"

time_launch() {
  local result_file="$1"
  local output
  output=$("$ADB" shell am start -W -n "$ACTIVITY")
  printf '%s\n' "$output" > "$result_file"
  local elapsed
  elapsed=$(printf '%s\n' "$output" |
    sed -n 's/.*TotalTime: *\([0-9][0-9]*\).*/\1/p' | tail -1)
  if [[ -z "$elapsed" ]]; then
    echo "No TotalTime reported by Android, see $result_file" >&2
  else
    printf '%s\n' "$elapsed"
  fi
}

report_samples() {
  local label="$1"
  local file="$2"
  if [[ -s "$file" ]]; then
    sort -n "$file" | awk -v label="$label" '
      {times[NR]=$1; sum+=$1}
      END {
        n=NR
        p50=int((n-1)*0.50+0.5)+1
        p95=int((n-1)*0.95+0.5)+1
        printf "%s (%d): avg %.0f ms, p50 %d ms, p95 %d ms, min %d ms, max %d ms\n",
          label,n,sum/n,times[p50],times[p95],times[1],times[n]
      }'
  fi
}

echo "Cold launches (force-stop process; preserve app data):"
for i in 1 2 3 4 5; do
  "$ADB" shell am force-stop "$PACKAGE"
  sleep 1
  duration=$(time_launch "$REPORT_DIR/cold_$i.txt")
  if [[ -n "$duration" ]]; then printf '%s\n' "$duration" >> "$COLD"; fi
  echo "  $i: ${duration:-unavailable} ms"
done

echo "Warm launches (home/background; process remains alive):"
for i in 1 2 3 4 5; do
  "$ADB" shell input keyevent KEYCODE_HOME
  sleep 1
  duration=$(time_launch "$REPORT_DIR/warm_$i.txt")
  if [[ -n "$duration" ]]; then printf '%s\n' "$duration" >> "$WARM"; fi
  echo "  $i: ${duration:-unavailable} ms"
done
report_samples "Cold" "$COLD" | tee "$REPORT_DIR/launch_summary.txt"
report_samples "Warm" "$WARM" | tee -a "$REPORT_DIR/launch_summary.txt"

"$ADB" shell dumpsys meminfo "$PACKAGE" > "$REPORT_DIR/memory_before.txt"
"$ADB" shell dumpsys gfxinfo "$PACKAGE" reset > /dev/null
"$ADB" logcat -c || true

if [[ -t 0 ]]; then
  echo "Perform 20 FULL cycles on the device:"
  echo "Home > Units > Lesson > Dialogue > Exercise > Back > Home,"
  echo "then PDF > page changes > pinch zoom > Back; dictionary and settings."
  echo "Keep the same sequence and times for v29 and v30."
  echo "Press Enter only after finishing all 20 cycles."
  read -r
else
  echo "WARNING: no interactive console. 20-cycle navigation NOT measured."
fi

"$ADB" shell dumpsys gfxinfo "$PACKAGE" > "$REPORT_DIR/gfxinfo.txt"
"$ADB" shell dumpsys gfxinfo "$PACKAGE" framestats > "$REPORT_DIR/framestats.txt"
"$ADB" shell dumpsys meminfo "$PACKAGE" > "$REPORT_DIR/memory_after.txt"
"$ADB" logcat -d > "$REPORT_DIR/logcat.txt"
grep -E 'BaynaPerf|first_flutter_raster_ms|ui_p95_ms|raster_p95_ms' \
  "$REPORT_DIR/logcat.txt" > "$REPORT_DIR/flutter_frame_timings.txt" || true
grep -E 'Total frames rendered:|Janky frames:|50th percentile:|95th percentile:' \
  "$REPORT_DIR/gfxinfo.txt" || true

echo "Reports are in $REPORT_DIR"
echo "Android am start -W reports OS activity start, not Flutter raster time."
echo "For UI/raster p50/p95 use an APK built with:"
echo "  --dart-define=BAYNA_PERF_DIAGNOSTICS=true (profile or release)."
echo "Do not claim 60/120 FPS or memory improvements without measurements."
