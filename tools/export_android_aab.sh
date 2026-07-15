#!/usr/bin/env bash
# Build a signed release AAB for Google Play upload.
#
# Prereqs (once):
#   .secrets/ultravibe-release.keystore  (see tools/generate_android_release_keystore.sh)
#   .secrets/android-release-signing.env
#
# Usage:
#   ./tools/export_android_aab.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
SECRETS="$ROOT/.secrets"
KEYSTORE="$SECRETS/ultravibe-release.keystore"
ENV_FILE="$SECRETS/android-release-signing.env"

if [[ ! -f "$KEYSTORE" ]]; then
	echo "Missing release keystore. Run: ./tools/generate_android_release_keystore.sh" >&2
	exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
	echo "Missing $ENV_FILE" >&2
	exit 1
fi
# shellcheck source=/dev/null
source "$ENV_FILE"

# shellcheck source=/dev/null
source "$ROOT/tools/setup_android_build_env.sh"
# shellcheck source=/dev/null
source "$WORKSPACE/assets/scripts/shell/resolve_godot.sh"

GODOT_ANDROID="${GODOT_ANDROID:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [[ ! -x "$GODOT_ANDROID" ]]; then
	GODOT_ANDROID="${GODOT:-}"
fi

GODOT_SETTINGS="$HOME/Library/Application Support/Godot/editor_settings-4.7.tres"
if [[ -f "$GODOT_SETTINGS" ]] && grep -q 'export/android/java_sdk_path = ""' "$GODOT_SETTINGS"; then
	sed -i '' "s|export/android/java_sdk_path = \"\"|export/android/java_sdk_path = \"$JAVA_HOME\"|" "$GODOT_SETTINGS"
fi

export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${KEYSTORE_ALIAS:-ultravibe}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${KEYSTORE_PASSWORD:?KEYSTORE_PASSWORD not set in env file}"

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
OUT="$ROOT/builds/android/Ultravibe.aab"

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

echo "Exporting Android Play (release AAB) with $GODOT_ANDROID"
echo "  -> $OUT"
"$GODOT_ANDROID" --path "$ROOT" --headless --export-release "Android Play" "$OUT"

echo "Done: $OUT"
echo "Keystore: $KEYSTORE"
