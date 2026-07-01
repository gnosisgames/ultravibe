class_name Match3BoonScaling
extends RefCounted

## Boon scaling counter banking and round-end increments (Unity Policy.Boons / Policy.Score parity).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


static func for_each_equipped_boon_slot_with_effect_application(
	service: GnosisService,
	catalog_id: String,
	action: Callable
) -> int:
	var want := catalog_id.strip_edges().to_lower()
	if want.is_empty() or not action.is_valid():
		return 0
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	var matches: Array = []
	for i in range(slot_rows.size()):
		var row: GnosisNode = slot_rows[i]
		if SupportScript.read_boon_catalog_id_from_inventory_entry(row).to_lower() == want:
			matches.append({"slot": row, "index": i})
	if matches.is_empty():
		return 0
	var per_instance := SupportScript.read_boon_effect_application_is_per_instance(matches[0]["slot"])
	if per_instance:
		for entry in matches:
			action.call(entry["slot"], entry["index"])
		return matches.size()
	action.call(matches[0]["slot"], matches[0]["index"])
	return 1


static func add_delta_to_boon_slot_scaling_counter(
	service: GnosisService,
	slot_entry: GnosisNode,
	counter_key: String,
	delta: int
) -> bool:
	if delta == 0 or service == null or service.context == null or service.context.store == null:
		return false
	if slot_entry == null or not slot_entry.is_valid():
		return false
	var key := counter_key.strip_edges()
	if key.is_empty():
		return false
	var props := slot_entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		props = service.context.store.create_object()
		slot_entry.set_node("properties", props)
	var scaling := props.get_node("scaling")
	if not scaling.is_valid() or scaling.get_type() != GnosisValueType.OBJECT:
		scaling = service.context.store.create_object()
		props.set_node("scaling", scaling)
	var counters := scaling.get_node("counters")
	if not counters.is_valid() or counters.get_type() != GnosisValueType.OBJECT:
		counters = service.context.store.create_object()
		scaling.set_node("counters", counters)
	var cur := SupportScript._node_int(counters, key, 0)
	counters.set_key(key, cur + delta)
	return true


static func try_bank_boon_slot_scaling_counter(
	service: GnosisService,
	slot_index: int,
	slot_entry: GnosisNode,
	counter_key: String,
	delta: int,
	prefer_immediate_juice: bool = false
) -> bool:
	if not add_delta_to_boon_slot_scaling_counter(service, slot_entry, counter_key, delta):
		return false
	if prefer_immediate_juice and service.has_method("play_boon_scaling_juice_now"):
		service.call("play_boon_scaling_juice_now", slot_index, counter_key)
	return true


static func apply_resolve_step_scaling_increments(
	service: GnosisService,
	score_helper: RefCounted,
	step
) -> void:
	if service == null or step == null or score_helper == null:
		return
	if not score_helper.has_method("_build_score_finalize_payload"):
		return
	var points := int(step.move_points_so_far) if "move_points_so_far" in step else 0
	var multi := maxi(1, int(step.move_multi_so_far)) if "move_multi_so_far" in step else 1
	var destroyed := int(step.cleared_tile_count_this_step) if "cleared_tile_count_this_step" in step else 0
	var payload: GnosisNode = score_helper.call(
		"_build_score_finalize_payload",
		SupportScript.scalable_from_int(points),
		SupportScript.scalable_from_int(multi),
		destroyed,
		[step]
	)
	_apply_scaling_increments_for_on(service, payload, score_helper, "resolve_step", false)


static func apply_round_end_scaling_increments(service: GnosisService, score_helper: RefCounted) -> void:
	if service == null or service.context == null or service.context.store == null:
		return
	if score_helper == null or not score_helper.has_method("_build_score_finalize_payload"):
		return
	var gameplay = service.get_gameplay() if service.has_method("get_gameplay") else null
	if gameplay == null:
		return
	var points_sv := SupportScript.scalable_from_int(0)
	var multi_sv := SupportScript.scalable_from_int(1)
	var payload: GnosisNode = score_helper.call(
		"_build_score_finalize_payload",
		points_sv,
		multi_sv,
		0,
		[]
	)
	_apply_scaling_increments_for_on(service, payload, score_helper, "round_end", true)


static func _apply_scaling_increments_for_on(
	service: GnosisService,
	payload: GnosisNode,
	score_helper: RefCounted,
	on_want: String,
	prefer_immediate_juice: bool
) -> void:
	var empty_params := service.context.store.create_object()
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	for slot_index in range(slot_rows.size()):
		var slot_entry: GnosisNode = slot_rows[slot_index]
		var scaling := slot_entry.get_node("properties").get_node("scaling")
		if not scaling.is_valid() or scaling.get_type() != GnosisValueType.OBJECT:
			continue
		var increments := scaling.get_node("increments")
		if not increments.is_valid() or increments.get_type() != GnosisValueType.LIST:
			continue
		var counters := scaling.get_node("counters")
		if not counters.is_valid() or counters.get_type() != GnosisValueType.OBJECT:
			counters = service.context.store.create_object()
			scaling.set_node("counters", counters)
		for i in increments.get_count():
			var inc := increments.get_node(i)
			if not inc.is_valid() or inc.get_type() != GnosisValueType.OBJECT:
				continue
			if SupportScript._node_str(inc, "on", "resolve_step").to_lower() != on_want:
				continue
			var from_path := SupportScript._node_str(inc, "from")
			var counter_key := SupportScript._node_str(inc, "counter")
			if from_path.is_empty() or counter_key.is_empty():
				continue
			var scale := 1.0
			var scale_node := inc.get_node("scale")
			if scale_node.is_valid() and scale_node.value != null:
				scale = maxf(0.0, float(scale_node.value))
			var raw := _resolve_round_end_binding(from_path, payload, empty_params, score_helper)
			var delta := maxi(0, int(round(raw * scale)))
			if delta <= 0:
				continue
			try_bank_boon_slot_scaling_counter(
				service, slot_index, slot_entry, counter_key, delta, prefer_immediate_juice
			)


static func _resolve_round_end_binding(
	path: String,
	payload: GnosisNode,
	parameters: GnosisNode,
	score_helper: RefCounted
) -> float:
	if score_helper != null and score_helper.has_method("_resolve_score_expr_binding"):
		return float(score_helper.call("_resolve_score_expr_binding", path, payload, parameters))
	return 0.0
