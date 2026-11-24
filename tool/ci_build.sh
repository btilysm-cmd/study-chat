#!/usr/bin/env bash
# Build an APK without committing the generated android/ shell.
# Works on a PC and in GitHub Actions.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${WORKDIR:-/tmp/study-chat-build}"

rm -rf "$WORK"
flutter create --platforms=android --project-name study_chat "$WORK"
cp -R "$ROOT/lib" "$ROOT/pubspec.yaml" "$ROOT/analysis_options.yaml" "$WORK/"
rm -f "$WORK/test/widget_test.dart"
# Plugins such as flutter_plugin_android_lifecycle require API 36.
sed -i 's/compileSdk = flutter.compileSdkVersion/compileSdk = 36/' "$WORK/android/app/build.gradle.kts"
sed -i 's/targetSdk = flutter.targetSdkVersion/targetSdk = 36/' "$WORK/android/app/build.gradle.kts"
sed -i 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$WORK/android/app/build.gradle.kts"
# AGP's release lint crashes on image_picker's JavaDoc (CommentDetector bug).
# It only checks the release build and is not needed for our APK.
python3 - "$WORK/android/app/build.gradle.kts" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'checkReleaseBuilds' not in s:
    s = s.replace(
        'android {',
        'android {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }',
        1,
    )
    open(p, 'w').write(s)
PY
python3 - "$WORK/android/app/src/main/AndroidManifest.xml" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
if 'android.permission.INTERNET' not in s:
    s = s.replace(
        '<application',
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )
    open(p, 'w').write(s)
PY
cd "$WORK"
flutter pub get
flutter analyze || true
flutter build apk --release
mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-release.apk "$ROOT/dist/app-release.apk"
