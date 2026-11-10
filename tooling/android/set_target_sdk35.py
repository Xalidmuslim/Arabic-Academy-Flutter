"""Set only Android targetSdk to 35 for Xiaomi HyperOS A/B testing.

No change to compileSdk, Flutter engine, UI, package name, dictionary assets or
minSdk. This is an experiment, not a generic recommended target SDK downgrade.
"""
from pathlib import Path

GRADLE=Path("android/app/build.gradle.kts")
OLD = "targetSdk = flutter.targetSdkVersion"
NEW = "targetSdk = 35"

def patch_gradle(source: str) -> str:
    if source.count(NEW)==1 and OLD not in source:
        return source
    if source.count(OLD)!=1 or NEW in source:
        raise ValueError("Unexpected Android target SDK declaration, refusing unsafe rewrite")
    return source.replace(OLD, NEW, 1)

if __name__=="__main__":
    if not GRADLE.is_file():
        raise SystemExit("Missing generated Android build.gradle.kts")
    old=GRADLE.read_text(encoding="utf-8")
    new=patch_gradle(old)
    GRADLE.write_text(new,encoding="utf-8")
    print("Controlled experiment: targetSdk set to 35; all other Gradle fields unchanged")
