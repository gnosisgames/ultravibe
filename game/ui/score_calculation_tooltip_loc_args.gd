class_name ScoreCalculationTooltipLocArgs
extends RefCounted

## Resolves scoreCalculationValue* named args for catalog/shop tooltips.
## Port of GnosisScoreCalculationTooltipLocArgs (Unity engine).

const SCORE_VALUE_PREFIX := "scoreCalculationValue"
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


static func resolve_for_catalog_entry(
	engine: GnosisEngine,
	config_section: String,
	catalog_item_id: String,
	entry: GnosisNode = GnosisNode.new(null),
	reroll_random_preview: bool = false,
) -> Dictionary:
	if engine == null or engine.state == null:
		return {}
	var section := config_section.strip_edges()
	var item_id := catalog_item_id.strip_edges()
	if section.is_empty() or item_id.is_empty():
		return {}
	if not entry.is_valid():
		entry = _read_catalog_entry(engine, section, item_id)
	if not entry.is_valid():
		return {}

	var calcs := _read_calcs_list(entry)
	var boon_slot := _build_catalog_boon_slot(engine, entry) if section == "boons" else GnosisNode.new(null)
	if (not calcs.is_valid() or calcs.get_count() == 0) and not _has_scaling_counters(boon_slot):
		return {}

	var args := {}
	if calcs.is_valid() and calcs.get_count() > 0:
		_append_preview_args(engine, calcs, boon_slot, item_id, reroll_random_preview, args)
	_append_scaling_counter_loc_args(boon_slot, args)
	return args


static func _append_preview_args(
	engine: GnosisEngine,
	calcs: GnosisNode,
	boon_slot: GnosisNode,
	preview_seed: String,
	reroll_random_preview: bool,
	args: Dictionary,
) -> void:
	if engine.context == null or engine.context.store == null:
		return
	var payload := _build_neutral_preview_payload(engine)
	var rng := RandomNumberGenerator.new()
	if reroll_random_preview:
		rng.randomize()
	else:
		rng.seed = _seed_hash(preview_seed)
	var value_index := 0
	for c in range(calcs.get_count()):
		var calc := calcs.get_node(c)
		if not calc.is_valid() or calc.get_type() != GnosisValueType.OBJECT:
			continue
		var merged := _merge_calc_parameters(engine, calc.get_node("parameters"), boon_slot)
		var outcomes := calc.get_node("outcomes")
		if not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST:
			continue
		for o in range(outcomes.get_count()):
			var outcome := outcomes.get_node(o)
			if not outcome.is_valid() or outcome.get_type() != GnosisValueType.OBJECT:
				continue
			value_index += 1
			var key := "%s%d" % [SCORE_VALUE_PREFIX, value_index]
			var expr := _read_expr_string(outcome.get_node("value"))
			var outcome_rng := rng
			if reroll_random_preview and _expr_uses_random(expr):
				outcome_rng = RandomNumberGenerator.new()
				outcome_rng.randomize()
			args[key] = _evaluate_outcome_preview(engine, expr, payload, merged, outcome_rng)


static func _evaluate_outcome_preview(
	engine: GnosisEngine,
	expr: String,
	payload: GnosisNode,
	parameters: GnosisNode,
	rng: RandomNumberGenerator,
) -> String:
	var trimmed := expr.strip_edges()
	if trimmed.is_empty():
		return "0"
	var bind := func(path: String) -> float:
		return _resolve_binding(engine, path, payload, parameters)
	var value = GnosisScoreExpr.try_evaluate_double(trimmed, bind, rng)
	if value == null:
		return "0"
	return _format_preview_number(float(value))


static func _resolve_binding(
	engine: GnosisEngine,
	raw_path: String,
	payload: GnosisNode,
	parameters: GnosisNode,
) -> float:
	var path := raw_path.strip_edges()
	if path.is_empty():
		return 0.0
	if path.to_lower().begins_with("ephemeral.statistics."):
		var stat_path := path.substr("ephemeral.statistics.".length())
		var match3 := engine.get_service("Match3")
		if match3 != null and match3.has_method("get_statistic_int"):
			return float(match3.call("get_statistic_int", stat_path, 0))
	if path.to_lower() == "ephemeral.match3.boardcellscount":
		return _resolve_board_cells_count(engine)
	var node := _resolve_context_path(engine, path, payload, parameters)
	return _read_double(node, 0.0)


static func _resolve_context_path(
	engine: GnosisEngine,
	raw_path: String,
	payload: GnosisNode,
	parameters: GnosisNode,
) -> GnosisNode:
	var path := raw_path.strip_edges()
	if path.is_empty():
		return payload
	var parts := path.split(".")
	if parts.is_empty():
		return payload
	var idx := 0
	var cur: GnosisNode
	match parts[0].to_lower():
		"payload":
			cur = payload
			idx = 1
		"parameters":
			cur = parameters
			idx = 1
		"ephemeral":
			if parts.size() > 1:
				cur = engine.state.root.get_node("Ephemeral").get_node(parts[1])
				idx = 2
			else:
				cur = payload
		"persistent":
			if parts.size() > 1:
				cur = engine.state.root.get_node("Persistent").get_node(parts[1])
				idx = 2
			else:
				cur = payload
		_:
			cur = payload
	for i in range(idx, parts.size()):
		if cur == null or not cur.is_valid():
			return GnosisNode.new(null)
		cur = cur.get_node(parts[i])
	return cur


static func _merge_calc_parameters(
	engine: GnosisEngine,
	calc_parameters: GnosisNode,
	boon_slot: GnosisNode,
) -> GnosisNode:
	var merged := engine.context.store.create_object()
	if calc_parameters.is_valid() and calc_parameters.get_type() == GnosisValueType.OBJECT:
		for key in calc_parameters.get_keys():
			merged.set_key(str(key), calc_parameters.get_node(key))
	if boon_slot.is_valid() and boon_slot.get_type() == GnosisValueType.OBJECT:
		merged.set_key("boonSlot", boon_slot)
	return merged


static func _build_neutral_preview_payload(engine: GnosisEngine) -> GnosisNode:
	var store := engine.context.store
	var payload := store.create_object()
	var score := store.create_object()
	score.set_key("pointsTotal", SupportScript.write_scalable_node(store, SupportScript.scalable_from_int(0)))
	score.set_key("multiTotal", SupportScript.write_scalable_node(store, SupportScript.scalable_from_int(0)))
	score.set_key("destroyedCount", 0)
	score.set_key("movesRemaining", 0)
	score.set_key("movesPerformedThisRound", 0)
	score.set_key("isFirstMoveOfRound", 0)
	score.set_key("axisStraightMatch3Count", 0)
	score.set_key("hasTwoAxisStraightMatch3", 0)
	score.set_key("axisStraightMatch4Count", 0)
	score.set_key("axisStraightMatch5OrLongerCount", 0)
	score.set_key("hasAxisMatch3", 0)
	score.set_key("hasAxisMatch4", 0)
	score.set_key("hasAxisMatch5", 0)
	score.set_key("intersectionLShape5Count", 0)
	score.set_key("intersectionTShape5Count", 0)
	score.set_key("intersectionPlusShape5Count", 0)
	score.set_key("hasIntersectionLShape5", 0)
	score.set_key("hasIntersectionTShape5", 0)
	score.set_key("hasIntersectionPlusShape5", 0)
	score.set_key("topologyMatch5PlusComponentCount", 0)
	score.set_key("hasTopologyMatch5Plus", 0)
	score.set_key("cellFloorLuckySuccessfulTriggerCount", 0)
	score.set_key("destroyedDistinctItemIdCount", 0)
	score.set_key("coldDestroyedCount", 0)
	score.set_key("warmDestroyedCount", 0)
	payload.set_key("score", score)
	payload.set_key("boons", store.create_object())
	return payload


static func _build_catalog_boon_slot(engine: GnosisEngine, entry: GnosisNode) -> GnosisNode:
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return GnosisNode.new(null)
	var slot := engine.context.store.create_object()
	var props := entry.get_node("properties")
	if props.is_valid() and props.get_type() == GnosisValueType.OBJECT:
		slot.set_key("properties", props)
	return slot


static func _read_calcs_list(entry: GnosisNode) -> GnosisNode:
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return GnosisNode.new(null)
	var props := entry.get_node("properties")
	if props.is_valid() and props.get_type() == GnosisValueType.OBJECT:
		return props.get_node("scoreCalculations")
	return entry.get_node("scoreCalculations")


static func _read_catalog_entry(engine: GnosisEngine, config_section: String, catalog_item_id: String) -> GnosisNode:
	var config := engine.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	var catalog := config.get_node(config_section)
	if not catalog.is_valid():
		return GnosisNode.new(null)
	return catalog.get_node(catalog_item_id)


static func _has_scaling_counters(boon_slot: GnosisNode) -> bool:
	if not boon_slot.is_valid() or boon_slot.get_type() != GnosisValueType.OBJECT:
		return false
	var counters := boon_slot.get_node("properties").get_node("scaling").get_node("counters")
	return counters.is_valid() and counters.get_type() == GnosisValueType.OBJECT and counters.get_count() > 0


static func _append_scaling_counter_loc_args(boon_slot: GnosisNode, args: Dictionary) -> void:
	if not _has_scaling_counters(boon_slot):
		return
	var counters := boon_slot.get_node("properties").get_node("scaling").get_node("counters")
	var keys: Array = counters.get_keys()
	keys.sort()
	for i in range(mini(keys.size(), 100)):
		var counter := counters.get_node(str(keys[i]))
		args["currentIncrement%02d" % i] = _format_preview_number(_read_double(counter, 0.0))


static func _read_expr_string(node: GnosisNode) -> String:
	if not node.is_valid():
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


static func _read_double(node: GnosisNode, fallback: float) -> float:
	if not node.is_valid():
		return fallback
	match node.get_type():
		GnosisValueType.INT, GnosisValueType.LONG:
			return float(node.value)
		GnosisValueType.FLOAT:
			return float(node.value)
		GnosisValueType.OBJECT:
			return SupportScript.read_scalable_node(node).to_float()
		_:
			pass
	return fallback


static func _format_preview_number(value: float) -> String:
	if absf(value - round(value)) < 0.001:
		return str(int(round(value)))
	return str(snapped(value, 0.01))


static func _resolve_board_cells_count(engine: GnosisEngine) -> float:
	if engine == null or engine.state == null:
		return 64.0
	var m3 := engine.state.root.get_node("Ephemeral").get_node("match3")
	if not m3.is_valid():
		return 64.0
	var count := _read_double(m3.get_node("boardCellsCount"), 0.0)
	if count > 0.0:
		return count
	var width := _read_double(m3.get_node("width"), 0.0)
	var height := _read_double(m3.get_node("height"), 0.0)
	if width > 0.0 and height > 0.0:
		return width * height
	return 64.0


static func _expr_uses_random(expr: String) -> bool:
	var lowered := expr.to_lower()
	return lowered.contains("randint(") or lowered.contains("randfloat(")


static func _seed_hash(seed_text: String) -> int:
	var hash := 17
	for i in seed_text.length():
		hash = (hash * 31) + seed_text.unicode_at(i)
	return hash
