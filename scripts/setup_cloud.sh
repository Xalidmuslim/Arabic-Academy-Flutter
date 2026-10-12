#!/usr/bin/env bash
# Linux cloud bootstrap; HOME and existing owner files are never repurposed.
set -euo pipefail
workspace="${BAYNA_WORKSPACE:-/workspace}"
flutter_sdk=''
android_sdk=''
java_home=''
install_android=true
while (( $# )); do
  case "$1" in
    --workspace) workspace="$2"; shift 2 ;;
    --flutter-sdk) flutter_sdk="$2"; shift 2 ;;
    --android-sdk) android_sdk="$2"; shift 2 ;;
    --java-home) java_home="$2"; shift 2 ;;
    --no-install-android) install_android=false; shift ;;
    *) echo 'Usage: setup_cloud.sh [--workspace DIR] [--flutter-sdk DIR] [--android-sdk DIR] [--java-home DIR] [--no-install-android]' >&2; exit 2 ;;
  esac
done
mkdir -p "$workspace/.toolchains" "$workspace/.config" "$workspace/.cache" \
  "$workspace/.pub-cache" "$workspace/.dartServer" "$workspace/.gradle" "$workspace/.android"
workspace="$(cd "$workspace" && pwd)"
flutter_sdk="${flutter_sdk:-$workspace/.toolchains/flutter}"
android_sdk="${android_sdk:-$workspace/.toolchains/android-sdk}"
image='ghcr.io/cirruslabs/flutter:3.35.7@sha256:d271a49ddd8ce1be6c7954f7eabe0e03766c8a1bf1430f0dce780888a21ed408'
docker_cmd=(env -u DOCKER_HOST -u DOCKER_CONTEXT -u DOCKER_TLS -u DOCKER_TLS_VERIFY -u DOCKER_CERT_PATH docker --host=unix:///var/run/docker.sock)
source_containers=()
pulled_images=()
cleanup() {
  for container in "${source_containers[@]}"; do
    "${docker_cmd[@]}" rm "$container" >/dev/null 2>&1 || true
  done
  for sdk_image in "${pulled_images[@]}"; do
    if [[ -n "$("${docker_cmd[@]}" ps -aq --filter "ancestor=$sdk_image")" ]]; then
      echo 'SDK image retained because another container needs it.' >&2
      continue
    fi
    # No force: Docker retains an image referenced by anyone else's container.
    "${docker_cmd[@]}" image rm "$sdk_image" >/dev/null 2>&1 || echo 'SDK image retained because another Docker reference needs it.' >&2
  done
}
trap cleanup EXIT
if [[ ! -x "$flutter_sdk/bin/flutter" || ! -x "$android_sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
  command -v docker >/dev/null || { echo 'Docker is required for uncached pinned SDK extraction' >&2; exit 1; }
  "${docker_cmd[@]}" info >/dev/null
  python3 - "$workspace" <<'PY'
import shutil, sys
if shutil.disk_usage(sys.argv[1]).free < 22 * 1024**3:
    raise SystemExit('Uncached Docker SDK extraction needs at least 22 GiB free (vfs copies are large); reuse verified cached SDKs or free space first.')
PY
  if ! "${docker_cmd[@]}" image inspect "$image" >/dev/null 2>&1; then
    "${docker_cmd[@]}" pull "$image"
    pulled_images+=("$image")
  fi
  source_container="$("${docker_cmd[@]}" create "$image")"
  source_containers+=("$source_container")
  if [[ ! -x "$flutter_sdk/bin/flutter" ]]; then
    [[ ! -e "$flutter_sdk" ]] || { echo 'Existing incomplete Flutter directory was preserved; choose --flutter-sdk' >&2; exit 1; }
    "${docker_cmd[@]}" cp "$source_container:/sdks/flutter" "$flutter_sdk"
  fi
  if [[ ! -x "$android_sdk/cmdline-tools/latest/bin/sdkmanager" ]]; then
    [[ ! -e "$android_sdk" ]] || { echo 'Existing incomplete Android directory was preserved; choose --android-sdk' >&2; exit 1; }
    image_android="$("${docker_cmd[@]}" image inspect "$image" --format '{{json .Config.Env}}' | python3 -c 'import json,sys; print(next(v.partition("=")[2] for v in json.load(sys.stdin) if v.startswith("ANDROID_HOME=")))')"
    [[ "$image_android" == /* ]] || { echo 'Pinned image lacks an absolute Android SDK path' >&2; exit 1; }
    "${docker_cmd[@]}" cp "$source_container:$image_android" "$android_sdk"
  fi
fi
java_home="${java_home:-$workspace/.toolchains/jdk17}"
if [[ ! -x "$java_home/bin/javac" ]]; then
  [[ ! -e "$java_home" ]] || { echo 'Existing incomplete Java directory was preserved; a full JDK 17 with javac is required' >&2; exit 1; }
  jdk_image='eclipse-temurin:17-jdk@sha256:5d6042fb8cdc14d614e4e421f52e3211fc5aeadddce44cbf9de8ed37c791f824'
  command -v docker >/dev/null || { echo 'Docker or a cached full JDK 17 is required' >&2; exit 1; }
  if ! "${docker_cmd[@]}" image inspect "$jdk_image" >/dev/null 2>&1; then
    "${docker_cmd[@]}" pull "$jdk_image"
    pulled_images+=("$jdk_image")
  fi
  source_container="$("${docker_cmd[@]}" create "$jdk_image")"
  source_containers+=("$source_container")
  "${docker_cmd[@]}" cp "$source_container:/opt/java/openjdk" "$java_home"
fi
export JAVA_HOME="$java_home"
export PATH="$java_home/bin:$PATH"
[[ -x "$java_home/bin/java" && -x "$java_home/bin/keytool" && -x "$java_home/bin/javac" ]] || { echo 'A full JDK 17, not a JRE, is required' >&2; exit 1; }
java_version="$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)"
[[ "$java_version" == 17 ]] || { echo 'JDK 17 is required' >&2; exit 1; }
javac -version
truststore="$workspace/.config/bayna-java-cacerts"
if [[ -f /etc/ssl/certs/java/cacerts ]]; then
  cp /etc/ssl/certs/java/cacerts "$truststore"
else
  cp "$java_home/lib/security/cacerts" "$truststore"
fi
if [[ -n "${CODEX_PROXY_CERT:-}" && -f "${CODEX_PROXY_CERT:-}" ]]; then
  keytool -delete -alias bayna-session-proxy -keystore "$truststore" -storepass changeit >/dev/null 2>&1 || true
  keytool -importcert -noprompt -trustcacerts -alias bayna-session-proxy \
    -file "$CODEX_PROXY_CERT" -keystore "$truststore" -storepass changeit >/dev/null 2>&1
fi
cp /etc/ssl/certs/ca-certificates.crt "$workspace/.config/bayna-ca.pem"
python3 - "$workspace" "$flutter_sdk" "$android_sdk" "$java_home" "$truststore" <<'PY'
import os
from pathlib import Path
import shlex
import sys
from urllib.parse import urlsplit

workspace, flutter, android, java, truststore = sys.argv[1:]
proxy = os.environ.get('HTTPS_PROXY') or os.environ.get('HTTP_PROXY')
flags = ['-Djavax.net.ssl.trustStore=' + truststore, '-Djavax.net.ssl.trustStorePassword=changeit']
if proxy:
    url = urlsplit(proxy)
    if url.scheme != 'http' or not url.hostname or url.port is None or url.username or url.password:
        raise SystemExit('Java proxy needs an explicit HTTP proxy host/port in HTTPS_PROXY; TLS verification remains enabled.')
    flags += ['-Dhttps.proxyHost=' + url.hostname, '-Dhttps.proxyPort=' + str(url.port),
              '-Dhttp.proxyHost=' + url.hostname, '-Dhttp.proxyPort=' + str(url.port)]
    flags += ['-Dhttp.nonProxyHosts=localhost|127.*|[::1]']
proxy_script = Path(workspace) / 'android-proxy.sh'
# Persist only proxy hostname/port and public trust paths, never credentials or
# the inherited JAVA_TOOL_OPTIONS contents. Preserve those options when sourcing.
proxy_script.write_text('export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} "' +
                        shlex.quote(' '.join(flags)) + '\n', encoding='utf-8')
values = {'XDG_CONFIG_HOME': workspace + '/.config', 'XDG_CACHE_HOME': workspace + '/.cache',
          'PUB_CACHE': workspace + '/.pub-cache', 'ANALYZER_STATE_LOCATION_OVERRIDE': workspace + '/.dartServer',
          'GRADLE_USER_HOME': workspace + '/.gradle', 'ANDROID_USER_HOME': workspace + '/.android',
          'ANDROID_SDK_HOME': workspace, 'ANDROID_PREFS_ROOT': workspace,
          'ANDROID_HOME': android, 'ANDROID_SDK_ROOT': android, 'JAVA_HOME': java,
          'SSL_CERT_FILE': workspace + '/.config/bayna-ca.pem', 'CI': 'true',
          'FLUTTER_SUPPRESS_ANALYTICS': 'true', 'DART_SUPPRESS_ANALYTICS': 'true'}
lines = ['export PATH=' + shlex.quote(java + '/bin:' + flutter + '/bin:' + android + '/platform-tools:') + '"$PATH"']
lines += ['export ' + key + '=' + shlex.quote(value) for key, value in values.items()]
lines += ['source ' + shlex.quote(str(proxy_script))]
lines += ['export GRADLE_OPTS="${GRADLE_OPTS:-} -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process"']
(Path(workspace) / 'academy-env.sh').write_text('\n'.join(lines) + '\n', encoding='utf-8')
PY
source "$workspace/academy-env.sh"
flutter config --jdk-dir="$java_home"
flutter_version="$(flutter --version --machine | python3 -c 'import json,sys; print(json.load(sys.stdin)["frameworkVersion"])')"
[[ "$flutter_version" == 3.35.7 ]] || { echo 'Cached Flutter must be exactly 3.35.7; existing SDK was preserved' >&2; exit 1; }
sdkmanager="$android_sdk/cmdline-tools/latest/bin/sdkmanager"
required=(platform-tools 'platforms;android-36' 'build-tools;36.0.0' 'ndk;27.0.12077973')
missing=false
for path in platform-tools platforms/android-36 build-tools/36.0.0 ndk/27.0.12077973; do
  [[ -d "$android_sdk/$path" ]] || missing=true
done
if [[ "$install_android" == true ]]; then
  # Keep inherited licenses and accept any newly required package terms.
  set +o pipefail
  yes | "$sdkmanager" --sdk_root="$android_sdk" --licenses >/dev/null
  statuses=("${PIPESTATUS[@]}")
  set -o pipefail
  [[ "${statuses[1]}" == 0 ]] || { echo 'Android license acceptance failed' >&2; exit 1; }
fi
if [[ "$missing" == true ]]; then
  [[ "$install_android" == true ]] || { echo 'Android SDK 36, build-tools 36.0.0 and NDK 27.0.12077973 are required; rerun without --no-install-android using the approved Java proxy.' >&2; exit 1; }
  # sdkmanager inherits Java proxy and the trusted CA store above. The image's
  # accepted licenses remain; yes supplies only missing license prompts.
  "$sdkmanager" --sdk_root="$android_sdk" "${required[@]}"
fi
python3 - "$android_sdk" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
for relative, field, expected in [('platforms/android-36', 'AndroidVersion.ApiLevel', '36'),
                                  ('build-tools/36.0.0', 'Pkg.Revision', '36.0.0'),
                                  ('ndk/27.0.12077973', 'Pkg.Revision', '27.0.12077973')]:
    properties = {}
    for line in (root / relative / 'source.properties').read_text().splitlines():
        if '=' in line:
            key, value = line.split('=', 1)
            properties[key.strip()] = value.strip()
    if properties.get(field) != expected:
        raise SystemExit('Installed Android package version mismatch: ' + relative)
PY
flutter doctor -v
printf 'Verified Flutter 3.35.7, full JDK %s and Android package versions. Review doctor warnings separately. Source %s/academy-env.sh.\n' "$java_version" "$workspace"
