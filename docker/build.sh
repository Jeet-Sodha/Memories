#!/usr/bin/env bash
# Usage: build-memories [apk|analyze]
set -euo pipefail

MODE="${1:-apk}"
APP=/work/memories_app

# 1) Create the Flutter project once (kept in a Docker volume).
if [ ! -d "$APP" ]; then
  echo ">>> Creating Flutter project..."
  cd /work
  flutter create --org com.example --project-name memories_app \
    --platforms=android,ios memories_app
fi
cd "$APP"

# 2) Drop in our code (replaces the default counter app + its test).
rm -rf lib test
cp -r /src/lib ./lib

# 3) Dependencies.
echo ">>> Adding packages..."
flutter pub add \
  supabase_flutter google_fonts "flutter_map:^7.0.2" latlong2 \
  geolocator image_picker "file_picker:^8.1.6" \
  flutter_image_compress path_provider path video_player audioplayers \
  record cached_network_image shared_preferences intl
flutter pub add "geocoding:^3.0.0"
flutter pub get

# 4) Configure permissions and SDKs.
python3 /src/tools/apply_platform_config.py .

# 4b) Branding: app name "Memories", the logo, and the assets folder.
echo ">>> Applying branding (name + logo)..."
mkdir -p assets
cp -f /src/assets/* assets/ 2>/dev/null || true
flutter pub add --dev flutter_launcher_icons
python3 /src/tools/apply_branding.py .
flutter pub get
if [ "$MODE" != "analyze" ]; then
  dart run flutter_launcher_icons
fi

# 5) Analyze the actual Dart code when requested.
if [ "$MODE" = "analyze" ]; then
  echo ">>> Running flutter analyze"
  flutter analyze --no-fatal-infos --no-fatal-warnings
  echo ">>> Analyze finished."
  exit 0
fi

# 6) Let Flutter finish its Gradle migration/configuration first, then re-apply
# the SDK override. The root Gradle override applies to app AND plugin modules.
echo ">>> Preparing Android Gradle configuration..."
flutter build apk --release --config-only
python3 /src/tools/apply_platform_config.py .

echo ">>> Verifying Android compileSdk configuration"
grep -n 'compileSdk' android/app/build.gradle.kts 2>/dev/null || \
  grep -n 'compileSdkVersion' android/app/build.gradle

echo ">>> App name stored in the manifest:"
grep -n 'android:label' android/app/src/main/AndroidManifest.xml

echo ">>> Building release APK..."
flutter build apk --release
mkdir -p /out
cp build/app/outputs/flutter-apk/app-release.apk /out/memories.apk
echo ">>> DONE: output/memories.apk"
