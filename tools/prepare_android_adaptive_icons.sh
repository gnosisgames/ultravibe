#!/usr/bin/env bash
# Build Android-only adaptive launcher PNGs (432x432).
#
# Desktop uses project.godot config/icon (unchanged). Android export preset points
# at these files so Godot does not fall back to the full-bleed project icon.
#
# Usage: ./tools/prepare_android_adaptive_icons.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_ANDROID="$ROOT/assets/logos/android"
SRC_ICON="$SRC_ANDROID/playstore-icon.png"
OUT_FG="$SRC_ANDROID/adaptive-foreground-432.png"
OUT_BG="$SRC_ANDROID/adaptive-background-432.png"
CANVAS=432
LOGO_PX=288

if [[ ! -f "$SRC_ICON" ]]; then
	echo "Missing $SRC_ICON" >&2
	exit 1
fi

BG_HEX="#1e506e"
if [[ -f "$SRC_ANDROID/values/ic_launcher_background.xml" ]]; then
	BG_HEX="$(grep -o '#[0-9A-Fa-f]\{6\}' "$SRC_ANDROID/values/ic_launcher_background.xml" | head -1)"
fi
BG_SIPS="${BG_HEX//#/}"
BG_R=$((16#${BG_SIPS:0:2}))
BG_G=$((16#${BG_SIPS:2:2}))
BG_B=$((16#${BG_SIPS:4:2}))

make_solid_png() {
	local w="$1" h="$2" out="$3"
	python3 - "$w" "$h" "$BG_R" "$BG_G" "$BG_B" "$out" <<'PY'
import struct, sys, zlib
w, h = int(sys.argv[1]), int(sys.argv[2])
r, g, b = int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
out = sys.argv[6]
def chunk(tag, data):
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
raw = b"".join(b"\x00" + bytes([r, g, b]) * w for _ in range(h))
png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(raw, 9))
    + chunk(b"IEND", b"")
)
open(out, "wb").write(png)
PY
}

tmp="$(mktemp -t ultra_adaptive_XXXXXX.png)"
cp "$SRC_ICON" "$tmp"
sips -z "$LOGO_PX" "$LOGO_PX" "$tmp" >/dev/null
sips -p "$CANVAS" "$CANVAS" --padColor "$BG_SIPS" "$tmp" --out "$OUT_FG" >/dev/null
rm -f "$tmp"

make_solid_png "$CANVAS" "$CANVAS" "$OUT_BG"

echo "Prepared Android adaptive icons:"
echo "  foreground: $OUT_FG (playstore ${LOGO_PX}px on ${CANVAS}x${CANVAS}, bg $BG_HEX)"
echo "  background: $OUT_BG (solid $BG_HEX)"
echo "  desktop icon: unchanged (project.godot config/icon)"
