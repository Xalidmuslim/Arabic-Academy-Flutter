#!/usr/bin/env bash
set -euo pipefail
: "${ANDROID_HOME:?ANDROID_HOME must point to the installed Android SDK}"
: "${JAVA_HOME:?JAVA_HOME must point to a full JDK 17}"
[[ -x "$JAVA_HOME/bin/javac" ]] || { echo 'A JRE cannot compile Android; full JDK 17 javac is required' >&2; exit 1; }
"$JAVA_HOME/bin/javac" -version
sdk_manager="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"
[[ -x "$sdk_manager" ]] || { echo 'Android command-line SDK manager is missing from ANDROID_HOME' >&2; exit 1; }
set +o pipefail
yes | "$sdk_manager" --sdk_root="$ANDROID_HOME" --licenses >/dev/null
statuses=("${PIPESTATUS[@]}")
set -o pipefail
[[ "${statuses[1]}" == 0 ]] || { echo 'Android license acceptance failed' >&2; exit 1; }
"$sdk_manager" --sdk_root="$ANDROID_HOME" 'platforms;android-36' 'build-tools;36.0.0' 'ndk;27.0.12077973'
