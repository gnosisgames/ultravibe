extends SceneTree

## Sprint 6: all 20 match3Effects apply/remove, boss invocations, board pools, floor stats sync.

const Models = preload("res://game/match3/core/match3_models.gd")

const EFFECT_IDS: Array[String] = [
	"disable_blue_block",
	"disable_green_block",
	"disable_orange_block",
	"disable_pink_block",
	"disable_purple_block",
	"disable_red_block",
	"disable_all_cell_floor_modifiers",
	"half_round_moves",
	"halve_tile_points_multi_round",
	"lose_money_each_match",
	"party_animal_round_budget_bonus",
	"random_spawn_disabled_one_eighth",
	"reduce_first_destroyed_item_level_each_move",
	"starts_with_zero_shuffles",
	"hardstuck_round_budget",
	"hippie_round_shuffle_bonus",
	"touch_grass_round_moves_bonus",
	"score_only_exact_three_match_lines",
	"score_only_exact_four_or_five_match_lines",
	"shuffle_board_after_each_move",
]

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Bosses Effects Boards Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Bosses Effects Boards Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_all_match3_effects_apply_remove():
		return false
	if not _check_mister_beastus_boss_invocations():
		return false
	if not _check_board_difficulty_pools():
		return false
	if not _check_floor_modifier_statistics_sync():
		return false
	print("[SUCCESS] bosses, effects, and boards parity verified")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _match3() -> Match3Service:
	return _engine().get_service("Match3") as Match3Service


func _effects_module(match3: Match3Service):
	return match3.get("_match3_effects")


func _apply_effect(match3: Match3Service, effect_id: String) -> bool:
	var params := _engine().store.create_object()
	params.set_key("effectId", effect_id)
	params.set_key("roundsLifetime", 1)
	var result = match3.invoke_function("ApplyEffect", params)
	return result is GnosisFunctionResult and result.is_ok


func _remove_effect(match3: Match3Service, effect_id: String) -> bool:
	var params := _engine().store.create_object()
	params.set_key("effectId", effect_id)
	var result = match3.invoke_function("RemoveEffect", params)
	return result is GnosisFunctionResult and result.is_ok


func _check_all_match3_effects_apply_remove() -> bool:
	var match3 := _match3()
	for effect_id in EFFECT_IDS:
		if not _apply_effect(match3, effect_id):
			print("[FAIL] ApplyEffect failed for %s" % effect_id)
			return false
		if not _verify_effect_active(match3, effect_id):
			print("[FAIL] derived state missing for %s" % effect_id)
			return false
		if not _remove_effect(match3, effect_id):
			print("[FAIL] RemoveEffect failed for %s" % effect_id)
			return false
		if not _verify_effect_inactive(match3, effect_id):
			print("[FAIL] derived state still active after remove: %s" % effect_id)
			return false
	print("[OK] all %d match3Effects apply/remove with derived state" % EFFECT_IDS.size())
	return true


func _verify_effect_active(match3: Match3Service, effect_id: String) -> bool:
	var effects = _effects_module(match3)
	if effects == null:
		return false
	effects.rebuild_derived_state()
	var gameplay = match3.get_gameplay()
	match effect_id:
		"disable_blue_block":
			return effects.spawn_disabled_block_ids.has("blue")
		"disable_green_block":
			return effects.spawn_disabled_block_ids.has("green")
		"disable_orange_block":
			return effects.spawn_disabled_block_ids.has("orange")
		"disable_pink_block":
			return effects.spawn_disabled_block_ids.has("pink")
		"disable_purple_block":
			return effects.spawn_disabled_block_ids.has("purple")
		"disable_red_block":
			return effects.spawn_disabled_block_ids.has("red")
		"disable_all_cell_floor_modifiers":
			return effects.disable_all_cell_floor_modifiers
		"half_round_moves":
			return is_equal_approx(effects.round_moves_limit_multiplier_product, 0.5)
		"halve_tile_points_multi_round":
			return is_equal_approx(effects.tile_points_contribution_scale, 0.5) \
				and is_equal_approx(effects.tile_multi_contribution_scale, 0.5)
		"lose_money_each_match":
			return int(effects.currency_spend_per_match_by_currency_id.get("money", 0)) >= 1
		"party_animal_round_budget_bonus":
			return effects.manual_shuffle_add >= 1 and effects.round_moves_limit_add >= 3
		"random_spawn_disabled_one_eighth":
			return effects.random_spawn_disabled_probability > 0.0
		"reduce_first_destroyed_item_level_each_move":
			return effects.reduce_first_destroyed_item_level_each_move \
				and gameplay.reduce_first_destroyed_item_level_enabled
		"starts_with_zero_shuffles":
			return effects.manual_shuffles_round_start_override == 0
		"hardstuck_round_budget":
			return effects.manual_shuffle_add >= 1 and effects.round_moves_limit_add <= -2
		"hippie_round_shuffle_bonus":
			return effects.manual_shuffle_add >= 1
		"touch_grass_round_moves_bonus":
			return effects.round_moves_limit_add >= 3
		"score_only_exact_three_match_lines":
			return effects.restrict_score_to_exact_three_line_matches \
				and gameplay.score_restrict_exact_three
		"score_only_exact_four_or_five_match_lines":
			return effects.restrict_score_to_exact_four_or_five_line_matches \
				and gameplay.score_restrict_exact_four_five
		"shuffle_board_after_each_move":
			return effects.shuffle_board_after_each_move
	return false


func _verify_effect_inactive(match3: Match3Service, effect_id: String) -> bool:
	var effects = _effects_module(match3)
	if effects == null:
		return false
	effects.rebuild_derived_state()
	var gameplay = match3.get_gameplay()
	match effect_id:
		"disable_blue_block", "disable_green_block", "disable_orange_block", \
		"disable_pink_block", "disable_purple_block", "disable_red_block":
			return effects.spawn_disabled_block_ids.is_empty()
		"disable_all_cell_floor_modifiers":
			return not effects.disable_all_cell_floor_modifiers
		"half_round_moves":
			return is_equal_approx(effects.round_moves_limit_multiplier_product, 1.0)
		"halve_tile_points_multi_round":
			return is_equal_approx(effects.tile_points_contribution_scale, 1.0)
		"lose_money_each_match":
			return effects.currency_spend_per_match_by_currency_id.is_empty()
		"party_animal_round_budget_bonus", "hardstuck_round_budget", \
		"hippie_round_shuffle_bonus", "touch_grass_round_moves_bonus":
			return effects.manual_shuffle_add == 0 and effects.round_moves_limit_add == 0
		"random_spawn_disabled_one_eighth":
			return is_equal_approx(effects.random_spawn_disabled_probability, 0.0)
		"reduce_first_destroyed_item_level_each_move":
			return not effects.reduce_first_destroyed_item_level_each_move \
				and not gameplay.reduce_first_destroyed_item_level_enabled
		"starts_with_zero_shuffles":
			return effects.manual_shuffles_round_start_override < 0
		"score_only_exact_three_match_lines":
			return not effects.restrict_score_to_exact_three_line_matches
		"score_only_exact_four_or_five_match_lines":
			return not effects.restrict_score_to_exact_four_or_five_line_matches
		"shuffle_board_after_each_move":
			return not effects.shuffle_board_after_each_move
	return true


func _check_mister_beastus_boss_invocations() -> bool:
	var match3 := _match3()
	var effects = _effects_module(match3)
	if effects == null:
		print("[FAIL] match3 effects module missing")
		return false
	effects.apply_boss_round_start_for_profile("misterBeastus", false)
	if int(effects.currency_spend_per_match_by_currency_id.get("money", 0)) < 1:
		print("[FAIL] misterBeastus onRoundStart did not apply lose_money_each_match")
		return false
	effects.apply_boss_round_end_for_profile("misterBeastus")
	if effects.active_effect_count() != 0:
		print("[FAIL] misterBeastus onRoundEnd did not remove lose_money_each_match")
		return false
	print("[OK] Mister Beastus boss ApplyEffect/RemoveEffect invocations")
	return true


func _check_board_difficulty_pools() -> bool:
	var match3 := _match3()
	match3.call("_load_board_pools")
	var normal_pool: Array = match3.get("_normal_board_pool_ids")
	var advanced_pool: Array = match3.get("_advanced_board_pool_ids")
	var boss_pool: Array = match3.get("_boss_board_pool_ids")
	if normal_pool.is_empty() or advanced_pool.is_empty() or boss_pool.is_empty():
		print("[FAIL] board pools empty (easy/normal/hard tiers)")
		return false
	if not normal_pool.has("ball"):
		print("[FAIL] easy board 'ball' missing from normal-stage pool")
		return false
	if not advanced_pool.has("ball_bm"):
		print("[FAIL] normal-difficulty 'ball_bm' missing from advanced-stage pool")
		return false
	if not boss_pool.has("ball_in_ball"):
		print("[FAIL] hard board 'ball_in_ball' missing from boss-stage pool")
		return false
	var all_ids: Array[String] = match3.call("_get_all_board_ids")
	var used: Array[String] = []
	var normal_pick: String = match3.call("_pick_board_id_for_stage", "normal", 1, used, all_ids)
	if normal_pick.is_empty():
		print("[FAIL] could not pick board for normal stage")
		return false
	if not normal_pool.has(normal_pick):
		print("[FAIL] normal stage picked '%s' outside easy pool" % normal_pick)
		return false
	print("[OK] board difficulty pools map easy→normal, normal→advanced, hard→boss")
	return true


func _check_floor_modifier_statistics_sync() -> bool:
	var engine := _engine()
	var match3 := _match3()
	var store := engine.store

	var delta := store.create_object()
	delta.set_key("floorTypeId", "Gold")
	delta.set_key("count", 2)
	var add_result = match3.invoke_function("AddFloorModifierPoolDelta", delta)
	if not (add_result is GnosisFunctionResult) or not add_result.is_ok:
		print("[FAIL] AddFloorModifierPoolDelta for stats sync")
		return false

	match3.sync_floor_modifier_tile_statistics_from_pool()
	var pool_tiles := _read_floor_tiles_stats(match3)
	if int(pool_tiles.get("gold", 0)) != 2 or int(pool_tiles.get("gold_enhanced", 0)) != 2:
		print("[FAIL] pool sync stats %s (expected gold=2)" % str(pool_tiles))
		return false

	var gameplay = match3.get_gameplay()
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 2
	gameplay.load_level(layout, 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "green")
	_setup_tile(gameplay, 0, 1, "red")
	gameplay.get_tile(0, 1).cell_floor_type_id = "Gold"
	_setup_tile(gameplay, 1, 1, "blue")
	_setup_tile(gameplay, 2, 1, "green")

	match3.sync_floor_modifier_tile_statistics_from_grid()
	var grid_tiles := _read_floor_tiles_stats(match3)
	if int(grid_tiles.get("gold", 0)) != 1:
		print("[FAIL] grid sync gold count=%d (expected 1)" % int(grid_tiles.get("gold", 0)))
		return false
	if int(grid_tiles.get("capacity", 0)) < 6:
		print("[FAIL] grid sync missing capacity stat")
		return false
	var hud_counts: Dictionary = match3.get_enhanced_floor_tile_counts()
	if int(hud_counts.get("Gold", 0)) != 2:
		print("[FAIL] HUD enhanced counts %s (expected Gold=2 from pool)" % str(hud_counts))
		return false
	print("[OK] floor modifier pool + grid statistics sync with HUD counts")
	return true


func _read_floor_tiles_stats(match3: Match3Service) -> Dictionary:
	var stats := match3.get_node("statistics", false).get_node("match3").get_node("floorModifiers").get_node("tiles")
	var out: Dictionary = {}
	if not stats.is_valid():
		return out
	for key in stats.get_keys():
		var node := stats.get_node(str(key))
		if node.is_valid() and node.value != null:
			out[str(key)] = int(node.value)
	return out


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
