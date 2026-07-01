class_name Match3EffectHandlers
extends RefCounted

## Rebuild handlers keyed by JSON `handler` (Unity Match3EffectHandlerRegistry parity).

static func try_apply_rebuild(handler_id: String, parameters: Dictionary, acc) -> bool:
	var key := handler_id.strip_edges().to_lower()
	if key.is_empty() or acc == null:
		return false
	var params := parameters if parameters != null else {}
	match key:
		"spawn_disabled_item_type_for_blocks":
			_apply_spawn_disabled_item_type_for_blocks(params, acc)
		"random_disabled_plain_spawn":
			_apply_random_disabled_plain_spawn(params, acc)
		"halve_accumulated_tile_points_and_multi_for_round":
			_apply_halve_accumulated_tile_points_and_multi_for_round(params, acc)
		"override_manual_shuffles_at_round_start":
			_apply_override_manual_shuffles_at_round_start(params, acc)
		"add_shuffle_and_moves_budget_at_round_start":
			_apply_add_shuffle_and_moves_budget_at_round_start(params, acc)
		"multiply_round_moves_limit":
			_apply_multiply_round_moves_limit(params, acc)
		"spend_currency_each_match_wave":
			_apply_spend_currency_each_match_wave(params, acc)
		"restrict_score_to_exact_three_line_matches":
			_apply_restrict_score_to_exact_three_line_matches(params, acc)
		"restrict_score_to_exact_four_or_five_line_matches":
			_apply_restrict_score_to_exact_four_or_five_line_matches(params, acc)
		"shuffle_board_after_each_move":
			_apply_shuffle_board_after_each_move(params, acc)
		"reduce_first_destroyed_item_level_each_move":
			_apply_reduce_first_destroyed_item_level_each_move(params, acc)
		"disable_all_cell_floor_modifiers":
			_apply_disable_all_cell_floor_modifiers(params, acc)
		_:
			return false
	return true


static func is_registered(handler_id: String) -> bool:
	var key := handler_id.strip_edges().to_lower()
	return key in [
		"spawn_disabled_item_type_for_blocks",
		"random_disabled_plain_spawn",
		"halve_accumulated_tile_points_and_multi_for_round",
		"override_manual_shuffles_at_round_start",
		"add_shuffle_and_moves_budget_at_round_start",
		"multiply_round_moves_limit",
		"spend_currency_each_match_wave",
		"restrict_score_to_exact_three_line_matches",
		"restrict_score_to_exact_four_or_five_line_matches",
		"shuffle_board_after_each_move",
		"reduce_first_destroyed_item_level_each_move",
		"disable_all_cell_floor_modifiers",
	]


static func _read_float(params: Dictionary, key: String, fallback: float) -> float:
	if params == null or not params.has(key):
		return fallback
	var v: Variant = params[key]
	if v is float or v is int:
		return float(v)
	return fallback


static func _read_int(params: Dictionary, key: String, fallback: int) -> int:
	if params == null or not params.has(key):
		return fallback
	var v: Variant = params[key]
	if v is int or v is float:
		return int(v)
	return fallback


static func _read_string_ids(params: Dictionary, array_key: String, into: Dictionary) -> void:
	if params == null or not params.has(array_key):
		return
	var tok: Variant = params[array_key]
	if tok is Array:
		for item in tok:
			var s := str(item).strip_edges()
			if not s.is_empty():
				into[s.to_lower()] = true
	elif tok is String:
		for part in str(tok).split(","):
			var s := part.strip_edges()
			if not s.is_empty():
				into[s.to_lower()] = true


static func _apply_spawn_disabled_item_type_for_blocks(params: Dictionary, acc) -> void:
	_read_string_ids(params, "blockIds", acc.spawn_disabled_block_ids)


static func _apply_random_disabled_plain_spawn(params: Dictionary, acc) -> void:
	var one_in := _read_int(params, "oneIn", 0)
	var prob := _read_float(params, "probability", NAN)
	var resolved: float
	if one_in > 0:
		resolved = 1.0 / float(one_in)
	elif not is_nan(prob):
		resolved = prob
	else:
		resolved = 1.0 / 8.0
	resolved = clampf(resolved, 0.0, 1.0)
	acc.random_spawn_disabled_probability = maxf(acc.random_spawn_disabled_probability, resolved)


static func _apply_halve_accumulated_tile_points_and_multi_for_round(params: Dictionary, acc) -> void:
	var pts := _read_float(params, "pointsScale", NAN)
	var mul := _read_float(params, "multiScale", NAN)
	if is_nan(pts) or pts <= 0.0:
		pts = 0.5
	if is_nan(mul) or mul <= 0.0:
		mul = 0.5
	acc.tile_points_scale *= pts
	acc.tile_multi_scale *= mul


static func _apply_override_manual_shuffles_at_round_start(params: Dictionary, acc) -> void:
	var v := maxi(0, _read_int(params, "manualShuffles", 0))
	if acc.manual_shuffle_override_min < 0:
		acc.manual_shuffle_override_min = v
	else:
		acc.manual_shuffle_override_min = mini(acc.manual_shuffle_override_min, v)


static func _apply_add_shuffle_and_moves_budget_at_round_start(params: Dictionary, acc) -> void:
	acc.manual_shuffle_delta_sum += _read_int(params, "manualShufflesAdd", 0)
	acc.moves_limit_delta_sum += _read_int(params, "movesLimitAdd", 0)


static func _apply_multiply_round_moves_limit(params: Dictionary, acc) -> void:
	if params == null or not params.has("multiplier"):
		return
	var m := _read_float(params, "multiplier", -1.0)
	if m <= 0.0 or is_nan(m) or is_inf(m):
		return
	acc.moves_limit_multiplier_product *= m


static func _apply_spend_currency_each_match_wave(params: Dictionary, acc) -> void:
	var cid := str(params.get("currencyId", "")).strip_edges()
	if cid.is_empty() or cid.length() > 64:
		return
	var amt := _read_int(params, "amountPerMatch", 0)
	if amt <= 0:
		amt = _read_int(params, "currencyAmountPerMatch", 1)
	amt = maxi(1, amt)
	acc.currency_spend_per_match_by_id[cid] = int(acc.currency_spend_per_match_by_id.get(cid, 0)) + amt


static func _apply_restrict_score_to_exact_three_line_matches(_params: Dictionary, acc) -> void:
	acc.restrict_score_to_exact_three_line_matches = true


static func _apply_restrict_score_to_exact_four_or_five_line_matches(_params: Dictionary, acc) -> void:
	acc.restrict_score_to_exact_four_or_five_line_matches = true


static func _apply_shuffle_board_after_each_move(_params: Dictionary, acc) -> void:
	acc.shuffle_board_after_each_move = true


static func _apply_reduce_first_destroyed_item_level_each_move(_params: Dictionary, acc) -> void:
	acc.reduce_first_destroyed_item_level_each_move = true


static func _apply_disable_all_cell_floor_modifiers(_params: Dictionary, acc) -> void:
	acc.disable_all_cell_floor_modifiers = true
