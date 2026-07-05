#!/usr/bin/env bash
# Round target vs cascade-aware move score planning.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

export MATCH3_SCORE_MAX_LEVEL="${MATCH3_SCORE_MAX_LEVEL:-1}"
export MATCH3_CASCADE_YIELD="${MATCH3_CASCADE_YIELD:-0.55}"
export MATCH3_HIT_RATE="${MATCH3_HIT_RATE:-0.70}"
export MATCH3_MAX_ROUND="${MATCH3_MAX_ROUND:-24}"
export MATCH3_OPENING_MATCH="${MATCH3_OPENING_MATCH:-3}"

"$GODOT" --path "$ROOT" --headless --script res://tools/match3_round_balance_report.gd
