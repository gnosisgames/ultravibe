class_name Match3BoonMatchFloorConversions
extends RefCounted

## Data-driven properties.matchFloorConversions (Unity BoonMatchFloorConversions parity).

const Models = preload("res://game/match3/core/match3_models.gd")
const BoardScript = preload("res://game/match3/core/match3_cell_floor_board.gd")
const ScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const TopologyScript = preload("res://game/match3/core/match3_match_topology.gd")

const BOON_BASED := "Based"


static func try_apply_after_match_clear(service: GnosisService, match_result: Models.MatchResult) -> void:
	if service == null or match_result == null:
		return
	if service.has_method("are_cell_floor_modifiers_disabled") and service.call("are_cell_floor_modifiers_disabled"):
		return
	if match_result.topology_components.is_empty():
		return
	var changed := false
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		service,
		BOON_BASED,
		func(slot_entry: GnosisNode, slot_index: int) -> void:
			if _try_apply_for_slot(service, slot_entry, slot_index, match_result):
				changed = true
	)
	if changed:
		if service.has_method("sync_floor_modifier_tile_statistics_from_grid"):
			service.call("sync_floor_modifier_tile_statistics_from_grid")
		SupportScript.publish_ephemeral_state(service)


static func _try_apply_for_slot(
	service: GnosisService,
	slot_entry: GnosisNode,
	slot_index: int,
	match_result: Models.MatchResult
) -> bool:
	var rules := _read_rules_from_slot(slot_entry)
	if rules.is_empty():
		return false
	var any := false
	for rule in rules:
		var shapes: Array = rule.get("matchShapes", [])
		var floor_type_id: String = str(rule.get("floorTypeId", "")).strip_edges()
		var replace_existing := bool(rule.get("replaceExisting", true))
		if floor_type_id.is_empty() or shapes.is_empty():
			continue
		for topo in match_result.topology_components:
			if not (topo is Dictionary):
				continue
			var shape_kind := str(topo.get("shapeKind", ""))
			if not shapes.has(shape_kind):
				continue
			var tiles: Array = topo.get("tiles", [])
			for coord in tiles:
				if coord is Models.TileCoord:
					if BoardScript.try_set_cell_floor_at(
						service, coord.x, coord.y, floor_type_id, match_result, replace_existing
					):
						any = true
	if any and service.has_method("on_boon_match_floor_conversion_proc"):
		service.call("on_boon_match_floor_conversion_proc", slot_index, BOON_BASED)
	return any


static func _read_rules_from_slot(slot_entry: GnosisNode) -> Array:
	var out: Array = []
	if slot_entry == null or not slot_entry.is_valid() or slot_entry.get_type() != GnosisValueType.OBJECT:
		return out
	var props := slot_entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return out
	var conversions := props.get_node("matchFloorConversions")
	if not conversions.is_valid() or conversions.get_type() != GnosisValueType.LIST:
		return out
	for i in conversions.get_count():
		var row := conversions.get_node(i)
		if not row.is_valid() or row.get_type() != GnosisValueType.OBJECT:
			continue
		var floor_type_id := str(row.get_node("floorTypeId").value if row.get_node("floorTypeId").is_valid() else "").strip_edges()
		if floor_type_id.is_empty():
			continue
		var replace_existing := true
		var replace_node := row.get_node("replaceExisting")
		if replace_node.is_valid() and replace_node.value != null:
			replace_existing = bool(replace_node.value)
		var shapes: Array = []
		var shape_list := row.get_node("matchShapes")
		if shape_list.is_valid() and shape_list.get_type() == GnosisValueType.LIST:
			for s in shape_list.get_count():
				var shape_name := str(shape_list.get_node(s).value if shape_list.get_node(s).is_valid() else "")
				var kind := TopologyScript.shape_kind_from_json_name(shape_name)
				if kind != TopologyScript.SHAPE_UNKNOWN:
					shapes.append(kind)
		if shapes.is_empty():
			continue
		out.append({
			"floorTypeId": floor_type_id,
			"replaceExisting": replace_existing,
			"matchShapes": shapes,
		})
	return out
