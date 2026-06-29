#!/usr/bin/env bash
# Boot Ultravibe and save UI screenshots for visual verification.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

mkdir -p "$ROOT/screenshots"
echo "Capturing to $ROOT/screenshots/_capture_*.png ..."
"$GODOT" --path "$ROOT" --script res://tools/capture_views.gd
echo "Done. Inspect screenshots/_capture_*.png"
