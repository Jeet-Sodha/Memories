#!/usr/bin/env python3
"""Branding for the generated Flutter project:
  * app name  -> "Memories"   (Android label + iOS display name)
  * registers the assets/ folder in pubspec.yaml
  * writes flutter_launcher_icons.yaml (the logo -> app icon)
Run from the project root. Safe to run many times."""
import os, re, sys

root = sys.argv[1] if len(sys.argv) > 1 else "."
APP_NAME = "Memories"

# ---------- Android: name shown under the icon ----------
manifest = os.path.join(root, "android/app/src/main/AndroidManifest.xml")
if os.path.exists(manifest):
    s = open(manifest, encoding="utf-8").read()
    s2, n = re.subn(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', s, count=1)
    if n == 0:
        # no label attribute at all: add one to <application
        s2 = s.replace("<application", f'<application android:label="{APP_NAME}"', 1)
    if s2 != s:
        open(manifest, "w", encoding="utf-8").write(s2)
    m = re.search(r'android:label="([^"]*)"', s2)
    print("Android app name ->", m.group(1) if m else "?")
else:
    print("!! AndroidManifest.xml not found")

# ---------- iOS: name under the icon ----------
plist = os.path.join(root, "ios/Runner/Info.plist")
if os.path.exists(plist):
    s = open(plist, encoding="utf-8").read()
    for key in ("CFBundleDisplayName", "CFBundleName"):
        pat = rf"(<key>{key}</key>\s*<string>)[^<]*(</string>)"
        if re.search(pat, s):
            s = re.sub(pat, rf"\g<1>{APP_NAME}\g<2>", s, count=1)
        else:
            i = s.rfind("</dict>")
            s = s[:i] + f"\t<key>{key}</key>\n\t<string>{APP_NAME}</string>\n" + s[i:]
    open(plist, "w", encoding="utf-8").write(s)
    print("iOS app name ->", APP_NAME)

# ---------- pubspec: register assets/ ----------
pub = os.path.join(root, "pubspec.yaml")
s = open(pub, encoding="utf-8").read()
if not re.search(r"^\s*-\s*assets/\s*$", s, re.M):
    if re.search(r"^  assets:\s*$", s, re.M):
        s = re.sub(r"^  assets:\s*$", "  assets:\n    - assets/", s, count=1, flags=re.M)
    else:
        s = re.sub(r"^flutter:\s*$", "flutter:\n  assets:\n    - assets/", s, count=1, flags=re.M)
    open(pub, "w", encoding="utf-8").write(s)
print("pubspec assets:", "OK" if "- assets/" in open(pub, encoding="utf-8").read() else "!! not added")

# ---------- launcher icon config ----------
cfg = os.path.join(root, "flutter_launcher_icons.yaml")
open(cfg, "w", encoding="utf-8").write(
    'flutter_launcher_icons:\n'
    '  android: true\n'
    '  ios: true\n'
    '  image_path: "assets/app_icon.png"\n'
    '  adaptive_icon_background: "#15162F"\n'
    '  adaptive_icon_foreground: "assets/app_icon.png"\n'
    '  remove_alpha_ios: true\n'
)
print("launcher icon config: OK")
