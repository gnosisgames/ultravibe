#!/usr/bin/env bash
# Print per-gem match-3/4/5 score table for balance tuning.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

export MATCH3_SCORE_MAX_LEVEL="${MATCH3_SCORE_MAX_LEVEL:-5}"
"$GODOT" --path "$ROOT" --headless --script res://tools/match3_item_score_report.gd
