#!/usr/bin/env bash
# Called as one script: the emulator action otherwise executes YAML lines
# separately and discards the shell state.
set -euo pipefail
mkdir -p smoke-output

adb install -r downloaded-apk/app-x86_64-release.apk
adb shell am start -W -n com.example.arabic_academy/.MainActivity
sleep 12

capture_diagnostics() {
  adb shell screencap -p /sdcard/bayna-launch.png || true
  adb pull /sdcard/bayna-launch.png smoke-output/launch.png >/dev/null || true
  adb logcat -d -v time > smoke-output/logcat.txt || true
}

# Pixel Launcher can ANR immediately after a cold boot on Google's emulator.
# That is a different OS process, not an app crash. Dismiss only that explicit
# system dialog, then reassert our app as the foreground activity.
for attempt in 1 2 3 4 5 6 7 8; do
  if ! adb shell pidof com.example.arabic_academy >/dev/null; then
    echo 'App process terminated during smoke test'
    capture_diagnostics
    exit 1
  fi

  adb shell uiautomator dump /sdcard/bayna-ui.xml >/dev/null || true
  adb pull /sdcard/bayna-ui.xml smoke-output/window.xml >/dev/null || true

  if grep -Eq 'Pixel Launcher isn.t responding|com.google.android.apps.nexuslauncher.*not responding' smoke-output/window.xml 2>/dev/null &&
     grep -q 'android:id/aerr_close' smoke-output/window.xml; then
    echo 'Dismissing ANR in Android system launcher (not the tested app)'
    # This emulator uses a fixed 1080x2400 screen; the system ANR dialog's
    # Close-app button spans x=70..1010, y=1170..1296 on API 35.
    adb shell input tap 540 1230
    sleep 3
    adb shell am start -W -n com.example.arabic_academy/.MainActivity
    sleep 3
    continue
  fi

  if grep -Eq 'Начать обучение|Арабский каждый день|Арабский язык в твоих руках' smoke-output/window.xml 2>/dev/null; then
    echo 'Flutter learning content visible in Android UI hierarchy'
    capture_diagnostics
    if grep -E 'FATAL EXCEPTION.*com.example.arabic_academy|E/flutter.*Unhandled Exception' smoke-output/logcat.txt; then
      echo 'Fatal app error during launch'
      exit 1
    fi
    exit 0
  fi

  echo "Flutter learning content not visible yet, retry ${attempt}/8"
  sleep 5
done

capture_diagnostics
echo 'App process exists but Flutter learning UI is not exposed; review screenshot and logs'
exit 1
