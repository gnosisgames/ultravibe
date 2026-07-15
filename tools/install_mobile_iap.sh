#!/usr/bin/env bash
# Install mobile IAP plugins into Ultravibe (or pass another game root).
#
# Android: addons/GodotGooglePlayBilling/  (official Godot plugin)
# iOS:     ios/plugins/godot-storekit2/    (StoreKit 2)
#
# Usage:
#   ./tools/install_mobile_iap.sh
#   ./tools/install_mobile_iap.sh /path/to/other-game
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ $# -ge 1 ]]; then
	ROOT="$(cd "$1" && pwd)"
fi

PLAY_BILLING_VERSION="${PLAY_BILLING_VERSION:-3.2.0}"
STOREKIT2_VERSION="${STOREKIT2_VERSION:-v0.2}"
STOREKIT2_GODOT="${STOREKIT2_GODOT:-4.6.2}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PLAY_ZIP="$TMP/GodotGooglePlayBilling.zip"
STOREKIT_ZIP="$TMP/godot-storekit2.zip"

echo "Downloading GodotGooglePlayBilling ${PLAY_BILLING_VERSION}..."
curl -sL -o "$PLAY_ZIP" \
	"https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/${PLAY_BILLING_VERSION}/GodotGooglePlayBilling.zip"

echo "Downloading godot-storekit2 ${STOREKIT2_VERSION} (Godot ${STOREKIT2_GODOT})..."
curl -sL -o "$STOREKIT_ZIP" \
	"https://github.com/godot-sdk-integrations/godot-storekit2/releases/download/${STOREKIT2_VERSION}/godot-storekit2-${STOREKIT2_VERSION}-Godot-${STOREKIT2_GODOT}.zip"

unzip -qo "$PLAY_ZIP" -d "$ROOT"
mkdir -p "$ROOT/ios/plugins"
unzip -qo "$STOREKIT_ZIP" -d "$ROOT/ios/plugins"

echo "Installed:"
echo "  $ROOT/addons/GodotGooglePlayBilling/"
echo "  $ROOT/ios/plugins/godot-storekit2/"
echo ""
echo "Next steps:"
echo "  1. Open the project in Godot → Project → Project Settings → Plugins"
echo "     Enable GodotGooglePlayBilling (project.godot may already list it)."
echo "  2. Android export: Gradle build must stay enabled (already on in export_presets.cfg)."
echo "  3. iOS export: enable godot-storekit2 under Export → iOS → Plugins (export_presets.cfg updated)."
echo "  4. Create products in Play Console / App Store Connect (see data/edition.mobile.json)."
echo "  5. Engine wires GnosisEditionStoreHost on mobile export — no per-game store bridge needed."
