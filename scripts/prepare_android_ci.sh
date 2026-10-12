#!/usr/bin/env bash
set -euo pipefail
: "${ANDROID_HOME:?ANDROID_HOME must point to the installed Android SDK}"
: "${JAVA_HOME:?JAVA_HOME must point to a full JDK 17}"
[[ -x "$JAVA_HOME/bin/javac" ]] || { echo 'A JRE cannot compile Android; full JDK 17 javac is required' >&2; exit 1; }
"$JAVA_HOME/bin/javac" -version
set +o pipefail
yes | sdkmanager --licenses >/dev/null
statuses=("${PIPESTATUS[@]}")
set -o pipefail
[[ "${statuses[1]}" == 0 ]] || { echo 'Android license acceptance failed' >&2; exit 1; }
sdkmanager 'platforms;android-36' 'build-tools;36.0.0' 'ndk;27.0.12077973'
