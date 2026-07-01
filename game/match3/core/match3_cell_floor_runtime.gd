class_name Match3CellFloorRuntime
extends RefCounted

## Data-driven enhanced cell floor triggers (Unity CellFloorTypes partial parity).

const Models = preload("res://game/match3/core/match3_models.gd")
const PoolScript = preload("res://game/match3/core/match3_floor_modifier_pool.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const BoardScript = preload("res://game/match3/core/match3_cell_floor_board.gd")
const FloatTextScript = preload("res://game/match3/view/match3_score_floating_display_text.gd")

const WHEN_SCORING_DESTROY := "on_scoring_destroy"
const WHEN_MOVE_FINALIZE := "on_move_finalize"
const LOCKED_IN_RETRIGGER_TYPES := ["Steel"]
const BOON_LOCKED_IN := "LockedIn"

var _service: GnosisService = null


func _init(service: GnosisService) -> void:
	_service = service


func on_scoring_destroy(
	tile: Models.Match3TileData,
	coord: Models.TileCoord,
	match_result: Models.MatchResult,
	contrib_multi: int,
	move_multi_accum: int = 1
) -> Dictionary:
	var out := {"points": 0, "multi": 0}
	if _service == null or tile == null or match_result == null:
		return out
	if _floor_modifiers_disabled():
		return out
	var type_id := tile.cell_floor_type_id.strip_edges()
	if type_id.is_empty():
		return out
	var type_row := _floor_type_row(type_id)
	if not type_row.is_valid():
		return out
	var triggers := _triggers_node(type_row)
	if not triggers.is_valid() or triggers.get_type() != GnosisValueType.LIST:
		return out
	_play_type_sfx(type_row, "triggerSfxClipId")
	var rng := _gameplay_rng()
	for i in triggers.get_count():
		var trigger := triggers.get_node(i)
		if not trigger.is_valid():
			continue
		if _node_str(trigger, "when").to_lower() != WHEN_SCORING_DESTROY:
			continue
		var effects := trigger.get_node("effects")
		if not effects.is_valid() or effects.get_type() != GnosisValueType.LIST:
			continue
		for e in range(effects.get_count()):
			var effect := effects.get_node(e)
			var delta := _apply_scoring_destroy_effect(
				effect, type_id, tile, coord, match_result, contrib_multi, move_multi_accum, rng
			)
			out["points"] = int(out["points"]) + int(delta.get("points", 0))
			out["multi"] = int(out["multi"]) + int(delta.get("multi", 0))
	return out


func on_move_finalize(points: int, multi: int) -> Dictionary:
	if _service == null or _floor_modifiers_disabled():
		return {"points": 0, "multi": 0, "finalize_steps": []}
	var gameplay = _service.get_gameplay() if _service.has_method("get_gameplay") else null
	if gameplay == null:
		return {"points": 0, "multi": 0, "finalize_steps": []}
	var finalize_steps: Array = []
	var new_points := points
	var new_multi_f := float(maxi(1, multi))
	new_points += _finalize_points_delta(gameplay, [])
	var multi_pack := _finalize_multi_multiplier(gameplay, new_multi_f, [])
	new_multi_f = float(multi_pack.get("multi", new_multi_f))
	finalize_steps.append_array(multi_pack.get("steps", []))
	if SupportScript.is_boon_catalog_id_equipped(_service, BOON_LOCKED_IN):
		new_points += _finalize_points_delta(gameplay, LOCKED_IN_RETRIGGER_TYPES)
		var locked_pack := _finalize_multi_multiplier(gameplay, new_multi_f, LOCKED_IN_RETRIGGER_TYPES)
		new_multi_f = float(locked_pack.get("multi", new_multi_f))
		finalize_steps.append_array(locked_pack.get("steps", []))
	return {
		"points": new_points - points,
		"multi": int(round(new_multi_f)) - multi,
		"finalize_steps": finalize_steps,
	}


func _apply_scoring_destroy_effect(
	effect: GnosisNode,
	floor_type_id: String,
	tile: Models.Match3TileData,
	coord: Models.TileCoord,
	match_result: Models.MatchResult,
	contrib_multi: int,
	move_multi_accum: int,
	rng: RandomNumberGenerator
) -> Dictionary:
	var out := {"points": 0, "multi": 0}
	if not effect.is_valid() or not _random_passes(effect, rng):
		return out
	var kind := _node_str(effect, "kind").to_lower()
	match kind:
		"add_currency":
			var amount := maxi(0, _node_int(effect, "amount", 0))
			if amount <= 0:
				return out
			var currency_id := _node_str(effect, "currencyId", "money")
			_add_currency(currency_id, amount)
			if currency_id.to_lower() == "money":
				_record_floor_pop(match_result, coord, 0, 0, amount)
			_play_type_sfx(_floor_type_row(floor_type_id), "addSfxClipId")
			_record_lucky_successful_trigger(floor_type_id, match_result)
			return out
		"add_move_points":
			var amount := _node_int(effect, "amount", 0)
			if amount == 0:
				return out
			out["points"] = amount
			_record_floor_pop(match_result, coord, amount, 0, 0)
			_play_type_sfx(_floor_type_row(floor_type_id), "addSfxClipId")
			_record_lucky_successful_trigger(floor_type_id, match_result)
			return out
		"add_move_multi":
			var amount := _node_int(effect, "amount", 0)
			if amount == 0:
				return out
			out["multi"] = amount
			_record_floor_pop(match_result, coord, 0, amount, 0)
			_play_type_sfx(_floor_type_row(floor_type_id), "addSfxClipId")
			_record_lucky_successful_trigger(floor_type_id, match_result)
			return out
		"multiply_move_multi":
			var factor := _read_effect_float(effect, "factor", 1.0)
			if is_equal_approx(factor, 1.0):
				return out
			if contrib_multi > 0:
				var bonus := int(round(float(contrib_multi) * (factor - 1.0)))
				if bonus == 0:
					return out
				out["multi"] = bonus
				_record_floor_pop(match_result, coord, 0, bonus, 0)
			else:
				var move_multi_before := maxi(1, move_multi_accum)
				var scaled := int(round(float(move_multi_before) * factor))
				var bonus := scaled - move_multi_before
				if bonus == 0:
					return out
				out["multi"] = bonus
				_record_floor_pop(match_result, coord, 0, bonus, 0)
			_play_type_sfx(_floor_type_row(floor_type_id), "addSfxClipId")
			_record_lucky_successful_trigger(floor_type_id, match_result)
			return out
		"clear_cell_floor":
			if tile.cell_floor_type_id.strip_edges().is_empty():
				return out
			var cleared_id := tile.cell_floor_type_id.strip_edges()
			tile.cell_floor_type_id = ""
			_consume_pool_slot(cleared_id)
			_record_floor_cleared(match_result, coord)
			_play_type_sfx(_floor_type_row(cleared_id), "removeSfxClipId")
			return out
		"add_manual_shuffles":
			var add := maxi(0, _node_int(effect, "amount", 0))
			if add > 0 and _service.has_method("add_manual_shuffles"):
				_service.call("add_manual_shuffles", add)
			return out
		"add_current_moves":
			var add := _node_int(effect, "amount", 0)
			if add != 0 and _service.has_method("add_current_moves"):
				_service.call("add_current_moves", add)
			return out
		_:
			return out


func _finalize_points_delta(gameplay, restrict_types: Array[String]) -> int:
	var delta := 0
	var restrict := not restrict_types.is_empty()
	for type_id in _ordered_floor_type_ids_on_board(gameplay):
		if restrict and not restrict_types.has(type_id):
			continue
		var type_row := _floor_type_row(type_id)
		if not type_row.is_valid():
			continue
		var triggers := _triggers_node(type_row)
		if not triggers.is_valid() or triggers.get_type() != GnosisValueType.LIST:
			continue
		var match_cells := _count_cells_with_floor(gameplay, type_id)
		if match_cells <= 0:
			continue
		for i in triggers.get_count():
			var trigger := triggers.get_node(i)
			if not trigger.is_valid():
				continue
			if _node_str(trigger, "when").to_lower() != WHEN_MOVE_FINALIZE:
				continue
			var effects := trigger.get_node("effects")
			if not effects.is_valid() or effects.get_type() != GnosisValueType.LIST:
				continue
			for e in range(effects.get_count()):
				var effect := effects.get_node(e)
				if not effect.is_valid() or not _random_passes(effect, _gameplay_rng()):
					continue
				if _node_str(effect, "kind").to_lower() != "add_finalize_score_points":
					continue
				var amount := _node_int(effect, "amount", 0)
				if amount == 0:
					continue
				var per_cell := _node_bool(effect, "scaleByMatchingCells", false)
				delta += amount * match_cells if per_cell else amount
	return delta


func _finalize_multi_multiplier(gameplay, multi: float, restrict_types: Array[String]) -> Dictionary:
	var result := multi
	var steps: Array = []
	var restrict := not restrict_types.is_empty()
	for type_id in _ordered_floor_type_ids_on_board(gameplay):
		if restrict and not restrict_types.has(type_id):
			continue
		var type_row := _floor_type_row(type_id)
		if not type_row.is_valid():
			continue
		var triggers := _triggers_node(type_row)
		if not triggers.is_valid() or triggers.get_type() != GnosisValueType.LIST:
			continue
		var match_cells := _enumerate_cells_with_floor(gameplay, type_id)
		if match_cells.is_empty():
			continue
		for i in triggers.get_count():
			var trigger := triggers.get_node(i)
			if not trigger.is_valid():
				continue
			if _node_str(trigger, "when").to_lower() != WHEN_MOVE_FINALIZE:
				continue
			var effects := trigger.get_node("effects")
			if not effects.is_valid() or effects.get_type() != GnosisValueType.LIST:
				continue
			for e in range(effects.get_count()):
				var effect := effects.get_node(e)
				if not effect.is_valid() or not _random_passes(effect, _gameplay_rng()):
					continue
				if _node_str(effect, "kind").to_lower() != "multiply_finalize_score_multi_total":
					continue
				var factor := _read_effect_float(effect, "factorPerMatchingCell", 1.0)
				if is_equal_approx(factor, 1.0):
					continue
				for coord in match_cells:
					var before := result
					result *= factor
					var multi_delta := int(round(result - before))
					if multi_delta == 0:
						continue
					steps.append({
						"floorTypeId": type_id,
						"x": coord.x,
						"y": coord.y,
						"multiDelta": multi_delta,
						"multiDisplayText": FloatTextScript.build_for_multi_op("multiply", factor),
						"multiDisplayOp": "multiply",
						"multiDisplayFactor": factor,
					})
					if _service != null and _service.has_method("apply_cell_floor_finalize_echo"):
						var echo_out: Dictionary = _service.call(
							"apply_cell_floor_finalize_echo",
							type_id,
							0,
							int(round(result))
						)
						result = maxf(1.0, float(echo_out.get("multi", int(round(result)))))
	return {"multi": result, "steps": steps}


func _record_floor_pop(
	match_result: Models.MatchResult,
	coord: Models.TileCoord,
	points: int,
	multi: int,
	money: int
) -> void:
	if points == 0 and multi == 0 and money == 0:
		return
	match_result.floor_float_pops.append({
		"x": coord.x,
		"y": coord.y,
		"pointsDelta": points,
		"multiDelta": multi,
		"moneyDelta": money,
	})


func _record_lucky_successful_trigger(floor_type_id: String, match_result: Models.MatchResult) -> void:
	if match_result == null or floor_type_id.strip_edges().to_lower() != "lucky":
		return
	match_result.cell_floor_lucky_successful_trigger_count += 1


func _record_floor_cleared(match_result: Models.MatchResult, coord: Models.TileCoord) -> void:
	for entry in match_result.floor_cells_cleared:
		if int(entry.get("x", -1)) == coord.x and int(entry.get("y", -1)) == coord.y:
			return
	match_result.floor_cells_cleared.append({"x": coord.x, "y": coord.y})


func _consume_pool_slot(floor_type_id: String) -> void:
	if _service == null or _service.context == null or _service.context.store == null:
		return
	var m3 := _service.get_node("match3", false)
	if not m3.is_valid():
		return
	var pool := m3.get_node(PoolScript.POOL_KEY)
	if not pool.is_valid():
		return
	PoolScript.consume_one_from_pool(pool, floor_type_id)


func _add_currency(currency_id: String, amount: int) -> void:
	if amount <= 0 or _service == null or _service.context == null or _service.context.engine == null:
		return
	var currency = _service.context.engine.get_service("Currency")
	if currency and currency.has_method("add_currency"):
		currency.add_currency(currency_id, amount)


func _floor_modifiers_disabled() -> bool:
	if _service and _service.has_method("are_cell_floor_modifiers_disabled"):
		return bool(_service.call("are_cell_floor_modifiers_disabled"))
	return false


func _gameplay_rng() -> RandomNumberGenerator:
	if _service and _service.has_method("get_gameplay"):
		var gameplay = _service.get_gameplay()
		if gameplay and gameplay.get("_rng") != null:
			return gameplay._rng
	return RandomNumberGenerator.new()


func _floor_type_row(type_id: String) -> GnosisNode:
	if _service == null:
		return GnosisNode.new(null)
	var config := _service.get_node("configuration", true)
	if not config.is_valid():
		return GnosisNode.new(null)
	var root := config.get_node("match3CellFloorTypes")
	if not root.is_valid():
		return GnosisNode.new(null)
	return root.get_node(type_id.strip_edges())


func _triggers_node(type_row: GnosisNode) -> GnosisNode:
	var props := type_row.get_node("properties")
	if not props.is_valid():
		return GnosisNode.new(null)
	return props.get_node("triggers")


func _ordered_floor_type_ids_on_board(gameplay) -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			var tid: String = tile.cell_floor_type_id.strip_edges()
			if tid.is_empty() or seen.has(tid.to_lower()):
				continue
			seen[tid.to_lower()] = true
			out.append(tid)
	out.sort()
	return out


func _count_cells_with_floor(gameplay, type_id: String) -> int:
	return _enumerate_cells_with_floor(gameplay, type_id).size()


func _enumerate_cells_with_floor(gameplay, type_id: String) -> Array[Models.TileCoord]:
	var out: Array[Models.TileCoord] = []
	var needle := type_id.strip_edges().to_lower()
	if needle.is_empty():
		return out
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			if tile.cell_floor_type_id.strip_edges().to_lower() == needle:
				out.append(Models.TileCoord.new(x, y))
	return out


func on_griefing_pre_score(
	tile: Models.Match3TileData,
	coord: Models.TileCoord,
	match_result: Models.MatchResult
) -> void:
	BoardScript.try_apply_griefing_pre_score_enhanced_floor(_service, tile, coord, match_result)


func _play_type_sfx(type_row: GnosisNode, key: String) -> void:
	if _service == null or not type_row.is_valid():
		return
	if _service.has_method("play_cell_floor_type_sfx"):
		_service.call("play_cell_floor_type_sfx", type_row, key)


static func _random_passes(effect: GnosisNode, rng: RandomNumberGenerator) -> bool:
	if not effect.is_valid():
		return true
	var one_in_node := effect.get_node("oneIn")
	if one_in_node.is_valid() and one_in_node.value != null:
		var one_in := maxi(1, int(one_in_node.value))
		return rng.randi_range(0, one_in - 1) == 0
	var chance_node := effect.get_node("chance")
	if chance_node.is_valid() and chance_node.value != null:
		var p := float(chance_node.value)
		if p >= 1.0:
			return true
		if p <= 0.0:
			return false
		return rng.randf() < p
	return true


static func _read_effect_float(effect: GnosisNode, key: String, default_value: float) -> float:
	if not effect.is_valid():
		return default_value
	var node := effect.get_node(key)
	if not node.is_valid() or node.value == null:
		return default_value
	return float(node.value)


static func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return str(child.value).strip_edges()
	return default_value


static func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return int(child.value)
	return default_value


static func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return bool(child.value)
	return default_value
