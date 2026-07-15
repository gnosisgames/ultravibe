#!/usr/bin/env bash
# Build a debug APK for sideload testing on a phone.
#
# Prereqs (once): ./tools/setup_android_sdk.sh
# Install on phone: adb install -r builds/android/Ultravibe.apk
#
# Usage:
#   ./tools/export_android_apk.sh          # debug (default)
#   ./tools/export_android_apk.sh release
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
MODE="${1:-debug}"

# shellcheck source=/dev/null
source "$ROOT/tools/setup_android_build_env.sh"
# shellcheck source=/dev/null
source "$WORKSPACE/assets/scripts/shell/resolve_godot.sh"

GODOT_ANDROID="${GODOT_ANDROID:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_ANDROID" ]]; then
	GODOT_ANDROID="${GODOT:-}"
fi

MARKER="$ROOT/data/edition.mobile.json"
if [[ -f "$MARKER" ]]; then
	"$ROOT/addons/com.gnosisgames.gnosisengine/tools/apply_edition_manifest.sh" \
		"$ROOT" "$MARKER" --in-place
fi

if [[ ! -d "$ROOT/addons/mod_loader" ]] || [[ ! -f "$ROOT/addons/mod_loader/mod_loader_store.gd" ]]; then
	if [[ -f "$ROOT/tools/apply_gnosis_mod_loader_overlay.sh" ]]; then
		(cd "$ROOT" && git submodule update --init vendor/godot-mod-loader 2>/dev/null || true)
		"$ROOT/tools/apply_gnosis_mod_loader_overlay.sh"
	fi
fi

mkdir -p "$ROOT/builds/android"
OUT="$ROOT/builds/android/Ultravibe.apk"

touch "$ROOT/android/build/.gdignore" 2>/dev/null || true
find "$ROOT/android/build" -name "*.import" -delete 2>/dev/null || true

if [[ -x "$ROOT/tools/prepare_android_adaptive_icons.sh" ]]; then
	"$ROOT/tools/prepare_android_adaptive_icons.sh"
fi

if [[ ! -f "$ROOT/.godot/global_script_class_cache.cfg" ]]; then
	echo "First-time import..."
	"$GODOT_ANDROID" --path "$ROOT" --headless --import
fi

if [[ ! -d "$ROOT/android/build" ]] || [[ ! -f "$ROOT/android/build/build.gradle" ]]; then
	echo "Installing Android build template..."
	TEMPLATE_ZIP="$HOME/Library/Application Support/Godot/export_templates/4.7.stable/android_source.zip"
	if [[ -f "$TEMPLATE_ZIP" ]]; then
		mkdir -p "$ROOT/android/build"
		unzip -qo "$TEMPLATE_ZIP" -d "$ROOT/android/build"
		echo "4.7.stable" > "$ROOT/android/.build_version"
		touch "$ROOT/android/build/.gdignore"
	else
		"$GODOT_ANDROID" --path "$ROOT" --headless --install-android-build-template --quit-after 3
	fi
fi

FLAG="--export-debug"
if [[ "$MODE" == "release" ]]; then
	FLAG="--export-release"
fi

echo "Exporting Android ($MODE) with $GODOT_ANDROID"
echo "  -> $OUT"
"$GODOT_ANDROID" --path "$ROOT" --headless "$FLAG" "Android" "$OUT"

echo "Done: $OUT"
echo "Install: adb uninstall com.gnosisgames.ultravibe && adb install \"$OUT\""
