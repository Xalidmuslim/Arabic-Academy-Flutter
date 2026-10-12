# Development and CI

The shared branch is `codex/bayna-platform`. The repository's existing Android
and iOS folders are the source of truth. Do not run `flutter create .` in setup or
CI; it would overwrite maintained platform configuration. No asset restoration,
reference-image crop, icon regeneration, deployment, or Git commit runs in CI.

## Pinned tools and dependency resolution

- Flutter **3.35.7**, Dart **3.9.2**.
- A **full JDK 17**, including `javac`, `keytool`, and `jarsigner`. A Java runtime
  without `javac` cannot compile Android even if `java -version` succeeds.
- Android platform **36**, build-tools **36.0.0**, NDK **27.0.12077973**.
- Gradle **8.12 bin**, official SHA-256
  `7a00d51fb93147819aab76024feece20b6b84e420694101f276be952e08bef03`.
- Deno **2.9.6** and the committed `supabase/functions/deno.lock`.
- Python 3.12; the repository validators/importer/tests use only its standard library.
- CI iOS: macOS 15, Xcode **16.4**, deployment target **15.0**. Plugin compatibility
  is checked by the actual CocoaPods resolution and unsigned native build.

Commit `pubspec.lock` with the owning change. Always use
`flutter pub get --enforce-lockfile`; do not update dependencies to make a build
pass. CI also verifies that the Dart and Deno locks remain unchanged. If an iOS
`Podfile.lock` exists, CI uses `pod install --deployment`; the initial macOS job
also exports its resolved Podfile.lock for review and subsequent pinning.

## Cloud setup

```bash
bash scripts/setup_cloud.sh
source /workspace/academy-env.sh
flutter pub get --enforce-lockfile
python3 scripts/verify_assets.py
python3 -m unittest discover -s scripts/tests -v
flutter analyze --no-pub
flutter test --no-pub
```

The setup script reuses version-checked cached SDKs. Missing Flutter/Android SDKs
come from
`ghcr.io/cirruslabs/flutter:3.35.7@sha256:d271a49ddd8ce1be6c7954f7eabe0e03766c8a1bf1430f0dce780888a21ed408`.
Missing full JDK 17 comes from
`eclipse-temurin:17-jdk@sha256:5d6042fb8cdc14d614e4e421f52e3211fc5aeadddce44cbf9de8ed37c791f824`.
Only the script's own temporary containers and newly pulled image references are
removed. Removal never uses force, so another container's image is preserved.
Large Docker vfs copies can exhaust a 30 GB overlay: uncached SDK extraction
requires at least 22 GiB free. Reuse valid SDK directories when available.

`--workspace`, `--flutter-sdk`, `--android-sdk`, and `--java-home` can select
existing locations. `--no-install-android` checks installed package versions
without downloading packages or accepting new terms. The default accepts missing
Android licenses noninteractively and installs only the listed build prerequisites.
Emulator system images are optional and are not downloaded by this script.

All XDG, Pub, analyzer, Gradle, and Android preference/cache paths live under the
selected workspace. HOME is retained. The environment also selects the JDK's bin
directory, configures Flutter's JDK, and uses the Kotlin in-process compiler via
`-Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process`.

Java ignores HTTP_PROXY/HTTPS_PROXY by default. Setup parses the authorized HTTP
proxy's hostname/port from `HTTPS_PROXY`, writes public system properties to
`android-proxy.sh`, and sources it from `academy-env.sh`. It uses a workspace copy
of `/etc/ssl/certs/java/cacerts` when available and imports the supplied public
proxy CA when needed. TLS and artifact checksum verification stay enabled.
No credentials or the inherited JAVA_TOOL_OPTIONS value are copied to saved scripts.

Network policy must allow dependency destinations **before** the first uncached
build. Required destinations include `pub.dev`, `storage.googleapis.com`,
`services.gradle.org`, `downloads.gradle.org`, `dl.google.com`,
`repo.maven.apache.org`, `repo1.maven.org`, `jitpack.io`, `github.com`, `ghcr.io`,
Docker registry/auth/blob hosts, and macOS CocoaPods CDN/source hosts. Preserve
existing domain permissions when adding a destination; do not replace an unknown
allowlist. JitPack is required by locked `flutter_webrtc 1.3.0` /
`livekit_client 2.6.4` for
`com.github.davidliu:audioswitch:89582c47c9a04c62f90aa5e57251af4800a62c9a`.
An actual allowlist denial must be resolved in environment settings. Do not edit
package caches, dependencies, expected checksums, proxy routing, or TLS checks to
force a build through it.

`flutter doctor -v` is printed for diagnosis. Chrome/Linux desktop/Android Studio
warnings are optional for this Android/test workflow. Copied SDK Git metadata can
also produce a channel warning despite the verified version. Device discovery on
older ADB binaries can still require a writable Android user directory; a failed
device check does not establish emulator readiness. Android license or network
warnings must be resolved for the affected operation. A doctor exit code alone
is not evidence that an APK, emulator, or iOS app works.

## Android signing and package verification

```bash
bash scripts/prepare_signing.sh --mode development
flutter build apk --debug --no-pub
flutter build apk --release --split-per-abi
flutter build appbundle --release --no-pub
python3 scripts/verify_android_artifacts.py --split-apks \
  --mode development --apksigner "$ANDROID_HOME/build-tools/36.0.0/apksigner" \
  --certificate-sha256 "$(cat build/signing/certificate.sha256)" \
  build/app/outputs/flutter-apk/app-*-release.apk \
  build/app/outputs/bundle/release/app-release.aab
```

`prepare_signing.sh` defaults to development (`BAYNA_SIGNING_MODE=development`):
ignored `build/signing/debug.keystore`, alias `androiddebugkey`, both passwords
`android`, self-signed `CN=Android Debug`. These are public test credentials.
An existing valid development keystore is reused. Existing owner
`android/key.properties` is never replaced or printed. The public selected
certificate fingerprint is written to `build/signing/certificate.sha256`.

Owner mode uses existing ignored owner properties, or creates them only when
absent and these environment names are supplied: `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
The created keystore/properties have restrictive permissions; no signing material
is uploaded as an artifact. For preexisting owner properties outside the helper's
generated keystore path, provide public `ANDROID_SIGNER_SHA256` for verification.
Gradle's `BAYNA_REQUIRE_RELEASE_SIGNING=true` rejects a missing owner configuration.
The CI push release job selects owner mode only if the owner keystore is provided.

The verifier checks ZIP integrity, all three release ABIs, source asset/font/JSON
hashes, absence of legacy artwork, actual APK/AAB signatures, and the expected
certificate fingerprint. Development release artifacts are clearly named as
development builds; they are not production store releases.

## Native iOS and CI outcome

`python3 scripts/verify_native_config.py` checks tracked native files, the Gradle
pin/checksum, iOS 15 targets, and both Flutter/CocoaPods xcconfig includes.
Debug/Release configs must include the matching Pods-Runner debug/release xcconfig
as well as Generated.xcconfig. These tracked files are maintained by the native
integration owner, not regenerated by these scripts.

The workflow runs on PRs to main, pushes to codex/bayna-platform, and manual dispatch.
All pushes/manual release requests must pass quality, backend, Android debug, and
unsigned iOS gates before Android release artifacts are uploaded. Backend tests
use the backend owner's `scripts/test_backend.sh` with a disposable pinned
PostgreSQL 16 Docker image; Edge checks/tests use Deno 2 with frozen dependencies.
`python3 scripts/test_catalog_sql.py` also checks generated catalog SQL against
the real migrations in disposable PostgreSQL, using only a synthetic test
fixture. It verifies permission denial, source locators, original vowels, SQL
quoting, and rollback on duplicate imports.
There are no skipped Flutter checks or disabled failure gates.

iOS runs `flutter build ios --release --no-codesign`; the artifact is a zip of
**unsigned Runner.app**, not a signed IPA. Apple signing, provisioning, physical
device installation, and store delivery are not established by that build.
GitHub Actions execution and branch protection require the repository owner to
publish the working branch/configuration; local script validation is separate
from a completed hosted CI run.

## Flutter 3.35.7 plugin regeneration

The first release APK build after a debug/test command must allow Flutter tooling regeneration: `flutter build apk --release --split-per-abi` (without `--no-pub`). This SDK skips regenerating its Android plugin registrant when `--no-pub` is used, while Gradle correctly excludes dev plugins from release. An old debug registrant can therefore reference `IntegrationTestPlugin`, which is absent from release. Keep the integration-test dependency and all checks; do not patch the generated Java or SDK. Resolve the committed lock beforehand with `flutter pub get --enforce-lockfile`, build sequentially, and check `git diff --exit-code -- pubspec.lock` afterward. A following release AAB may use `--no-pub` because its release registrant is current.

## Supported Apple compiler

Use Xcode 26.3 (present on the macOS 15 hosted image), while keeping the iOS deployment target 15. The locked `connectivity_plus 7.3.1` references `NWPath.isUltraConstrained` inside `#available(iOS 26.0, *)`. That guard preserves older-device support but requires an SDK that defines the symbol; Xcode 16.4 fails at compile time. No dependency cache or plugin source is patched.
