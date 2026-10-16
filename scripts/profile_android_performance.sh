#!/usr/bin/env bash
# Profile a REAL Android handset or AVD without clearing user data.
# Example: ANDROID_SERIAL=... bash scripts/profile_android_performance.sh
set -euo pipefail

ADB="${ADB:-adb}"
PACKAGE="com.example.arabic_academy"
ACTIVITY="$PACKAGE/.MainActivity"
REPORT_DIR="${REPORT_DIR:-build/performance}"
mkdir -p "$REPORT_DIR"
TIMES="$REPORT_DIR/cold_start_times_ms.txt"
: > "$TIMES"

"$ADB" get-state >/dev/null || {
  echo "No Android device connected; device measurements not executed." >&2
  exit 2
}

MODEL=$("$ADB" shell getprop ro.product.model | tr -d '\r')
EMULATOR=$("$ADB" shell getprop ro.kernel.qemu | tr -d '\r')
TYPE="physical Android device"
if [[ "$EMULATOR" == "1" ]]; then TYPE="Android emulator"; fi
echo "Device: $MODEL ($TYPE)"
echo "App: $PACKAGE"
echo "Run count: 3 cold launches (process killed; user data preserved)."

for iteration in 1 2 3; do
  "$ADB" shell am force-stop "$PACKAGE"
  sleep 1
  OUTPUT=$("$ADB" shell am start -W -n "$ACTIVITY")
  echo "$OUTPUT" > "$REPORT_DIR/cold_start_$iteration.txt"
  echo "Cold launch $iteration:"
  printf '%s\n' "$OUTPUT" | grep -E 'Status:|LaunchState:|ThisTime:|TotalTime:|WaitTime:' || true
  TIME=$(printf '%s\n' "$OUTPUT" | sed -n 's/.*TotalTime: *\([0-9][0-9]*\).*/\1/p' | tail -1)
  if [[ -z "$TIME" ]]; then
    echo "The device did not provide TotalTime; see the raw result." >&2
  else
    printf '%s\n' "$TIME" >> "$TIMES"
  fi
done

if [[ -s "$TIMES" ]]; then
  awk '{sum+=$1; if(min==0 || $1<min) min=$1; if($1>max) max=$1; n++}
       END {printf "Cold launch: avg %.0f ms, min %d ms, max %d ms (%d runs)\n",
            sum/n,min,max,n}' "$TIMES"
fi

echo "Resetting graphics frame counters now."
"$ADB" shell dumpsys gfxinfo "$PACKAGE" reset > /dev/null
if [[ -t 0 ]]; then
  echo "On the device: scroll the textbook, open/close lesson and PDF fragment,"
  echo "pinch zoom, navigate back, repeat. Press Enter when finished."
  read -r
else
  echo "No interactive console: record frame data only for activity so far."
fi
"$ADB" shell dumpsys gfxinfo "$PACKAGE" > "$REPORT_DIR/gfxinfo.txt"
"$ADB" shell dumpsys gfxinfo "$PACKAGE" framestats > "$REPORT_DIR/framestats.txt"
grep -E 'Total frames rendered:|Janky frames:|50th percentile:|90th percentile:|95th percentile:|99th percentile:'   "$REPORT_DIR/gfxinfo.txt" || true

echo "Raw reports: $REPORT_DIR"
echo "Device results must be compared with the previous release on the SAME"
echo "device, refresh rate, profile and screen sequence before claiming gains."
