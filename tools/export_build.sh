#!/usr/bin/env bash
# Thin wrapper — logic lives in 02_godot/scripts/export_godot.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$ROOT/.." && pwd)"
exec "$WORKSPACE/scripts/export_godot.sh" ultravibe "$@"
