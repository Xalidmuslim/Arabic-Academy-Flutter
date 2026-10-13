#!/usr/bin/env bash
# Invoked as one script: android-emulator-runner otherwise executes each
# YAML script line in a separate /bin/sh process, breaking compound commands.
set -euo pipefail
mkdir -p smoke-output
adb install -r downloaded-apk/app-x86_64-release.apk
adb shell am start -W -n com.example.arabic_academy/.MainActivity
sleep 15
adb shell pidof com.example.arabic_academy
adb shell screencap -p /sdcard/bayna-launch.png
adb pull /sdcard/bayna-launch.png smoke-output/launch.png
adb logcat -d -v time > smoke-output/logcat.txt
if grep -E 'FATAL EXCEPTION|E/flutter.*Unhandled Exception' smoke-output/logcat.txt; then
  echo 'Android startup emitted a fatal exception'
  exit 1
fi
for attempt in 1 2 3; do
  adb shell uiautomator dump /sdcard/bayna-ui.xml >/dev/null || true
  adb pull /sdcard/bayna-ui.xml smoke-output/window.xml >/dev/null || true
  if grep -Eq 'Начать обучение|Арабский каждый день|Арабский язык в твоих руках' smoke-output/window.xml; then
    echo 'Visible Flutter learning UI confirmed on Android emulator'
    exit 0
  fi
  sleep 5
done
echo 'Expected Flutter content was not exposed by UIAutomator; review screenshot and logs'
exit 1
