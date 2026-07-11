#!/usr/bin/env bash
# Fast smoke CI for Ultravibe (~14 headless boots).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../assets/scripts/shell/resolve_godot.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/_test_runner.sh"

SMOKE_TESTS=(
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

run_godot_tests "$ROOT" "${SMOKE_TESTS[@]}"
