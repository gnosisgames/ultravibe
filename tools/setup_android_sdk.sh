#!/usr/bin/env bash
# One-time Android SDK package install for Godot 4.7 mobile exports.
#
# Requires Homebrew. Installs JDK 17 + sdkmanager packages Godot expects.
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
	echo "Install Homebrew first: https://brew.sh" >&2
	exit 1
fi

echo "Installing JDK 17 and Android command-line tools..."
brew install openjdk@17 android-platform-tools android-commandlinetools

# shellcheck source=/dev/null
source "$(dirname "$0")/setup_android_build_env.sh"

SDK_ROOT="$ANDROID_SDK_ROOT"
mkdir -p "$SDK_ROOT"

echo "Installing SDK platforms/build-tools (android-36)..."
yes | sdkmanager --sdk_root="$SDK_ROOT" \
	"platform-tools" \
	"platforms;android-36" \
	"build-tools;36.0.0" \
	"cmdline-tools;latest"

GODOT_SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
if [[ -f "$GODOT_SETTINGS" ]]; then
	if grep -q 'export/android/java_sdk_path = ""' "$GODOT_SETTINGS"; then
		sed -i '' "s|export/android/java_sdk_path = \"\"|export/android/java_sdk_path = \"$JAVA_HOME\"|" "$GODOT_SETTINGS"
		echo "Updated Godot java_sdk_path in editor_settings-4.7.tres"
	fi
fi

echo ""
echo "Android build environment ready."
echo "  JAVA_HOME=$JAVA_HOME"
echo "  ANDROID_SDK_ROOT=$SDK_ROOT"
echo ""
echo "Build APK:  cd ultravibe && ./tools/export_android_apk.sh"
echo "Install:    adb install -r builds/android/Ultravibe.apk"
