import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from scripts import verify_native_config


ROOT = Path(__file__).resolve().parents[2]


class BuildHelpersTests(unittest.TestCase):
    def test_android_sdk_manager_does_not_require_sdk_in_path(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            sdk = root / 'sdk'
            manager = sdk / 'cmdline-tools/latest/bin/sdkmanager'
            javac = root / 'jdk/bin/javac'
            manager.parent.mkdir(parents=True)
            javac.parent.mkdir(parents=True)
            calls = root / 'calls.txt'
            manager.write_text('#!/bin/bash\nprintf "%s\\n" "$*" >> "$BAYNA_TEST_CALLS"\nif [[ "$*" == *--licenses* ]]; then head -n 1 >/dev/null; fi\n')
            javac.write_text('#!/bin/bash\nprintf "javac 17\\n"\n')
            manager.chmod(0o755)
            javac.chmod(0o755)
            env = {**os.environ, 'PATH': '/usr/bin:/bin', 'ANDROID_HOME': str(sdk),
                   'JAVA_HOME': str(root / 'jdk'), 'BAYNA_TEST_CALLS': str(calls)}
            result = subprocess.run(['bash', str(ROOT / 'scripts/prepare_android_ci.sh')],
                                    env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('--licenses', calls.read_text())
            self.assertIn('platforms;android-36', calls.read_text())

    def test_workflow_has_all_gates_and_immutable_action_pins(self):
        import re
        workflow = (ROOT / '.github/workflows/flutter-android.yml').read_text()
        for gate in ['flutter analyze --no-pub', 'flutter test --no-pub',
                     'python3 scripts/verify_assets.py', '-m unittest discover',
                     'scripts/test_backend.sh', 'scripts/test_catalog_sql.py', 'deno check --frozen', 'deno test --frozen',
                     'flutter build apk --debug', '--split-per-abi', 'flutter build appbundle',
                     'flutter build ios --release --no-codesign', 'flutter pub get --enforce-lockfile']:
            self.assertIn(gate, workflow)
        self.assertIn("FLUTTER_VERSION: '3.35.7'", workflow)
        self.assertIn("java-version: '17'", workflow)
        self.assertIn('branches: [codex/bayna-platform, codex/bayna-matte-3d-depth-v1, codex/bayna-matte-3d-depth-v2, codex/bayna-solid-3d-floating-v3, codex/bayna-solid-3d-v4]', workflow)
        self.assertIn('branches: [main]', workflow)
        self.assertNotIn('flutter create', workflow)
        self.assertNotIn('continue-on-error', workflow)
        self.assertNotIn('--no-test-assets', workflow)
        for action in re.findall(r'uses:\s*(\S+)', workflow):
            self.assertRegex(action, r'^[\w./-]+@[0-9a-f]{40}$')
        for name in ['import_reference_art.py', 'import_modern_assets.py',
                     'restore_original_artwork.py', 'refresh_launcher_icons.py']:
            self.assertFalse((ROOT / 'scripts' / name).exists())

    def test_native_validator_detects_pods_and_gradle_checksum_mismatches(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ['android/app/build.gradle.kts', 'android/app/src/main/AndroidManifest.xml',
                         'android/gradle/wrapper/gradle-wrapper.properties', 'ios/Podfile',
                         'ios/Runner.xcodeproj/project.pbxproj', 'ios/Runner/Info.plist',
                         'ios/Flutter/AppFrameworkInfo.plist', 'ios/Flutter/Debug.xcconfig', 'ios/Flutter/Release.xcconfig']:
                target = root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy(ROOT / name, target)
            for name, variant in [('Debug', 'debug'), ('Release', 'release')]:
                (root / f'ios/Flutter/{name}.xcconfig').write_text(
                    f'#include? "../Pods/Target Support Files/Pods-Runner/Pods-Runner.{variant}.xcconfig"\n#include "Generated.xcconfig"\n')
            verify_native_config.validate(root)
            (root / 'ios/Flutter/Debug.xcconfig').write_text('#include "Generated.xcconfig"')
            with self.assertRaises(ValueError):
                verify_native_config.validate(root)
            (root / 'android/gradle/wrapper/gradle-wrapper.properties').write_text('distributionUrl=unverified')
            with self.assertRaises(ValueError):
                verify_native_config.validate(root)

    @unittest.skipUnless(shutil.which('keytool'), 'JDK keytool is required for signing fixture')
    def test_signing_is_repeatable_ignored_and_preserves_owner_properties(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'android').mkdir()
            (root / '.gitignore').write_text('build/\nandroid/key.properties\n*.keystore\n')
            subprocess.run(['git', 'init', '-q', str(root)], check=True)
            owner = root / 'android/key.properties'
            owner.write_text('storePassword=owner-secret-preserve\n')
            command = ['bash', str(ROOT / 'scripts/prepare_signing.sh'), '--repo', str(root)]
            first = subprocess.run(command, check=True, capture_output=True, text=True)
            key = root / 'build/signing/debug.keystore'
            digest = hashlib.sha256(key.read_bytes()).hexdigest()
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(digest, hashlib.sha256(key.read_bytes()).hexdigest())
            self.assertEqual(owner.read_text(), 'storePassword=owner-secret-preserve\n')
            self.assertNotIn('owner-secret', first.stdout + first.stderr)
            self.assertRegex((root / 'build/signing/certificate.sha256').read_text().strip(), r'^[0-9a-f]{64}$')
            self.assertEqual((root / 'build/signing/mode.txt').read_text().strip(), 'development')


if __name__ == '__main__':
    unittest.main()
