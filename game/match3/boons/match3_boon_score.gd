class_name Match3BoonScore
extends RefCounted

## Data-driven boon scoreCalculations (finalize phase; Unity Policy.Score parity core).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

var _service: GnosisService
var _rng := RandomNumberGenerator.new()


func _init(service: GnosisService) -> void:
	_service = service


## Called from Match3Gameplay before final move score is computed.
func apply_finalize_for_move(results: Array, points: int, multi: int) -> Dictionary:
	if _service.context == null or _service.context.store == null or results.is_empty():
		return {"points": points, "multi": multi}
	var points_sv := SupportScript.scalable_from_int(points)
	var multi_sv := SupportScript.scalable_from_int(maxi(1, multi))
	var destroyed := _count_destroyed(results)
	var payload := _build_score_finalize_payload(points_sv, multi_sv, destroyed, results)
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	for slot_index in range(slot_rows.size()):
		var slot_entry: GnosisNode = slot_rows[slot_index]
		var boon_id := SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry)
		if boon_id.is_empty():
			continue
		var calcs := slot_entry.get_node("properties").get_node("scoreCalculations")
		if not calcs.is_valid() or calcs.get_type() != GnosisValueType.LIST:
			continue
		for i in range(calcs.get_count()):
			var calc := calcs.get_node(i)
			if not calc.is_valid() or calc.get_type() != GnosisValueType.OBJECT:
				continue
			var phase := SupportScript._node_str(calc, "phase", "finalize").to_lower()
			if phase != "finalize":
				continue
			var merged_params := _merge_calc_parameters_with_optional_boon_slot(calc.get_node("parameters"), slot_entry)
			var calculation_id := SupportScript._node_str(calc, "id")
			if not _evaluate_score_calc_when(calc, payload, merged_params, slot_entry, calculation_id):
				continue
			_apply_score_calc_outcomes(
				calc.get_node("outcomes"),
				payload,
				merged_params,
				boon_id,
				slot_index,
				calculation_id,
				slot_entry,
			)
	points_sv = SupportScript.read_scalable_node(payload.get_node("score").get_node("pointsTotal"), points_sv)
	multi_sv = SupportScript.read_scalable_node(payload.get_node("score").get_node("multiTotal"), multi_sv)
	return {
		"points": maxi(0, SupportScript.scalable_to_move_int(points_sv)),
		"multi": maxi(1, SupportScript.scalable_to_move_int(multi_sv)),
	}


func _build_score_finalize_payload(points_total: GnosisScalableValue, multi_total: GnosisScalableValue, destroyed_count: int, results: Array) -> GnosisNode:
	var store := _service.context.store
	var payload := store.create_object()
	var score := store.create_object()
	score.set_key("pointsTotal", SupportScript.write_scalable_node(store, points_total))
	score.set_key("multiTotal", SupportScript.write_scalable_node(store, multi_total))
	score.set_key("destroyedCount", maxi(0, destroyed_count))
	score.set_key("movesRemaining", maxi(0, _service.get_gameplay().current_moves))
	score.set_key("movesPerformedThisRound", maxi(0, _service.get_gameplay().moves_performed))
	score.set_key("isFirstMoveOfRound", 1 if _service.get_gameplay().moves_performed == 1 else 0)
	var axis_counts := _accumulate_axis_straight_line_match_counts(results)
	score.set_key("axisStraightMatch3Count", axis_counts.get("match3", 0))
	score.set_key("axisStraightMatch4Count", axis_counts.get("match4", 0))
	score.set_key("axisStraightMatch5OrLongerCount", axis_counts.get("match5", 0))
	score.set_key("hasAxisMatch3", 1 if axis_counts.get("match3", 0) > 0 else 0)
	score.set_key("hasAxisMatch4", 1 if axis_counts.get("match4", 0) > 0 else 0)
	score.set_key("hasAxisMatch5", 1 if axis_counts.get("match5", 0) > 0 else 0)
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	payload.set_key("boons", SupportScript.build_active_boons_context_node(store, slot_rows))
	payload.set_key("score", score)
	_apply_scoring_destroy_counts_to_score_node(score, results)
	_apply_cell_floor_lucky_trigger_count(score, results)
	return payload


static func _apply_cell_floor_lucky_trigger_count(score: GnosisNode, results: Array) -> void:
	if score == null or not score.is_valid():
		return
	var lucky := 0
	for step in results:
		if step == null:
			continue
		if "cell_floor_lucky_successful_trigger_count" in step:
			lucky += int(step.cell_floor_lucky_successful_trigger_count)
	score.set_key("cellFloorLuckySuccessfulTriggerCount", maxi(0, lucky))


func _apply_scoring_destroy_counts_to_score_node(score: GnosisNode, results: Array) -> void:
	if score == null or not score.is_valid():
		return
	var store := _service.context.store
	var destroyed_by_item_id := store.create_object()
	var counters: Dictionary = {}
	for step in results:
		if step == null:
			continue
		var contribs: Array = step.contributions if "contributions" in step else []
		for c in contribs:
			if c is Dictionary:
				var pts := int(c.get("pointsAdded", 0))
				var mul := int(c.get("multiAdded", 0))
				if pts <= 0 and mul <= 0:
					continue
				var item_id := str(c.get("itemId", "")).strip_edges()
				if item_id.is_empty():
					continue
				counters[item_id.to_lower()] = int(counters.get(item_id.to_lower(), 0)) + 1
	for key in counters.keys():
		destroyed_by_item_id.set_key(str(key), int(counters[key]))
	score.set_key("destroyedByItemId", destroyed_by_item_id)
	score.set_key("destroyedDistinctItemIdCount", counters.size())
	score.set_key("coldDestroyedCount", _sum_palette_destroyed(counters, SupportScript.COLD_PALETTE_ITEM_IDS))
	score.set_key("warmDestroyedCount", _sum_palette_destroyed(counters, SupportScript.WARM_PALETTE_ITEM_IDS))


func _evaluate_score_calc_when(calc: GnosisNode, payload: GnosisNode, parameters: GnosisNode, slot_entry: GnosisNode, _calculation_id: String) -> bool:
	var when_node := calc.get_node("when")
	if not when_node.is_valid() or when_node.get_type() != GnosisValueType.STRING:
		return true
	var when := str(when_node.value).strip_edges()
	if when.is_empty():
		return true
	return GnosisScoreExpr.evaluate_condition(when, func(path: String) -> float: return _resolve_score_expr_binding(path, payload, parameters), _rng)


func _apply_score_calc_outcomes(
	outcomes: GnosisNode,
	payload: GnosisNode,
	parameters: GnosisNode,
	boon_id: String,
	boon_slot_index: int,
	calculation_id: String,
	slot_entry: GnosisNode,
) -> void:
	if outcomes == null or not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST:
		return
	for i in range(outcomes.get_count()):
		var outcome := outcomes.get_node(i)
		if outcome == null or not outcome.is_valid():
			continue
		var op := SupportScript._node_str(outcome, "op").to_lower()
		var target := SupportScript._node_str(outcome, "target")
		if op.is_empty() or target.is_empty():
			continue
		var expr := _read_expr_string(outcome.get_node("value"))
		if expr.is_empty():
			continue
		var x = GnosisScoreExpr.try_evaluate_double(expr, func(path: String) -> float: return _resolve_score_expr_binding(path, payload, parameters), _rng)
		if x == null:
			continue
		var score := payload.get_node("score")
		if target.to_lower() == "score.pointstotal":
			var cur := SupportScript.read_scalable_node(score.get_node("pointsTotal"))
			if op == "add":
				score.set_key("pointsTotal", SupportScript.write_scalable_node(_service.context.store, cur.add(GnosisScalableValue.from_int(int(round(x))))))
			elif op == "multiply":
				score.set_key("pointsTotal", SupportScript.write_scalable_node(_service.context.store, SupportScript.multiply_scalable_by_numeric_factor(cur, float(x))))
		elif target.to_lower() == "score.multitotal":
			var cur_m := SupportScript.read_scalable_node(score.get_node("multiTotal"))
			if op == "add":
				score.set_key("multiTotal", SupportScript.write_scalable_node(_service.context.store, cur_m.add(GnosisScalableValue.from_int(int(round(x))))))
			elif op == "multiply":
				score.set_key("multiTotal", SupportScript.write_scalable_node(_service.context.store, SupportScript.multiply_scalable_by_numeric_factor(cur_m, float(x))))
		elif target.to_lower() == "score.destroyedcount":
			var cur_d := SupportScript._node_int(score, "destroyedCount", 0)
			var val := int(round(x))
			if op == "add":
				score.set_key("destroyedCount", cur_d + val)
			elif op == "multiply":
				score.set_key("destroyedCount", maxi(0, cur_d * val))


func _resolve_score_expr_binding(path: String, payload: GnosisNode, parameters: GnosisNode) -> float:
	var node := _resolve_context_path(path.strip_edges(), payload, parameters)
	return _read_double(node, 0.0)


func _resolve_context_path(raw_path: String, payload: GnosisNode, parameters: GnosisNode) -> GnosisNode:
	var path := raw_path.strip_edges()
	if path.is_empty():
		return payload
	var parts := path.split(".")
	if parts.is_empty():
		return payload
	var idx := 0
	var cur: GnosisNode
	if parts[0].to_lower() == "payload":
		cur = payload
		idx = 1
	elif parts[0].to_lower() == "parameters":
		cur = parameters
		idx = 1
	elif parts[0].to_lower() == "ephemeral" and parts.size() > 1:
		cur = _service.get_node(parts[1], false)
		idx = 2
	elif parts[0].to_lower() == "persistent" and parts.size() > 1:
		cur = _service.get_node(parts[1], true)
		idx = 2
	else:
		cur = payload
	for i in range(idx, parts.size()):
		if cur == null or not cur.is_valid():
			return GnosisNode.new(null)
		cur = cur.get_node(parts[i])
	return cur


func _merge_calc_parameters_with_optional_boon_slot(calc_parameters: GnosisNode, boon_slot: GnosisNode) -> GnosisNode:
	var merged := _service.context.store.create_object()
	if calc_parameters != null and calc_parameters.is_valid() and calc_parameters.get_type() == GnosisValueType.OBJECT:
		for key in calc_parameters.get_keys():
			merged.set_key(str(key), calc_parameters.get_node(key))
	if boon_slot != null and boon_slot.is_valid() and boon_slot.get_type() == GnosisValueType.OBJECT:
		merged.set_key("boonSlot", boon_slot)
	return merged


func _count_destroyed(results: Array) -> int:
	var total := 0
	for step in results:
		if step == null:
			continue
		if "scoring_eligible_destroy_count" in step:
			total += maxi(0, int(step.scoring_eligible_destroy_count))
	return total


func _accumulate_axis_straight_line_match_counts(results: Array) -> Dictionary:
	var match3 := 0
	var match4 := 0
	var match5 := 0
	var counts := {"match3": match3, "match4": match4, "match5": match5}
	for step in results:
		if step == null or not ("matched_tiles" in step):
			continue
		var tiles: Array = step.matched_tiles
		if tiles.is_empty():
			continue
		var by_row: Dictionary = {}
		var by_col: Dictionary = {}
		for coord in tiles:
			var x := int(coord.x) if "x" in coord else 0
			var y := int(coord.y) if "y" in coord else 0
			if not by_row.has(y):
				by_row[y] = []
			if not by_col.has(x):
				by_col[x] = []
			(by_row[y] as Array).append(x)
			(by_col[x] as Array).append(y)
		for y in by_row.keys():
			_add_axis_run_counts(_sorted_int_array(by_row[y]), counts)
		for x in by_col.keys():
			_add_axis_run_counts(_sorted_int_array(by_col[x]), counts)
	return counts


func _add_axis_run_counts(sorted_coords: Array, counts: Dictionary) -> void:
	if sorted_coords.size() < 3:
		return
	var run_start := 0
	for i in range(1, sorted_coords.size() + 1):
		var contiguous := i < sorted_coords.size() and int(sorted_coords[i]) == int(sorted_coords[i - 1]) + 1
		if contiguous:
			continue
		var run_len := i - run_start
		if run_len >= 5:
			counts["match5"] = int(counts.get("match5", 0)) + 1
		elif run_len == 4:
			counts["match4"] = int(counts.get("match4", 0)) + 1
		elif run_len == 3:
			counts["match3"] = int(counts.get("match3", 0)) + 1
		run_start = i


func _sorted_int_array(values: Array) -> Array:
	var copy := values.duplicate()
	copy.sort()
	return copy


func _sum_palette_destroyed(counters: Dictionary, palette: Array[String]) -> int:
	var sum := 0
	for id in palette:
		sum += int(counters.get(id.to_lower(), 0))
	return sum


func _read_expr_string(node: GnosisNode) -> String:
	if node == null or not node.is_valid():
		return ""
	match node.get_type():
		GnosisValueType.STRING:
			return str(node.value)
		GnosisValueType.INT, GnosisValueType.LONG:
			return str(node.value)
		GnosisValueType.FLOAT:
			return str(node.value)
		_:
			return ""


func _read_double(node: GnosisNode, fallback: float) -> float:
	if node == null or not node.is_valid():
		return fallback
	match node.get_type():
		GnosisValueType.INT, GnosisValueType.LONG:
			return float(node.value)
		GnosisValueType.FLOAT:
			return float(node.value)
		GnosisValueType.STRING:
			return float(node.value) if str(node.value).is_valid_float() else fallback
		GnosisValueType.OBJECT:
			return SupportScript.read_scalable_node(node).to_float()
		_:
			return fallback
