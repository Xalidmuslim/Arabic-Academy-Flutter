#!/usr/bin/env python3
"""Verify packaged assets, ABI splits, and cryptographic Android signatures."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

if __package__:
    from .verify_assets import FONT_LICENSES, ValidationError, validate_assets
else:
    from verify_assets import FONT_LICENSES, ValidationError, validate_assets


ABIS = {"armeabi-v7a", "arm64-v8a", "x86_64"}


def verify_package(root, artifact, abi=None):
    root, artifact = Path(root), Path(artifact)
    validate_assets(root)
    is_bundle = artifact.suffix == ".aab"
    prefix = "base/assets/flutter_assets/" if is_bundle else "assets/flutter_assets/"
    with zipfile.ZipFile(artifact) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)) or archive.testzip() is not None:
            raise ValidationError("Duplicate/corrupt archive entries")
        if any("/assets/images/" in name or "/assets/_embedded/" in name for name in names):
            raise ValidationError("Legacy artwork is packaged in Android artifact")
        manifest = json.loads((root / "assets/artwork/manifest.json").read_text())
        files = {entry["file"]: entry["sha256"] for entry in manifest}
        files.update({entry["file"]: entry["sha256"] for entry in FONT_LICENSES.values()})
        files["assets/artwork/manifest.json"] = hashlib.sha256((root / "assets/artwork/manifest.json").read_bytes()).hexdigest()
        files.update({path.relative_to(root).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest()
                      for path in (root / "assets/content").glob("*.json")})
        for name, digest in files.items():
            packaged = prefix + name
            if packaged not in names or hashlib.sha256(archive.read(packaged)).hexdigest() != digest:
                raise ValidationError(f"Packaged file missing or differs from verified source: {name}")
        native_prefix = "base/lib/" if is_bundle else "lib/"
        found_abis = {name.split("/")[len(native_prefix.split("/")) - 1] for name in names
                      if name.startswith(native_prefix) and name.endswith(".so")}
        if is_bundle and found_abis != ABIS:
            raise ValidationError("AAB must contain all three Android release ABIs")
        if abi and found_abis != {abi}:
            raise ValidationError("APK does not match its declared ABI split")
        if is_bundle and not any(name.startswith("META-INF/") and name.endswith((".RSA", ".DSA", ".EC")) for name in names):
            raise ValidationError("AAB has no signing certificate entry")


def verify_signature(artifact, mode, apksigner=None, certificate_sha256=None):
    artifact = Path(artifact)
    if artifact.suffix == ".apk":
        if not apksigner:
            raise ValidationError("apksigner from Android build-tools 36.0.0 is required")
        command = [str(apksigner), "verify", "--verbose", "--print-certs", str(artifact)]
    else:
        command = ["jarsigner", "-J-Duser.language=en", "-verify", "-verbose", "-certs", str(artifact)]
    result = subprocess.run(command, capture_output=True, text=True, env={**os.environ, "LC_ALL": "C"})
    if result.returncode != 0 or (artifact.suffix == ".aab" and "jar verified." not in result.stdout.lower()):
        raise ValidationError("Android signature verification failed")
    if artifact.suffix == ".aab":
        result = subprocess.run(["keytool", "-J-Duser.language=en", "-printcert", "-jarfile", str(artifact)], capture_output=True, text=True)
        fingerprints = re.findall(r"SHA256:\s*([0-9A-F:]+)", result.stdout)
    else:
        fingerprints = re.findall(r"certificate SHA-256 digest:\s*([0-9a-fA-F]+)", result.stdout)
    if not certificate_sha256 or not re.fullmatch(r"[0-9a-f]{64}", certificate_sha256) or not fingerprints or \
            any(value.replace(":", "").lower() != certificate_sha256 for value in fingerprints):
        raise ValidationError("Android signing certificate differs from the explicitly selected keystore")
    if mode == "development":
        if "CN=Android Debug" not in result.stdout:
            raise ValidationError("Development artifact was not signed with the declared Android Debug identity")
    elif "CN=Android Debug" in result.stdout:
        raise ValidationError("Owner signing mode unexpectedly used the public development identity")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--mode", choices=["development", "owner"], default="development")
    parser.add_argument("--split-apks", action="store_true")
    parser.add_argument("--apksigner", type=Path)
    parser.add_argument("--certificate-sha256", required=True, help="Public SHA-256 fingerprint from the selected keystore")
    parser.add_argument("artifacts", type=Path, nargs="+")
    args = parser.parse_args()
    try:
        expected = {f"app-{abi}-release.apk": abi for abi in ABIS}
        if args.split_apks and {path.name for path in args.artifacts if path.suffix == ".apk"} != set(expected):
            raise ValidationError("Supply exactly the three Flutter release ABI APKs")
        for artifact in args.artifacts:
            if artifact.suffix not in {".apk", ".aab"}:
                raise ValidationError("Only APK/AAB files can be verified")
            verify_package(args.root, artifact, expected.get(artifact.name) if args.split_apks else None)
            verify_signature(artifact, args.mode, args.apksigner, args.certificate_sha256)
    except (ValidationError, OSError, zipfile.BadZipFile) as exc:
        parser.exit(1, f"Android artifact validation failed: {exc}\n")
    print(f"Verified {len(args.artifacts)} Android artifacts; signing mode: {args.mode}")


if __name__ == "__main__":
    main()
