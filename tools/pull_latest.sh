#!/usr/bin/env bash
set -euo pipefail
GAME_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(cd "$GAME_ROOT/.." && pwd)"
exec "$WORKSPACE/scripts/pull_game_and_engine.sh" "$(basename "$GAME_ROOT")" "$@"
