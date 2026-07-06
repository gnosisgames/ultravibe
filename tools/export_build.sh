#!/usr/bin/env bash
# Export Ultravibe for a named preset (see export_presets.cfg).
# Usage:
#   ./tools/export_build.sh macOS
#   ./tools/export_build.sh "Windows Desktop" release
#   ./tools/export_build.sh Android debug
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

PRESET="${1:-macOS}"
MODE="${2:-release}"
mkdir -p "$ROOT/builds"

case "$MODE" in
	release) EXPORT_FLAG="--export-release" ;;
	debug) EXPORT_FLAG="--export-debug" ;;
	*)
		echo "Unknown mode '$MODE' (use release or debug)" >&2
		exit 1
		;;
esac

# Resolve output path from export_presets.cfg (preset name must match exactly).
EXPORT_PATH="$(
	python3 - "$PRESET" "$ROOT/export_presets.cfg" <<'PY'
import re, sys
preset_name, path = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
blocks = re.split(r"\n(?=\[preset\.\d+\]\n)", text)
for block in blocks:
    if not block.strip():
        continue
    name_m = re.search(r'^name="([^"]+)"', block, re.M)
    path_m = re.search(r'^export_path="([^"]+)"', block, re.M)
    if name_m and name_m.group(1) == preset_name and path_m:
        print(path_m.group(1))
        break
PY
)"

if [[ -z "$EXPORT_PATH" ]]; then
	echo "Could not find export_path for preset '$PRESET' in export_presets.cfg" >&2
	exit 1
fi

OUT="$ROOT/$EXPORT_PATH"
mkdir -p "$(dirname "$OUT")"

if [[ "$PRESET" == "Android" ]]; then
	echo "Ensuring Android build template..."
	"$GODOT" --path "$ROOT" --headless --install-android-build-template
fi

echo "Exporting '$PRESET' ($MODE) -> $OUT"
"$GODOT" --path "$ROOT" --headless "$EXPORT_FLAG" "$PRESET" "$OUT"
echo "Done: $OUT"
