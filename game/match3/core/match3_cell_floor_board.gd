class_name Match3CellFloorBoard
extends RefCounted

## Board-level enhanced floor operations (Unity CellFloorBoard partial parity).

const Models = preload("res://game/match3/core/match3_models.gd")
const PoolScript = preload("res://game/match3/core/match3_floor_modifier_pool.gd")
const ScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

const GAMEPLAY_TAG_ENHANCED := "enhanced"
const BOON_GRIEFING := "Griefing"
const BOON_RED_FLAG := "RedFlag"
const BOON_BOOMER := "Boomer"
const FLOOR_TYPE_BONUS_POINTS := "BonusPoints"
const COUNTER_GRIEFING := "griefingEnhancedGriefedLifetime"
const COUNTER_RED_FLAG := "redFlagEnhancedDestroyedLifetime"
const COUNTER_LOOKSMAXXING := "looksmaxxingEnhancedAddedLifetime"
const BOON_LOOKSMAXXING := "Looksmaxxing"


static func cell_floor_type_has_gameplay_tag(service: GnosisService, type_id: String, gameplay_tag: String) -> bool:
	var want := gameplay_tag.strip_edges().to_lower()
	if want.is_empty():
		return false
	var row := _floor_type_row(service, type_id)
	if not row.is_valid():
		return false
	var tags := row.get_node("properties").get_node("gameplayTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	for i in tags.get_count():
		if str(tags.get_node(i).value).strip_edges().to_lower() == want:
			return true
	return false


static func notify_enhanced_floor_added(
	service: GnosisService,
	new_floor_type_id: String,
	previous_floor_type_id: String,
	_prefer_immediate_juice: bool = false
) -> void:
	var new_id := new_floor_type_id.strip_edges()
	if new_id.is_empty() or not cell_floor_type_has_gameplay_tag(service, new_id, GAMEPLAY_TAG_ENHANCED):
		return
	var prev := previous_floor_type_id.strip_edges()
	if not prev.is_empty() and cell_floor_type_has_gameplay_tag(service, prev, GAMEPLAY_TAG_ENHANCED):
		return
	var changed := false
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		service,
		BOON_LOOKSMAXXING,
		func(slot_entry: GnosisNode, slot_index: int) -> void:
			if ScalingScript.try_bank_boon_slot_scaling_counter(
				service, slot_index, slot_entry, COUNTER_LOOKSMAXXING, 1, _prefer_immediate_juice
			):
				changed = true
	)
	if changed:
		SupportScript.publish_ephemeral_state(service)


static func try_apply_griefing_pre_score_enhanced_floor(
	service: GnosisService,
	tile: Models.Match3TileData,
	coord: Models.TileCoord,
	match_result: Models.MatchResult
) -> void:
	if service == null or tile == null or match_result == null:
		return
	if service.has_method("are_cell_floor_modifiers_disabled") and service.call("are_cell_floor_modifiers_disabled"):
		return
	if not SupportScript.is_boon_catalog_id_equipped(service, BOON_GRIEFING):
		return
	var type_id: String = tile.cell_floor_type_id.strip_edges()
	if type_id.is_empty() or not cell_floor_type_has_gameplay_tag(service, type_id, GAMEPLAY_TAG_ENHANCED):
		return
	if not _try_clear_cell_floor_at(service, coord.x, coord.y):
		return
	_play_floor_remove_sfx(service, type_id)
	_record_floor_cleared(match_result, coord)
	var changed := false
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		service,
		BOON_GRIEFING,
		func(slot_entry: GnosisNode, slot_index: int) -> void:
			if ScalingScript.try_bank_boon_slot_scaling_counter(
				service, slot_index, slot_entry, COUNTER_GRIEFING, 1
			):
				changed = true
	)
	if changed:
		SupportScript.publish_ephemeral_state(service)


static func apply_red_flag_round_end_for_all_equipped(service: GnosisService, gameplay) -> void:
	if service == null or gameplay == null:
		return
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		service,
		BOON_RED_FLAG,
		func(slot_entry: GnosisNode, slot_index: int) -> void:
			_try_apply_red_flag_round_end_destroy(service, gameplay, slot_entry, slot_index)
	)


static func apply_boomer_round_end_pool_grants(service: GnosisService) -> void:
	if service == null:
		return
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		service,
		BOON_BOOMER,
		func(_slot_entry: GnosisNode, _slot_index: int) -> void:
			if service.has_method("try_add_floor_modifier_pool_slots"):
				service.call("try_add_floor_modifier_pool_slots", FLOOR_TYPE_BONUS_POINTS, 1)
	)


static func _try_apply_red_flag_round_end_destroy(
	service: GnosisService,
	gameplay,
	slot_entry: GnosisNode,
	slot_index: int
) -> void:
	_try_destroy_random_enhanced_floor(service, gameplay)
	if ScalingScript.try_bank_boon_slot_scaling_counter(
		service, slot_index, slot_entry, COUNTER_RED_FLAG, 1, true
	):
		SupportScript.publish_ephemeral_state(service)


static func _try_destroy_random_enhanced_floor(service: GnosisService, gameplay) -> bool:
	if gameplay == null:
		return false
	var candidates: Array[Models.TileCoord] = []
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			var type_id: String = tile.cell_floor_type_id.strip_edges()
			if type_id.is_empty() or not cell_floor_type_has_gameplay_tag(service, type_id, GAMEPLAY_TAG_ENHANCED):
				continue
			candidates.append(Models.TileCoord.new(x, y))
	if candidates.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	var pick := candidates[rng.randi_range(0, candidates.size() - 1)]
	var destroyed_id: String = gameplay.get_tile(pick.x, pick.y).cell_floor_type_id.strip_edges()
	if not _try_clear_cell_floor_at(service, pick.x, pick.y):
		return false
	_consume_pool_slot(service, destroyed_id)
	if service.has_method("sync_floor_modifier_tile_statistics_from_grid"):
		service.call("sync_floor_modifier_tile_statistics_from_grid")
	_play_floor_remove_sfx(service, destroyed_id)
	return true


static func _try_clear_cell_floor_at(service: GnosisService, x: int, y: int) -> bool:
	if service == null or not service.has_method("get_gameplay"):
		return false
	var gameplay = service.get_gameplay()
	if gameplay == null:
		return false
	var tile = gameplay.get_tile(x, y)
	if tile == null or not tile.can_hold_item() or tile.cell_floor_type_id.strip_edges().is_empty():
		return false
	tile.cell_floor_type_id = ""
	return true


static func _consume_pool_slot(service: GnosisService, floor_type_id: String) -> void:
	if service == null or service.context == null or service.context.store == null:
		return
	var m3 := service.get_node("match3", false)
	if not m3.is_valid():
		return
	var pool := m3.get_node(PoolScript.POOL_KEY)
	if not pool.is_valid():
		return
	PoolScript.consume_one_from_pool(pool, floor_type_id)


static func _record_floor_cleared(match_result: Models.MatchResult, coord: Models.TileCoord) -> void:
	for entry in match_result.floor_cells_cleared:
		if int(entry.get("x", -1)) == coord.x and int(entry.get("y", -1)) == coord.y:
			return
	match_result.floor_cells_cleared.append({"x": coord.x, "y": coord.y})


static func _play_floor_remove_sfx(service: GnosisService, type_id: String) -> void:
	var row := _floor_type_row(service, type_id)
	if row.is_valid() and service.has_method("play_cell_floor_type_sfx"):
		service.call("play_cell_floor_type_sfx", row, "removeSfxClipId")


static func _floor_type_row(service: GnosisService, type_id: String) -> GnosisNode:
	if service == null:
		return GnosisNode.new(null)
	var config := service.get_node("configuration", true)
	if not config.is_valid():
		return GnosisNode.new(null)
	var root := config.get_node("match3CellFloorTypes")
	if not root.is_valid():
		return GnosisNode.new(null)
	return root.get_node(type_id.strip_edges())
