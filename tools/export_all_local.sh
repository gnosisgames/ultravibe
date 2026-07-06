#!/usr/bin/env bash
# Export all presets this Mac can build (macOS, Linux, Android, iOS if configured).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
exec "$WORKSPACE/scripts/export_godot_all_local.sh" ultravibe "$@"
