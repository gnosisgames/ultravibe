#!/usr/bin/env bash
# Run all Ultravibe integration tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"

TESTS=(
	test_config_catalogs
	test_scene_format_guard
	test_project_packaging_smoke
	test_falling_block_core
	test_full_boot
	test_fall_speed
	test_line_scoring
	test_negative_ramp
	test_lock_delay_feel
	test_round_rewards
	test_boon_score
	test_discards_consumables
	test_consumable_roll
	test_discard_single_press
	test_bosses
	test_localization_theme
	test_ui_focus
	test_play_hud_smoke
	test_console_overlay
	test_audio_feedback
	test_game_ui_overlays
	test_gameplay_input_routing
	test_gamepad_player_assignment
	test_input_rebinding
	test_persistence_boundaries
	test_game_over_flow
	test_e2e_run
	test_parity_invocations
	test_parity_boss_effects
	test_parity_coop
	test_parity_content_catalog
)

failed=0
for t in "${TESTS[@]}"; do
	echo "==> $t"
	out=$("$GODOT" --path "$ROOT" --headless --script "res://tests/${t}.gd" 2>&1 | sed -E 's/\x1b\[[0-9;]*m//g')
	if echo "$out" | grep -qE "Passed|passed|SUCCESS"; then
		echo "$out" | grep -E "Passed|SUCCESS" | tail -1
	else
		echo "$out" | grep -E "FAIL|FAILED|SCRIPT ERROR|Parse Error" | head -5
		echo "FAILED: $t"
		failed=$((failed + 1))
	fi
done

if [[ $failed -gt 0 ]]; then
	echo "--- Ultravibe tests: $failed failed ---"
	exit 1
fi
echo "--- Ultravibe tests: all passed ---"
