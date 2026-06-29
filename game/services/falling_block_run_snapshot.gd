class_name FallingBlockRunSnapshot
extends RefCounted

## Serializes and restores FallingBlockService runtime mirrors for Continue saves.

const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")

static func capture(service: FallingBlockService) -> Dictionary:
	var grid := service.get_grid_state()
	var players := service.get_players()
	return {
		"runState": _capture_run_state(service),
		"gridState": _capture_grid_state(grid),
		"players": _capture_players(players),
		"pieceInstanceCounter": service.get_piece_instance_counter(),
		"gravityAccumulator": service.get_gravity_accumulator(),
		"runElapsedSeconds": service.get_run_elapsed_seconds(),
		"abilityCooldownReadyAt": service.get_ability_cooldown_ready_at(),
		"abilityCooldownTotal": service.get_ability_cooldown_total(),
	}

static func restore(service: FallingBlockService, snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var grid := service.get_grid_state()
	if grid == null:
		return
	_restore_run_state(service, snapshot.get("runState", {}))
	_restore_grid_state(grid, snapshot.get("gridState", {}))
	_restore_players(service, snapshot.get("players", []))
	service.set_piece_instance_counter(int(snapshot.get("pieceInstanceCounter", 0)))
	service.set_gravity_accumulator(float(snapshot.get("gravityAccumulator", 0.0)))
	service.set_run_elapsed_seconds(float(snapshot.get("runElapsedSeconds", 0.0)))
	service.set_ability_cooldown_state(
		float(snapshot.get("abilityCooldownReadyAt", 0.0)),
		float(snapshot.get("abilityCooldownTotal", 0.0))
	)

static func _capture_run_state(service: FallingBlockService) -> Dictionary:
	var run_state := service.get_run_state()
	if run_state == null:
		return {"runId": "", "isGameOver": false}
	return {
		"runId": run_state.run_id,
		"isGameOver": run_state.is_game_over,
	}

static func _restore_run_state(service: FallingBlockService, data: Dictionary) -> void:
	var run_state := service.get_run_state()
	if run_state == null:
		return
	run_state.run_id = str(data.get("runId", ""))
	run_state.is_game_over = bool(data.get("isGameOver", false))

static func _capture_grid_state(grid: FallingBlockModels.GridState) -> Dictionary:
	if grid == null:
		return {"width": 0, "height": 0, "hiddenRows": 0, "cells": []}
	var cells: Array = []
	for cell in grid.cells:
		cells.append(_cell_to_dict(cell))
	return {
		"width": grid.width,
		"height": grid.height,
		"hiddenRows": grid.hidden_rows,
		"cells": cells,
	}

static func _restore_grid_state(grid: FallingBlockModels.GridState, data: Dictionary) -> void:
	grid.width = int(data.get("width", 0))
	grid.height = int(data.get("height", 0))
	grid.hidden_rows = int(data.get("hiddenRows", 0))
	var cells_data: Variant = data.get("cells", [])
	grid.cells = []
	if cells_data is Array:
		for entry in cells_data:
			grid.cells.append(_cell_from_dict(entry))
	grid.ensure_cells()

static func _capture_players(players: Array) -> Array:
	var out: Array = []
	for player in players:
		if player == null:
			out.append(null)
			continue
		out.append(_player_to_dict(player))
	return out

static func _restore_players(service: FallingBlockService, players_data: Array) -> void:
	var players := service.get_players()
	while players.size() < players_data.size():
		var ps := FallingBlockModels.PlayerState.new()
		ps.player_id = PlayerRuntime.build_player_id(players.size())
		players.append(ps)
	for i in range(players_data.size()):
		var data: Variant = players_data[i]
		if not (data is Dictionary):
			continue
		if i >= players.size() or players[i] == null:
			continue
		_player_from_dict(players[i], data)

static func _cell_to_dict(cell: FallingBlockModels.CellState) -> Variant:
	if cell == null:
		return null
	return {
		"blockId": cell.block_id,
		"pieceInstanceId": cell.piece_instance_id,
		"ultravibeId": cell.ultravibe_id,
		"variantId": cell.variant_id,
		"tags": cell.tags.duplicate(),
		"isLocked": cell.is_locked,
		"ephemeralPlacementsRemaining": cell.ephemeral_placements_remaining,
	}

static func _cell_from_dict(data: Variant) -> FallingBlockModels.CellState:
	var cell := FallingBlockModels.CellState.new()
	if not (data is Dictionary):
		return cell
	cell.block_id = str(data.get("blockId", ""))
	cell.piece_instance_id = str(data.get("pieceInstanceId", ""))
	cell.ultravibe_id = str(data.get("ultravibeId", ""))
	cell.variant_id = str(data.get("variantId", ""))
	var tags: Variant = data.get("tags", [])
	if tags is Array:
		var typed_tags: Array[String] = []
		for tag in tags:
			typed_tags.append(str(tag))
		cell.tags = typed_tags
	cell.is_locked = bool(data.get("isLocked", false))
	cell.ephemeral_placements_remaining = int(data.get("ephemeralPlacementsRemaining", 0))
	return cell

static func _player_to_dict(player: FallingBlockModels.PlayerState) -> Dictionary:
	var origin: Dictionary = data_vec2i(player.current_piece_origin)
	return {
		"playerId": player.player_id,
		"currentPieceInstanceId": player.current_piece_instance_id,
		"currentPieceDeckEntryId": player.current_piece_deck_entry_id,
		"heldPieceInstanceId": player.held_piece_instance_id,
		"currentPieceOrigin": origin,
		"currentPieceRotation": player.current_piece_rotation,
		"isOnGround": player.is_on_ground,
		"lockDelayExpiresAtUnscaledTime": player.lock_delay_expires_at_unscaled_time,
		"pieceSpawnGraceTicksRemaining": player.piece_spawn_grace_ticks_remaining,
		"pieceSpawnGraceLastDecrementFrame": player.piece_spawn_grace_last_decrement_frame,
		"pieceSessionHorizontalMoves": player.piece_session_horizontal_moves,
		"pieceSessionRotationCount": player.piece_session_rotation_count,
		"pieceSessionSoftDropCells": player.piece_session_soft_drop_cells,
		"pieceSessionGravityCells": player.piece_session_gravity_cells,
		"lockDelayRefreshCount": player.lock_delay_refresh_count,
		"pieceSpawnedAtUnscaledTime": player.piece_spawned_at_unscaled_time,
		"hardDropAllowedAfterUnscaledTime": player.hard_drop_allowed_after_unscaled_time,
		"lastHardDropAcceptedAtUnscaledTime": player.last_hard_drop_accepted_at_unscaled_time,
		"lockDelayAllowedAfterUnscaledTime": player.lock_delay_allowed_after_unscaled_time,
		"isGameOver": player.is_game_over,
	}

static func _player_from_dict(player: FallingBlockModels.PlayerState, data: Dictionary) -> void:
	player.player_id = str(data.get("playerId", player.player_id))
	player.current_piece_instance_id = str(data.get("currentPieceInstanceId", ""))
	player.current_piece_deck_entry_id = str(data.get("currentPieceDeckEntryId", ""))
	player.held_piece_instance_id = str(data.get("heldPieceInstanceId", ""))
	player.current_piece_origin = vec2i_from_data(data.get("currentPieceOrigin", {}))
	player.current_piece_rotation = int(data.get("currentPieceRotation", 0))
	player.is_on_ground = bool(data.get("isOnGround", false))
	player.lock_delay_expires_at_unscaled_time = float(data.get("lockDelayExpiresAtUnscaledTime", 0.0))
	player.piece_spawn_grace_ticks_remaining = int(data.get("pieceSpawnGraceTicksRemaining", 0))
	player.piece_spawn_grace_last_decrement_frame = int(data.get("pieceSpawnGraceLastDecrementFrame", -1))
	player.piece_session_horizontal_moves = int(data.get("pieceSessionHorizontalMoves", 0))
	player.piece_session_rotation_count = int(data.get("pieceSessionRotationCount", 0))
	player.piece_session_soft_drop_cells = int(data.get("pieceSessionSoftDropCells", 0))
	player.piece_session_gravity_cells = int(data.get("pieceSessionGravityCells", 0))
	player.lock_delay_refresh_count = int(data.get("lockDelayRefreshCount", 0))
	player.piece_spawned_at_unscaled_time = float(data.get("pieceSpawnedAtUnscaledTime", 0.0))
	player.hard_drop_allowed_after_unscaled_time = float(data.get("hardDropAllowedAfterUnscaledTime", 0.0))
	player.last_hard_drop_accepted_at_unscaled_time = float(data.get("lastHardDropAcceptedAtUnscaledTime", 0.0))
	player.lock_delay_allowed_after_unscaled_time = float(data.get("lockDelayAllowedAfterUnscaledTime", 0.0))
	player.is_game_over = bool(data.get("isGameOver", false))

static func data_vec2i(value: Vector2i) -> Dictionary:
	return {"x": value.x, "y": value.y}

static func vec2i_from_data(data: Variant) -> Vector2i:
	if not (data is Dictionary):
		return Vector2i.ZERO
	return Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
