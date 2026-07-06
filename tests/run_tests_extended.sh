#!/usr/bin/env bash
# Extended Match-3 mechanics regression suite (slower; run before large merges).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/../scripts/resolve_godot.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/_test_runner.sh"

EXTENDED_TESTS=(
	# Sprint 2 critical parity
	test_boon_sell
	test_consumable_sell
	test_shop_economy
	test_presentation_hud
	test_boon_consumable_depth
	test_lucky_find_upgrade
	test_shop_polish
	test_boss_match3_effects
	test_item_upgrade_grant
	test_skip_then_floor_consumable
	test_run_upgrade_invokes
	test_shop_available_after_skip
	test_hud_item_upgrade_grant_level_select
	# Core mechanics depth
	test_lucky_find
	test_boon_flavors
	test_boon_grants
	test_boon_move_hooks
	test_item_level_upgrades
	test_disable_color_block
	test_cell_floor_effects
	test_floor_modifier_pool
	test_play_level_floor_pool
	test_level_select_consumable_floor_pool
	test_hud_skip_floor_consumable
	test_cryptobro_round_skip
	test_ephemeral_finalize_boons
	test_double_match3_finalize_boons
	test_floor_stats_finalize_boons
	test_destroy_random_cell_floor
	test_griefing_floor
	test_hot_resolve_step
	test_freeze_resolve_step
	test_brainrot_scaling_increment
	test_salty_steel_finalize
	test_iconic_uncommon_echo
	test_match_component_axis_boons
	test_mewing_topology_scaling
	test_based_match5_gold_floor
	test_block_match_component
	test_topology_intersection_shapes
	test_slay_move_finalize
	test_boon_glitch_offgrid
	test_get_tile_empty_grid
	test_game_ui_nav
	test_catalog_localization
	test_catalog_sprite_paths
	test_hud_kratomania_level_select
	test_level_select_floor_consumable_dispatcher
)

run_godot_tests "$ROOT" "${EXTENDED_TESTS[@]}"
