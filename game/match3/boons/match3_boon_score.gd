class_name Match3BoonScore
extends RefCounted

## Data-driven boon scoreCalculations (finalize + resolve_step; Unity Policy.Score parity core).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const EchoesScript = preload("res://game/match3/boons/match3_boon_contribution_echoes.gd")
const JuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
const DisplayTextScript = preload("res://game/match3/view/match3_score_floating_display_text.gd")
const TopologyScript = preload("res://game/match3/core/match3_match_topology.gd")

const SCORE_CALC_TRIGGER_ITEM_DESTROYED := "item_destroyed"
const SCORE_CALC_TRIGGER_MATCH_COMPONENT := "match_component"
const CONTRIBUTION_LIST_FINALIZE := "boonFinalizeSteps"
const CONTRIBUTION_LIST_RESOLVE := "boonResolveSteps"

var _service: GnosisService
var _rng := RandomNumberGenerator.new()
var _resolve_step_payload: GnosisNode = GnosisNode.new(null)
var _pending_finalize_echo_steps: Array = []


func _init(service: GnosisService) -> void:
	_service = service


func begin_resolve_step(step, results: Array, points: int, multi: int, destroyed_count: int) -> void:
	if _service.context == null or _service.context.store == null:
		_resolve_step_payload = GnosisNode.new(null)
		return
	var points_sv := SupportScript.scalable_from_int(points)
	var multi_sv := SupportScript.scalable_from_int(maxi(1, multi))
	_resolve_step_payload = _build_score_finalize_payload(
		points_sv,
		multi_sv,
		maxi(0, destroyed_count),
		results if results.size() > 0 else [step]
	)
	_ensure_contribution_list(_resolve_step_payload, CONTRIBUTION_LIST_RESOLVE)


func apply_item_destroyed(
	item_id: String,
	_step,
	results: Array,
	points: int,
	multi: int,
	destroyed_count: int
) -> Dictionary:
	var trimmed := item_id.strip_edges()
	var is_cold := SupportScript.is_cold_palette_item_id(trimmed)
	var is_warm := SupportScript.is_warm_palette_item_id(trimmed)
	if not is_cold and not is_warm:
		return {"points": points, "multi": multi}
	if _resolve_step_payload == null or not _resolve_step_payload.is_valid():
		begin_resolve_step(_step, results, points, multi, destroyed_count)
	_refresh_resolve_step_score_payload(points, multi, destroyed_count, [_step])
	var score := _resolve_step_payload.get_node("score")
	score.set_key("lastDestroyedItemId", trimmed)
	score.set_key("lastDestroyedIsCold", 1 if is_cold else 0)
	score.set_key("lastDestroyedIsWarm", 1 if is_warm else 0)
	_run_resolve_step_calcs(
		_resolve_step_payload,
		true,
		1 if is_cold else -1,
		1 if is_warm else -1,
		_step,
		true
	)
	return _totals_from_payload(_resolve_step_payload, points, multi)


func apply_match_components(
	step,
	results: Array,
	points: int,
	multi: int,
	destroyed_count: int
) -> Dictionary:
	if step == null or not ("topology_components" in step) or step.topology_components.is_empty():
		return {"points": points, "multi": multi}
	if _resolve_step_payload == null or not _resolve_step_payload.is_valid():
		begin_resolve_step(step, results, points, multi, destroyed_count)
	var out_points := points
	var out_multi := multi
	for topo in step.topology_components:
		if not (topo is Dictionary):
			continue
		var counts := TopologyScript.increment_axis_straight_line_run_counts(str(topo.get("shapeKind", "")))
		if int(counts.get("match3", 0)) == 0 and int(counts.get("match4", 0)) == 0 and int(counts.get("match5", 0)) == 0:
			continue
		_refresh_resolve_step_score_payload(out_points, out_multi, destroyed_count, [step])
		var score := _resolve_step_payload.get_node("score")
		score.set_key("lastAxisStraightMatch3", int(counts.get("match3", 0)))
		score.set_key("lastAxisStraightMatch4", int(counts.get("match4", 0)))
		score.set_key("lastAxisStraightMatch5OrLonger", int(counts.get("match5", 0)))
		_run_match_component_calcs(
			int(counts.get("match3", 0)),
			int(counts.get("match4", 0)),
			int(counts.get("match5", 0)),
			step
		)
		var totals := _totals_from_payload(_resolve_step_payload, out_points, out_multi)
		out_points = int(totals.get("points", out_points))
		out_multi = maxi(1, int(totals.get("multi", out_multi)))
	return {"points": out_points, "multi": out_multi}


func apply_cell_floor_finalize_echo(floor_type_id: String, points: int, multi: int) -> Dictionary:
	if _service.context == null or _service.context.store == null:
		return {"points": points, "multi": multi}
	var points_sv := SupportScript.scalable_from_int(points)
	var multi_sv := SupportScript.scalable_from_int(maxi(1, multi))
	var payload := _build_score_finalize_payload(points_sv, multi_sv, 0, [])
	_ensure_contribution_list(payload, CONTRIBUTION_LIST_FINALIZE)
	EchoesScript.try_apply_after_cell_floor_finalize(
		_service,
		self,
		payload,
		floor_type_id,
		CONTRIBUTION_LIST_FINALIZE
	)
	_pending_finalize_echo_steps.append_array(_copy_contribution_steps(payload, CONTRIBUTION_LIST_FINALIZE))
	return _totals_from_payload(payload, points, multi)


func apply_resolve_step_cascade(
	step,
	results: Array,
	points: int,
	multi: int,
	destroyed_count: int
) -> Dictionary:
	if _resolve_step_payload == null or not _resolve_step_payload.is_valid():
		begin_resolve_step(step, results, points, multi, destroyed_count)
	else:
		_refresh_resolve_step_score_payload(points, multi, destroyed_count, [step])
	var component_totals := apply_match_components(step, results, points, multi, destroyed_count)
	points = int(component_totals.get("points", points))
	multi = maxi(1, int(component_totals.get("multi", multi)))
	_refresh_resolve_step_score_payload(points, multi, destroyed_count, [step])
	ScalingScript.apply_resolve_step_scaling_increments(_service, self, step, points, multi)
	_run_resolve_step_calcs(_resolve_step_payload, false, -1, -1, step, false)
	var resolve_steps := _copy_contribution_steps(_resolve_step_payload, CONTRIBUTION_LIST_RESOLVE)
	var totals := _totals_from_payload(_resolve_step_payload, points, multi)
	_resolve_step_payload = GnosisNode.new(null)
	var resolved_points := int(totals.get("points", points))
	if resolved_points <= 0 and points > 0:
		resolved_points = points
	var resolved_multi := maxi(1, int(totals.get("multi", multi)))
	return {
		"points": resolved_points,
		"multi": resolved_multi,
		"boon_resolve_steps": resolve_steps,
	}


## Called from Match3Gameplay before final move score is computed.
func apply_finalize_for_move(results: Array, points: int, multi: int) -> Dictionary:
	if _service.context == null or _service.context.store == null or results.is_empty():
		return {"points": points, "multi": multi}
	var points_sv := SupportScript.scalable_from_int(points)
	var multi_sv := SupportScript.scalable_from_int(maxi(1, multi))
	var destroyed := _count_destroyed(results)
	var payload := _build_score_finalize_payload(points_sv, multi_sv, destroyed, results)
	var score := payload.get_node("score")
	if score.is_valid():
		score.set_key("pointsTotal", maxi(0, points))
		score.set_key("multiTotal", maxi(1, multi))
		score.set_key(
			"steelFinalizeStepCount",
			_count_cell_floor_finalize_steps_for_type(results, "Steel")
		)
	_ensure_contribution_list(payload, CONTRIBUTION_LIST_FINALIZE)
	_run_finalize_calcs(payload)
	var finalize_steps := _copy_contribution_steps(payload, CONTRIBUTION_LIST_FINALIZE)
	finalize_steps.append_array(_pending_finalize_echo_steps)
	_pending_finalize_echo_steps.clear()
	var scoring_result = _last_scoring_match_result(results)
	if scoring_result != null and "boon_finalize_steps" in scoring_result:
		scoring_result.boon_finalize_steps = finalize_steps
	return _totals_from_payload(payload, points, multi)


func _apply_echo_outcomes(
	echo: GnosisNode,
	payload: GnosisNode,
	listener_boon_id: String,
	listener_slot_index: int,
	echo_id: String,
	contribution_list_key: String
) -> void:
	if echo == null or not echo.is_valid() or payload == null or not payload.is_valid():
		return
	var merged := _merge_calc_parameters_with_optional_boon_slot(echo.get_node("parameters"), GnosisNode.new(null))
	_apply_score_calc_outcomes(
		echo.get_node("outcomes"),
		payload,
		merged,
		listener_boon_id,
		listener_slot_index,
		echo_id,
		GnosisNode.new(null),
		contribution_list_key,
		-1,
		-1,
		-1,
		-1,
		-1,
		true,
		false
	)


func _run_finalize_calcs(payload: GnosisNode) -> void:
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
				CONTRIBUTION_LIST_FINALIZE,
				-1,
				-1,
				-1,
				-1,
				-1,
				false,
				true
			)


func _run_resolve_step_calcs(
	payload: GnosisNode,
	item_destroyed_only: bool,
	cold_bind: int,
	warm_bind: int,
	step,
	prefer_immediate_juice: bool
) -> void:
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
			if phase != "resolve_step" and phase != "step" and phase != "cascade_step":
				continue
			var uses_item_destroyed := _score_calc_uses_trigger(calc, SCORE_CALC_TRIGGER_ITEM_DESTROYED)
			var uses_match_component := _score_calc_uses_trigger(calc, SCORE_CALC_TRIGGER_MATCH_COMPONENT)
			if item_destroyed_only:
				if not uses_item_destroyed:
					continue
			else:
				if uses_item_destroyed or uses_match_component:
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
				CONTRIBUTION_LIST_RESOLVE,
				cold_bind,
				warm_bind,
				-1,
				-1,
				-1,
				prefer_immediate_juice,
				true
			)
	if step != null and "boon_resolve_steps" in step:
		step.boon_resolve_steps = _copy_contribution_steps(payload, CONTRIBUTION_LIST_RESOLVE)


func _run_match_component_calcs(axis3: int, axis4: int, axis5: int, step) -> void:
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
			if phase != "resolve_step" and phase != "step" and phase != "cascade_step":
				continue
			if not _score_calc_uses_trigger(calc, SCORE_CALC_TRIGGER_MATCH_COMPONENT):
				continue
			var merged_params := _merge_calc_parameters_with_optional_boon_slot(calc.get_node("parameters"), slot_entry)
			var calculation_id := SupportScript._node_str(calc, "id")
			if not _evaluate_score_calc_when(calc, _resolve_step_payload, merged_params, slot_entry, calculation_id):
				continue
			_apply_score_calc_outcomes(
				calc.get_node("outcomes"),
				_resolve_step_payload,
				merged_params,
				boon_id,
				slot_index,
				calculation_id,
				slot_entry,
				CONTRIBUTION_LIST_RESOLVE,
				-1,
				-1,
				axis3,
				axis4,
				axis5,
				false,
				true
			)
	if step != null and "boon_resolve_steps" in step:
		step.boon_resolve_steps = _copy_contribution_steps(_resolve_step_payload, CONTRIBUTION_LIST_RESOLVE)


static func _count_cell_floor_finalize_steps_for_type(results: Array, floor_type_id: String) -> int:
	var needle := floor_type_id.strip_edges().to_lower()
	if needle.is_empty():
		return 0
	var count := 0
	for entry in results:
		if entry == null or not ("cell_floor_finalize_steps" in entry):
			continue
		for step in entry.cell_floor_finalize_steps:
			if str(step.get("floorTypeId", "")).strip_edges().to_lower() == needle:
				count += 1
	return count


func _build_score_finalize_payload(points_total: GnosisScalableValue, multi_total: GnosisScalableValue, destroyed_count: int, results: Array) -> GnosisNode:
	var store := _service.context.store
	var payload := store.create_object()
	var score := store.create_object()
	score.set_key("pointsTotal", SupportScript.scalable_to_move_int(points_total))
	score.set_key("multiTotal", maxi(1, SupportScript.scalable_to_move_int(multi_total)))
	score.set_key("destroyedCount", maxi(0, destroyed_count))
	score.set_key("movesRemaining", maxi(0, _service.get_gameplay().current_moves))
	score.set_key("movesPerformedThisRound", maxi(0, _service.get_gameplay().moves_performed))
	score.set_key("isFirstMoveOfRound", 1 if _service.get_gameplay().moves_performed == 1 else 0)
	var axis_counts := _accumulate_axis_straight_line_match_counts(results)
	score.set_key("axisStraightMatch3Count", axis_counts.get("match3", 0))
	score.set_key("hasTwoAxisStraightMatch3", 1 if int(axis_counts.get("match3", 0)) >= 2 else 0)
	score.set_key("axisStraightMatch4Count", axis_counts.get("match4", 0))
	score.set_key("axisStraightMatch5OrLongerCount", axis_counts.get("match5", 0))
	score.set_key("hasAxisMatch3", 1 if axis_counts.get("match3", 0) > 0 else 0)
	score.set_key("hasAxisMatch4", 1 if axis_counts.get("match4", 0) > 0 else 0)
	score.set_key("hasAxisMatch5", 1 if axis_counts.get("match5", 0) > 0 else 0)
	_apply_topology_counts_to_score_node(score, results)
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	payload.set_key("boons", SupportScript.build_active_boons_context_node(store, slot_rows))
	payload.set_key("score", score)
	_apply_scoring_destroy_counts_to_score_node(score, results)
	_apply_cell_floor_lucky_trigger_count(score, results)
	return payload


func _refresh_resolve_step_score_payload(points: int, multi: int, destroyed_count: int, results: Array) -> void:
	if _resolve_step_payload == null or not _resolve_step_payload.is_valid():
		return
	var score := _resolve_step_payload.get_node("score")
	if not score.is_valid():
		return
	score.set_key("pointsTotal", points)
	score.set_key("multiTotal", maxi(1, multi))
	score.set_key("destroyedCount", maxi(0, destroyed_count))
	_apply_scoring_destroy_counts_to_score_node(score, results)
	_apply_topology_counts_to_score_node(score, results)


static func _apply_topology_counts_to_score_node(score: GnosisNode, results: Array) -> void:
	if score == null or not score.is_valid():
		return
	var topology5 := TopologyScript.count_match5_plus_components(results)
	score.set_key("topologyMatch5PlusComponentCount", topology5)
	score.set_key("hasTopologyMatch5Plus", 1 if topology5 > 0 else 0)
	var intersection := TopologyScript.accumulate_intersection_five_tile_shape_counts(results)
	var l_count := int(intersection.get("l", 0))
	var t_count := int(intersection.get("t", 0))
	var plus_count := int(intersection.get("plus", 0))
	score.set_key("intersectionLShape5Count", l_count)
	score.set_key("intersectionTShape5Count", t_count)
	score.set_key("intersectionPlusShape5Count", plus_count)
	score.set_key("hasIntersectionLShape5", 1 if l_count > 0 else 0)
	score.set_key("hasIntersectionTShape5", 1 if t_count > 0 else 0)
	score.set_key("hasIntersectionPlusShape5", 1 if plus_count > 0 else 0)


static func _last_scoring_match_result(results: Array):
	for i in range(results.size() - 1, -1, -1):
		var entry = results[i]
		if entry != null and "matched_tiles" in entry and not entry.matched_tiles.is_empty():
			return entry
	return null


func _totals_from_payload(payload: GnosisNode, fallback_points: int, fallback_multi: int) -> Dictionary:
	if payload == null or not payload.is_valid():
		return {"points": fallback_points, "multi": maxi(1, fallback_multi)}
	var score := payload.get_node("score")
	return {
		"points": maxi(0, int(round(_read_score_move_number(score, "pointsTotal", float(fallback_points))))),
		"multi": maxi(1, int(round(_read_score_move_number(score, "multiTotal", float(maxi(1, fallback_multi)))))),
	}


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
	contribution_list_key: String = "",
	cold_bind: int = -1,
	warm_bind: int = -1,
	axis3_bind: int = -1,
	axis4_bind: int = -1,
	axis5_bind: int = -1,
	prefer_immediate_juice: bool = false,
	trigger_contribution_echoes: bool = true,
) -> void:
	if outcomes == null or not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST:
		return
	var bind := _make_binding_func(payload, parameters, cold_bind, warm_bind, axis3_bind, axis4_bind, axis5_bind)
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
		var x = GnosisScoreExpr.try_evaluate_double(expr, bind, _rng)
		if x == null:
			continue
		var score := payload.get_node("score")
		var points_before := _read_score_move_number(score, "pointsTotal", 0.0)
		var multi_before := _read_score_move_number(score, "multiTotal", 1.0)
		var points_display := ""
		var multi_display := ""
		if target.to_lower() == "score.pointstotal":
			if op == "add":
				_set_score_move_number(score, "pointsTotal", points_before + float(x))
				points_display = DisplayTextScript.build_points_add(int(round(x)))
			elif op == "multiply":
				_set_score_move_number(score, "pointsTotal", maxf(0.0, points_before * float(x)))
				points_display = DisplayTextScript.build_for_multi_op(op, float(x))
		elif target.to_lower() == "score.multitotal":
			if op == "add":
				_set_score_move_number(score, "multiTotal", multi_before + float(x))
				if absf(float(x) - round(float(x))) < 1e-6:
					multi_display = DisplayTextScript.build_multi_add(int(round(x)))
				else:
					multi_display = "+%s" % str(snapped(float(x), 0.1))
			elif op == "multiply":
				_set_score_move_number(score, "multiTotal", maxf(1.0, multi_before * float(x)))
				multi_display = DisplayTextScript.build_for_multi_op(op, float(x))
		elif target.to_lower() == "score.destroyedcount":
			var cur_d := SupportScript._node_int(score, "destroyedCount", 0)
			var val := int(round(x))
			if op == "add":
				score.set_key("destroyedCount", cur_d + val)
			elif op == "multiply":
				score.set_key("destroyedCount", maxi(0, cur_d * val))
		var points_after := _read_score_move_number(score, "pointsTotal", points_before)
		var multi_after := _read_score_move_number(score, "multiTotal", multi_before)
		var pts_delta := int(round(points_after - points_before))
		var multi_delta := int(round(multi_after - multi_before))
		if (
			not contribution_list_key.is_empty()
			and (
				pts_delta != 0
				or multi_delta != 0
				or not points_display.is_empty()
				or not multi_display.is_empty()
			)
		):
			_append_contribution_step(
				payload,
				contribution_list_key,
				boon_id,
				boon_slot_index,
				calculation_id,
				pts_delta,
				multi_delta,
				points_display,
				multi_display
			)
			if prefer_immediate_juice:
				var kind := JuiceScript.KIND_POINTS
				var display := points_display
				if not multi_display.is_empty():
					kind = JuiceScript.KIND_MULTI
					display = multi_display
				elif multi_delta != 0 and display.is_empty():
					kind = JuiceScript.KIND_MULTI
					display = DisplayTextScript.build_multi_add(multi_delta)
				JuiceScript.publish_score_juice(_service, boon_slot_index, kind, display)
			if trigger_contribution_echoes:
				EchoesScript.try_apply_after_boon_score_step(
					_service,
					self,
					payload,
					boon_id,
					boon_slot_index,
					contribution_list_key
				)


func _append_contribution_step(
	payload: GnosisNode,
	list_key: String,
	boon_id: String,
	slot_index: int,
	calculation_id: String,
	points_delta: int,
	multi_delta: int,
	points_display: String,
	multi_display: String
) -> void:
	var list := _ensure_contribution_list(payload, list_key)
	var step := _service.context.store.create_object()
	step.set_key("boonId", boon_id)
	step.set_key("slotIndex", slot_index)
	step.set_key("calculationId", calculation_id)
	step.set_key("pointsDelta", points_delta)
	step.set_key("multiDelta", multi_delta)
	step.set_key("pointsDisplayText", points_display)
	step.set_key("multiDisplayText", multi_display)
	list.add(step)


func _ensure_contribution_list(payload: GnosisNode, list_key: String) -> GnosisNode:
	var list := payload.get_node(list_key)
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		list = _service.context.store.create_list()
		payload.set_node(list_key, list)
	return list


func _copy_contribution_steps(payload: GnosisNode, list_key: String) -> Array:
	var out: Array = []
	if payload == null or not payload.is_valid():
		return out
	var list := payload.get_node(list_key)
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return out
	for i in list.get_count():
		var step := list.get_node(i)
		if not step.is_valid():
			continue
		out.append({
			"boonId": SupportScript._node_str(step, "boonId"),
			"slotIndex": SupportScript._node_int(step, "slotIndex", 0),
			"calculationId": SupportScript._node_str(step, "calculationId"),
			"pointsDelta": SupportScript._node_int(step, "pointsDelta", 0),
			"multiDelta": SupportScript._node_int(step, "multiDelta", 0),
			"pointsDisplayText": SupportScript._node_str(step, "pointsDisplayText"),
			"multiDisplayText": SupportScript._node_str(step, "multiDisplayText"),
		})
	return out


func _make_binding_func(
	payload: GnosisNode,
	parameters: GnosisNode,
	cold_bind: int,
	warm_bind: int,
	axis3_bind: int = -1,
	axis4_bind: int = -1,
	axis5_bind: int = -1
) -> Callable:
	return func(path: String) -> float:
		var normalized := path.strip_edges().to_lower()
		if cold_bind >= 0 and normalized.ends_with("colddestroyedcount"):
			return float(cold_bind)
		if warm_bind >= 0 and normalized.ends_with("warmdestroyedcount"):
			return float(warm_bind)
		if axis3_bind >= 0 and normalized.ends_with("axisstraightmatch3count"):
			return float(axis3_bind)
		if axis4_bind >= 0 and normalized.ends_with("axisstraightmatch4count"):
			return float(axis4_bind)
		if axis5_bind >= 0 and (
			normalized.ends_with("axisstraightmatch5orlongercount")
			or normalized.ends_with("axisstraightmatch5count")
		):
			return float(axis5_bind)
		return _resolve_score_expr_binding(path, payload, parameters)


func _score_calc_uses_trigger(calc: GnosisNode, trigger_id: String) -> bool:
	var parameters := calc.get_node("parameters")
	if not parameters.is_valid() or parameters.get_type() != GnosisValueType.OBJECT:
		return false
	return SupportScript._node_str(parameters, "trigger").to_lower() == trigger_id.to_lower()


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


func _read_score_move_number(score: GnosisNode, key: String, fallback: float) -> float:
	if score == null or not score.is_valid():
		return fallback
	return _read_score_move_number_node(score.get_node(key), fallback)


func _read_score_move_number_node(node: GnosisNode, fallback: float) -> float:
	if node == null or not node.is_valid():
		return fallback
	match node.get_type():
		GnosisValueType.INT, GnosisValueType.LONG:
			return float(node.value)
		GnosisValueType.FLOAT:
			return float(node.value)
		GnosisValueType.OBJECT:
			return float(SupportScript.scalable_to_move_int(SupportScript.read_scalable_node(node)))
		_:
			return fallback


func _set_score_move_number(score: GnosisNode, key: String, value: float) -> void:
	if score == null or not score.is_valid():
		return
	if absf(value - round(value)) < 1e-6:
		score.set_key(key, int(round(value)))
	else:
		score.set_key(key, float(value))


func _read_score_move_int(score: GnosisNode, key: String, fallback: int) -> int:
	return int(round(_read_score_move_number(score, key, float(fallback))))


func _set_score_move_int(score: GnosisNode, key: String, value: int) -> void:
	_set_score_move_number(score, key, float(value))
