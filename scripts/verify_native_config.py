#!/usr/bin/env python3
"""Check tracked native prerequisites without regenerating platform folders."""
import argparse
from pathlib import Path
import plistlib
import re


def validate(root):
    root = Path(root)
    required = ["android/app/build.gradle.kts", "android/app/src/main/AndroidManifest.xml",
                "android/gradle/wrapper/gradle-wrapper.properties", "ios/Podfile",
                "ios/Runner.xcodeproj/project.pbxproj", "ios/Runner/Info.plist"]
    if any(not (root / name).is_file() for name in required):
        raise ValueError("Tracked Android/iOS folders are required; CI must not run flutter create")
    wrapper = (root / required[2]).read_text()
    if "gradle-8.12-bin.zip" not in wrapper or not re.search(
            r"^distributionSha256Sum=7a00d51fb93147819aab76024feece20b6b84e420694101f276be952e08bef03$", wrapper, re.M):
        raise ValueError("Gradle must use the official SHA-256-pinned 8.12 bin distribution")
    podfile = (root / "ios/Podfile").read_text()
    if not re.search(r"platform\s*:ios,\s*['\"]15\.0['\"]", podfile):
        raise ValueError("iOS Podfile must declare deployment target 15.0")
    targets = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET\s*=\s*([\d.]+)", (root / "ios/Runner.xcodeproj/project.pbxproj").read_text())
    if not targets or any(float(value) < 15 for value in targets):
        raise ValueError("All Runner build configurations must target iOS 15 or newer")
    for name, variant in [("Debug", "debug"), ("Release", "release")]:
        config = (root / f"ios/Flutter/{name}.xcconfig").read_text()
        if "Generated.xcconfig" not in config or f"Pods-Runner.{variant}.xcconfig" not in config:
            raise ValueError(f"ios/Flutter/{name}.xcconfig must include both Flutter Generated and CocoaPods {variant} configuration")
    with (root / "ios/Flutter/AppFrameworkInfo.plist").open("rb") as file:
        framework = plistlib.load(file)
    if float(framework.get("MinimumOSVersion", "999")) > min(map(float, targets)):
        raise ValueError("Flutter framework minimum OS exceeds Runner deployment target")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        validate(args.root)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Native configuration failed: {exc}\n")
    print("Native configuration verified: Android/Gradle 8.12 bin and iOS 15/CocoaPods includes")


if __name__ == "__main__":
    main()
