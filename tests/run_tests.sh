#!/usr/bin/env bash
# Run all Ultravibe integration tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

TESTS=(
	test_config_catalogs
	test_match3_core
	test_scene_format_guard
	test_project_packaging_smoke
	test_localization_theme
	test_ui_focus
	test_console_overlay
	test_audio_feedback
	test_game_ui_overlays
	test_gamepad_player_assignment
	test_input_rebinding
	test_persistence_boundaries
	test_continue_run
	test_endless_mode
)

failed=0
for t in "${TESTS[@]}"; do
	echo "==> $t"
	out=$("$GODOT" --path "$ROOT" --headless --script "res://tests/${t}.gd" 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g')
	tail_out=$(printf '%s' "$out" | tail -30)
	if printf '%s' "$tail_out" | grep -qE "Passed|passed|SUCCESS"; then
		printf '%s' "$tail_out" | grep -E "Passed|passed|SUCCESS" | tail -1 || true
	else
		printf '%s' "$out" | grep -E "FAIL|FAILED|SCRIPT ERROR|Parse Error" | head -5 || true
		echo "FAILED: $t"
		failed=$((failed + 1))
	fi
done

if [[ $failed -gt 0 ]]; then
	echo "--- Ultravibe tests: $failed failed ---"
	exit 1
fi
echo "--- Ultravibe tests: all passed ---"
