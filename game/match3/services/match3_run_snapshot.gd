class_name Match3RunSnapshot
extends RefCounted

## Serializes and restores Match3Service runtime mirrors for Continue saves.

const Models = preload("res://game/match3/core/match3_models.gd")

const GAME_TYPE := "match3"


static func capture(service) -> Dictionary:
	var gameplay = service.get_gameplay()
	return {
		"gameType": GAME_TYPE,
		"runState": _capture_run_state(service),
		"gridState": _capture_grid_state(gameplay),
		"serviceState": _capture_service_state(service),
	}


static func restore(service, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var gameplay = service.get_gameplay()
	if gameplay == null:
		return
	_restore_run_state(service, snapshot.get("runState", {}))
	_restore_grid_state(gameplay, snapshot.get("gridState", {}))
	_restore_service_state(service, snapshot.get("serviceState", {}))
	if service.has_method("_sync_gameplay_effect_flags"):
		service._sync_gameplay_effect_flags()
	if service.has_method("_hydrate_lucky_find_from_store"):
		service._hydrate_lucky_find_from_store()
	if service.has_method("_hydrate_round_action_reward_locks_from_ephemeral"):
		service._hydrate_round_action_reward_locks_from_ephemeral()
	if service.has_method("refresh_planned_floor_preview"):
		service.refresh_planned_floor_preview()


static func _capture_run_state(service) -> Dictionary:
	var run_id := ""
	if service.has_method("_try_get_run_seed"):
		run_id = str(service._try_get_run_seed())
	var is_over := false
	if service.has_method("is_run_game_over"):
		is_over = bool(service.is_run_game_over())
	return {
		"runId": run_id,
		"isGameOver": is_over,
	}


static func _restore_run_state(_service, data: Dictionary) -> void:
	# Run identity lives in Ephemeral/Seed; snapshot only stores terminal flags for validation.
	pass


static func _capture_service_state(service) -> Dictionary:
	return {
		"currentRound": service.get_current_round() if service.has_method("get_current_round") else 1,
		"currentFloor": service.get_current_floor() if service.has_method("get_current_floor") else 1,
		"roundInFloor": service.get_round_in_floor() if service.has_method("get_round_in_floor") else 1,
		"activeBoardId": service._active_board_id,
		"activeLevelId": service._active_level_id,
		"activeStageType": service._active_stage_type,
		"manualShufflesRemaining": service._manual_shuffles_remaining,
		"floorBundlePlans": service._floor_bundle_plans.duplicate(true),
		"roundActionRewardLocks": service._round_action_reward_locks.duplicate(true),
		"lastStepPoints": service._last_step_points,
		"lastStepMulti": service._last_step_multi,
		"lastMoveScore": service._last_move_score,
	}


static func _restore_service_state(service, data: Dictionary) -> void:
	if data.is_empty():
		return
	service._current_round = maxi(1, int(data.get("currentRound", 1)))
	service._current_floor = maxi(1, int(data.get("currentFloor", 1)))
	service._round_in_floor = maxi(1, int(data.get("roundInFloor", 1)))
	service._active_board_id = str(data.get("activeBoardId", ""))
	service._active_level_id = str(data.get("activeLevelId", "normal"))
	service._active_stage_type = str(data.get("activeStageType", "normal"))
	service._manual_shuffles_remaining = maxi(0, int(data.get("manualShufflesRemaining", 0)))
	var plans: Variant = data.get("floorBundlePlans", {})
	service._floor_bundle_plans = plans.duplicate(true) if plans is Dictionary else {}
	var locks: Variant = data.get("roundActionRewardLocks", {})
	service._round_action_reward_locks = locks.duplicate(true) if locks is Dictionary else {}
	service._last_step_points = int(data.get("lastStepPoints", 0))
	service._last_step_multi = int(data.get("lastStepMulti", 0))
	service._last_move_score = int(data.get("lastMoveScore", 0))


static func _capture_grid_state(gameplay) -> Dictionary:
	if gameplay == null or not gameplay.is_grid_allocated():
		return {
			"width": 0,
			"height": 0,
			"cells": [],
			"palette": [],
			"entryPoints": [],
			"movesPerformed": 0,
			"currentMoves": 0,
			"currentScore": 0,
			"targetScore": 0,
			"status": Models.STATUS_LEVEL_SELECT_PANEL,
			"rngState": 0,
			"scoreRestrictExactThree": false,
			"scoreRestrictExactFourFive": false,
			"tilePointsContributionScale": 1.0,
			"tileMultiContributionScale": 1.0,
			"reduceFirstDestroyedItemLevelEnabled": false,
		}
	var cells: Array = []
	for y in gameplay.height:
		var row: Array = []
		for x in gameplay.width:
			row.append(_tile_to_dict(gameplay.get_tile(x, y)))
		cells.append(row)
	var entry_points: Array = []
	for ep in gameplay.entry_points:
		if ep is Models.TileCoord:
			entry_points.append(ep.to_dict())
		elif ep is Dictionary:
			entry_points.append(ep)
	return {
		"width": gameplay.width,
		"height": gameplay.height,
		"cells": cells,
		"palette": Array(gameplay.palette),
		"entryPoints": entry_points,
		"movesPerformed": gameplay.moves_performed,
		"currentMoves": gameplay.current_moves,
		"currentScore": gameplay.current_score,
		"targetScore": gameplay.target_score,
		"status": gameplay.status,
		"rngState": gameplay.get_spawn_rng().state,
		"scoreRestrictExactThree": gameplay.score_restrict_exact_three,
		"scoreRestrictExactFourFive": gameplay.score_restrict_exact_four_five,
		"tilePointsContributionScale": gameplay.tile_points_contribution_scale,
		"tileMultiContributionScale": gameplay.tile_multi_contribution_scale,
		"reduceFirstDestroyedItemLevelEnabled": gameplay.reduce_first_destroyed_item_level_enabled,
	}


static func _restore_grid_state(gameplay, data: Dictionary) -> void:
	if gameplay == null or data.is_empty():
		return
	var width := int(data.get("width", 0))
	var height := int(data.get("height", 0))
	if width <= 0 or height <= 0:
		gameplay.width = 0
		gameplay.height = 0
		gameplay.grid = []
		gameplay.moves_performed = int(data.get("movesPerformed", 0))
		gameplay.current_moves = int(data.get("currentMoves", 0))
		gameplay.current_score = int(data.get("currentScore", 0))
		gameplay.target_score = maxi(1, int(data.get("targetScore", 1)))
		gameplay.status = int(data.get("status", Models.STATUS_LEVEL_SELECT_PANEL))
		return
	gameplay.width = width
	gameplay.height = height
	gameplay.grid = []
	for y in height:
		var row: Array = []
		for x in width:
			row.append(Models.Match3TileData.new())
		gameplay.grid.append(row)
	var cells: Variant = data.get("cells", [])
	if cells is Array:
		for y in mini(height, cells.size()):
			var row_data: Variant = cells[y]
			if not (row_data is Array):
				continue
			for x in mini(width, row_data.size()):
				_tile_from_dict(gameplay.grid[y][x], row_data[x])
	var palette: Variant = data.get("palette", [])
	if palette is Array:
		var packed := PackedStringArray()
		for entry in palette:
			packed.append(str(entry))
		gameplay.palette = packed
	gameplay.entry_points = []
	var entry_data: Variant = data.get("entryPoints", [])
	if entry_data is Array:
		for ep in entry_data:
			if ep is Dictionary:
				gameplay.entry_points.append(Models.TileCoord.from_dict(ep))
	gameplay.moves_performed = int(data.get("movesPerformed", 0))
	gameplay.current_moves = int(data.get("currentMoves", 0))
	gameplay.current_score = int(data.get("currentScore", 0))
	gameplay.target_score = maxi(1, int(data.get("targetScore", 1)))
	gameplay.status = int(data.get("status", Models.STATUS_PLAYING))
	gameplay.score_restrict_exact_three = bool(data.get("scoreRestrictExactThree", false))
	gameplay.score_restrict_exact_four_five = bool(data.get("scoreRestrictExactFourFive", false))
	gameplay.tile_points_contribution_scale = float(data.get("tilePointsContributionScale", 1.0))
	gameplay.tile_multi_contribution_scale = float(data.get("tileMultiContributionScale", 1.0))
	gameplay.reduce_first_destroyed_item_level_enabled = bool(
		data.get("reduceFirstDestroyedItemLevelEnabled", false)
	)
	var rng_state := int(data.get("rngState", 0))
	if rng_state != 0:
		gameplay.get_spawn_rng().state = rng_state


static func _tile_to_dict(tile: Models.Match3TileData) -> Dictionary:
	if tile == null:
		return {}
	return {
		"slotType": tile.slot_type,
		"slotHealth": tile.slot_health,
		"itemId": tile.item_id,
		"itemKind": tile.item_kind,
		"itemTypeId": tile.item_type_id,
		"cellFloorTypeId": tile.cell_floor_type_id,
		"pointForItem": tile.point_for_item,
		"multiForItem": tile.multi_for_item,
	}


static func _tile_from_dict(tile: Models.Match3TileData, data: Variant) -> void:
	if tile == null or not (data is Dictionary):
		return
	tile.slot_type = int(data.get("slotType", Models.SLOT_ACTIVE))
	tile.slot_health = int(data.get("slotHealth", 0))
	tile.item_id = str(data.get("itemId", ""))
	tile.item_kind = int(data.get("itemKind", Models.KIND_NORMAL))
	tile.item_type_id = str(data.get("itemTypeId", "plain"))
	tile.cell_floor_type_id = str(data.get("cellFloorTypeId", ""))
	tile.point_for_item = int(data.get("pointForItem", Models.DEFAULT_ITEM_POINTS))
	tile.multi_for_item = int(data.get("multiForItem", Models.DEFAULT_ITEM_MULTI))
