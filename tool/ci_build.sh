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
cd "$WORK"
flutter pub get
flutter analyze || true
flutter build apk --debug
mkdir -p "$ROOT/dist"
cp build/app/outputs/flutter-apk/app-debug.apk "$ROOT/dist/app-debug.apk"
