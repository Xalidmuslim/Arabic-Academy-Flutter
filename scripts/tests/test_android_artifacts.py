from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest import mock
import zipfile

from scripts import verify_android_artifacts


ROOT = Path(__file__).resolve().parents[2]


class ArtifactTests(unittest.TestCase):
    def package(self, path, *, extra=None, corrupt=False, bundle=False):
        prefix = 'base/assets/flutter_assets/' if bundle else 'assets/flutter_assets/'
        with zipfile.ZipFile(path, 'w') as archive:
            for folder in ['artwork', 'content', 'fonts']:
                for source in (ROOT / 'assets' / folder).iterdir():
                    if source.suffix in {'.webp', '.json', '.ttf'}:
                        archive.writestr(prefix + source.relative_to(ROOT).as_posix(),
                            b'wrong' if corrupt and source.name == 'hero.webp' else source.read_bytes())
            for abi in verify_android_artifacts.ABIS if bundle else ['arm64-v8a']:
                archive.writestr(('base/lib/' if bundle else 'lib/') + abi + '/libflutter.so', b'fixture')
            if bundle:
                archive.writestr('META-INF/FIXTURE.RSA', b'fixture certificate presence only')
            if extra:
                archive.writestr(extra, b'forbidden')

    def test_verified_asset_bytes_and_abi_in_apk_and_aab(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / 'app.apk'
            self.package(apk)
            verify_android_artifacts.verify_package(ROOT, apk, 'arm64-v8a')
            with self.assertRaises(verify_android_artifacts.ValidationError):
                verify_android_artifacts.verify_package(ROOT, apk, 'x86_64')
            bundle = Path(directory) / 'app.aab'
            self.package(bundle, bundle=True)
            verify_android_artifacts.verify_package(ROOT, bundle)

    def test_legacy_or_corrupted_packaged_assets_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / 'app.apk'
            for kwargs in [{'extra': 'assets/flutter_assets/assets/images/old.webp'}, {'corrupt': True}]:
                self.package(apk, **kwargs)
                with self.assertRaises(verify_android_artifacts.ValidationError):
                    verify_android_artifacts.verify_package(ROOT, apk)

    def test_signature_must_match_the_selected_public_fingerprint(self):
        fingerprint = 'ab' * 32
        result = SimpleNamespace(returncode=0, stdout='Signer #1 certificate DN: CN=Android Debug\n'
                                  'Signer #1 certificate SHA-256 digest: ' + fingerprint)
        with mock.patch('subprocess.run', return_value=result):
            verify_android_artifacts.verify_signature('app.apk', 'development', '/apksigner', fingerprint)
            for mode, expected in [('owner', fingerprint), ('development', 'cd' * 32)]:
                with self.assertRaises(verify_android_artifacts.ValidationError):
                    verify_android_artifacts.verify_signature('app.apk', mode, '/apksigner', expected)

    def test_unsigned_bundle_is_rejected_even_when_jarsigner_exits_zero(self):
        with mock.patch('subprocess.run', return_value=SimpleNamespace(returncode=0, stdout='jar is unsigned.')):
            with self.assertRaises(verify_android_artifacts.ValidationError):
                verify_android_artifacts.verify_signature('app.aab', 'development', certificate_sha256='ab' * 32)


if __name__ == '__main__':
    unittest.main()
