
#!/usr/bin/env python3
"""Configure Memories Android permissions and SDK versions, plus iOS permissions."""
import os
import re
import sys

root = sys.argv[1] if len(sys.argv) > 1 else "."

# ---------- Android manifest ----------
manifest = os.path.join(root, "android/app/src/main/AndroidManifest.xml")
perms = [
    "android.permission.INTERNET",
    "android.permission.ACCESS_FINE_LOCATION",
    "android.permission.ACCESS_COARSE_LOCATION",
    "android.permission.RECORD_AUDIO",
]

if os.path.exists(manifest):
    with open(manifest, encoding="utf-8") as f:
        s = f.read()

    add = "".join(
        f'    <uses-permission android:name="{p}"/>\n'
        for p in perms if p not in s
    )

    if add:
        s = s.replace("<application", add + "<application", 1)
        with open(manifest, "w", encoding="utf-8") as f:
            f.write(s)

    print("Android manifest: OK")
else:
    print("AndroidManifest.xml not found")

# ---------- App SDK versions ----------
for name in ("android/app/build.gradle.kts", "android/app/build.gradle"):
    path = os.path.join(root, name)
    if not os.path.exists(path):
        continue

    with open(path, encoding="utf-8") as f:
        s = f.read()

    s = re.sub(
        r"minSdk\s*=\s*flutter\.minSdkVersion",
        "minSdk = 23",
        s,
    )
    s = re.sub(
        r"minSdkVersion\s+flutter\.minSdkVersion",
        "minSdkVersion 23",
        s,
    )
    s = re.sub(
        r"compileSdk\s*=\s*flutter\.compileSdkVersion",
        "compileSdk = 36",
        s,
    )
    s = re.sub(
        r"compileSdkVersion\s+flutter\.compileSdkVersion",
        "compileSdkVersion 36",
        s,
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(s)

    print(f"{name}: configured")

# Do not add afterEvaluate hooks to the root Gradle file.
# The app module uses compileSdk 36 directly.

# ---------- iOS permissions ----------
plist = os.path.join(root, "ios/Runner/Info.plist")
keys = {
    "NSLocationWhenInUseUsageDescription":
        "Memories uses your location to place a memory on the map.",
    "NSPhotoLibraryUsageDescription":
        "Memories needs your photo library to add photos and videos to a memory.",
    "NSCameraUsageDescription":
        "Memories can use the camera to capture photos for a memory.",
    "NSMicrophoneUsageDescription":
        "Memories uses the microphone to record voice notes.",
}

if os.path.exists(plist):
    with open(plist, encoding="utf-8") as f:
        s = f.read()

    add = "".join(
        f"\t<key>{k}</key>\n\t<string>{v}</string>\n"
        for k, v in keys.items() if f"<key>{k}</key>" not in s
    )

    if add:
        idx = s.rfind("</dict>")
        if idx != -1:
            s = s[:idx] + add + s[idx:]
            with open(plist, "w", encoding="utf-8") as f:
                f.write(s)

    print("iOS Info.plist: OK")
else:
    print("iOS folder not found; skipped")


# ---------- Patch cached Flutter plugins to compile against SDK 36 ----------
import glob

cache_roots = [
    os.path.expanduser("~/.pub-cache/hosted/pub.dev"),
    "/root/.pub-cache/hosted/pub.dev",
]

patched = []

for cache_root in cache_roots:
    if not os.path.isdir(cache_root):
        continue

    for pattern in ("*/android/build.gradle", "*/android/build.gradle.kts"):
        for gradle_file in glob.glob(os.path.join(cache_root, pattern)):
            with open(gradle_file, encoding="utf-8") as f:
                content = f.read()

            updated = re.sub(
                r"(\bcompileSdk\s*=\s*)flutter\.compileSdkVersion",
                r"\g<1>36",
                content,
            )
            updated = re.sub(
                r"(\bcompileSdkVersion\s+)flutter\.compileSdkVersion",
                r"\g<1>36",
                updated,
            )
            updated = re.sub(r"\bcompileSdk\s+34\b", "compileSdk 36", updated)
            updated = re.sub(
                r"\bcompileSdkVersion\s+34\b",
                "compileSdkVersion 36",
                updated,
            )

            if updated != content:
                with open(gradle_file, "w", encoding="utf-8") as f:
                    f.write(updated)
                patched.append(gradle_file)

print("Flutter plugin SDK patch complete.")
print("Patched files:", ", ".join(patched) if patched else "None found")