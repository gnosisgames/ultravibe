class_name PieceLifecycleSystem
extends RefCounted

const CellState = FallingBlockModels.CellState
const GridState = FallingBlockModels.GridState
const PlayerState = FallingBlockModels.PlayerState
const UltravibeInfo = FallingBlockModels.UltravibeInfo
const TraitTags = preload("res://game/services/falling_block_trait_tags.gd")

var _grid_system: GridSystem
var _variant_tags_resolver: Callable = Callable()

func _init(grid_system: GridSystem) -> void:
	_grid_system = grid_system

func bind_variant_tags_resolver(resolver: Callable) -> void:
	_variant_tags_resolver = resolver

func _variant_tags_for(cell: CellState) -> Array:
	if cell == null or cell.variant_id.is_empty() or not _variant_tags_resolver.is_valid():
		return []
	return _variant_tags_resolver.call(cell.variant_id)

func try_spawn_piece(
	grid: GridState,
	player: PlayerState,
	ultravibe_info: UltravibeInfo,
	variant_id: String,
	variant_tags: Array,
	spawn_origin: Vector2i,
	piece_instance_id: String,
	new_block_id: Callable
) -> bool:
	if variant_id.is_empty():
		variant_id = "disabled"
	for offset in ultravibe_info.block_offsets:
		var x := spawn_origin.x + offset.x
		var y := spawn_origin.y + offset.y
		if _grid_system.is_cell_occupied_by_locked_block(grid, x, y):
			return false
	for offset in ultravibe_info.block_offsets:
		var x := spawn_origin.x + offset.x
		var y := spawn_origin.y + offset.y
		var cell := _grid_system.get_cell(grid, x, y)
		if cell == null:
			cell = CellState.new()
		cell.block_id = str(new_block_id.call())
		cell.piece_instance_id = piece_instance_id
		cell.ultravibe_id = ultravibe_info.ultravibe_id
		cell.variant_id = variant_id
		cell.tags = _clone_tags(variant_tags)
		cell.is_locked = false
		_grid_system.set_cell(grid, x, y, cell)
	player.current_piece_instance_id = piece_instance_id
	player.current_piece_origin = spawn_origin
	player.current_piece_rotation = 0
	player.is_on_ground = false
	player.lock_delay_expires_at_unscaled_time = 0.0
	player.lock_delay_refresh_count = 0
	return true

func can_move_piece(grid: GridState, player: PlayerState, delta: Vector2i) -> bool:
	if player.current_piece_instance_id.is_empty():
		return false
	var piece_id := player.current_piece_instance_id
	var current_positions: Array[Vector2i] = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.piece_instance_id == piece_id and not cell.is_locked:
			current_positions.append(Vector2i(i % grid.width, i / grid.width))
	if current_positions.is_empty():
		return false
	var moving_down := delta.y < 0
	var piece_is_heavy := moving_down and _piece_has_tag(grid, piece_id, "heavy")
	for pos in current_positions:
		var new_x := pos.x + delta.x
		var new_y := pos.y + delta.y
		if not _grid_system.is_cell_inside(grid, new_x, new_y):
			return false
		var target_cell := _grid_system.get_cell(grid, new_x, new_y)
		if target_cell != null and not target_cell.block_id.is_empty() and target_cell.piece_instance_id != piece_id:
			if not _can_heavy_crush_target(piece_is_heavy, target_cell):
				return false
		if target_cell != null and not target_cell.block_id.is_empty() and target_cell.piece_instance_id == piece_id and target_cell.is_locked:
			return false
	return true

func try_move_piece(grid: GridState, player: PlayerState, delta: Vector2i) -> bool:
	if player.current_piece_instance_id.is_empty():
		return false
	var piece_id := player.current_piece_instance_id
	var current_positions: Array[Vector2i] = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.piece_instance_id == piece_id and not cell.is_locked:
			current_positions.append(Vector2i(i % grid.width, i / grid.width))
	if current_positions.is_empty():
		return false
	var moving_down := delta.y < 0
	var piece_is_heavy := moving_down and _piece_has_tag(grid, piece_id, "heavy")
	var crushed_targets := {}
	for pos in current_positions:
		var new_x := pos.x + delta.x
		var new_y := pos.y + delta.y
		if not _grid_system.is_cell_inside(grid, new_x, new_y):
			return false
		var target_cell := _grid_system.get_cell(grid, new_x, new_y)
		if target_cell != null and not target_cell.block_id.is_empty() and target_cell.piece_instance_id != piece_id:
			if not _can_heavy_crush_target(piece_is_heavy, target_cell):
				return false
			crushed_targets[Vector2i(new_x, new_y)] = true
	var snapshot := {}
	for pos in current_positions:
		snapshot[pos] = _grid_system.get_cell(grid, pos.x, pos.y)
	_grid_system.clear_piece_from_grid(grid, piece_id)
	for crush_pos in crushed_targets.keys():
		_grid_system.set_cell(grid, crush_pos.x, crush_pos.y, CellState.new())
	for pos in snapshot.keys():
		var cell: CellState = snapshot[pos]
		_grid_system.set_cell(grid, pos.x + delta.x, pos.y + delta.y, cell)
	player.current_piece_origin += delta
	return true

func try_rotate_piece(grid: GridState, player: PlayerState, clockwise: bool) -> bool:
	if player.current_piece_instance_id.is_empty():
		return false
	var piece_id := player.current_piece_instance_id
	var current_positions: Array[Vector2i] = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.piece_instance_id == piece_id and not cell.is_locked:
			current_positions.append(Vector2i(i % grid.width, i / grid.width))
	if current_positions.is_empty():
		return false
	if _piece_has_tag(grid, piece_id, "rigid") and not _piece_has_tag(grid, piece_id, "gyroscopic"):
		return false
	var kick_offsets: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for kick in kick_offsets:
		var origin: Vector2i = player.current_piece_origin + kick
		var rotated_positions: Array[Vector2i] = []
		var valid := true
		for pos in current_positions:
			var dx := pos.x - player.current_piece_origin.x
			var dy := pos.y - player.current_piece_origin.y
			var rx_local: int
			var ry_local: int
			if clockwise:
				rx_local = dy
				ry_local = -dx
			else:
				rx_local = -dy
				ry_local = dx
			var rx := origin.x + rx_local
			var ry := origin.y + ry_local
			rotated_positions.append(Vector2i(rx, ry))
			if not _grid_system.is_cell_inside(grid, rx, ry):
				valid = false
				break
			var target_cell := _grid_system.get_cell(grid, rx, ry)
			if target_cell != null and not target_cell.block_id.is_empty() and target_cell.piece_instance_id != piece_id:
				valid = false
				break
		if not valid:
			continue
		var snapshot: Array[CellState] = []
		for pos in current_positions:
			snapshot.append(_grid_system.get_cell(grid, pos.x, pos.y))
		_grid_system.clear_piece_from_grid(grid, piece_id)
		for i in range(rotated_positions.size()):
			_grid_system.set_cell(grid, rotated_positions[i].x, rotated_positions[i].y, snapshot[i])
		player.current_piece_origin = origin
		player.current_piece_rotation = (player.current_piece_rotation + (1 if clockwise else -1) + 4) % 4
		return true
	return false

func lock_current_piece(grid: GridState, player: PlayerState) -> void:
	if player.current_piece_instance_id.is_empty():
		return
	var piece_id := player.current_piece_instance_id
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.piece_instance_id == piece_id:
			cell.is_locked = true
	player.current_piece_instance_id = ""
	player.is_on_ground = false
	player.lock_delay_expires_at_unscaled_time = 0.0
	player.lock_delay_refresh_count = 0

## Removes the active (non-locked) piece's cells from the grid and clears the
## player's active-piece state. Used by discards to swap the falling piece.
func clear_active_piece(grid: GridState, player: PlayerState) -> bool:
	if player == null or player.current_piece_instance_id.is_empty():
		return false
	var piece_id := player.current_piece_instance_id
	var cleared := false
	for cell in grid.cells:
		if cell != null and not cell.is_locked and cell.piece_instance_id == piece_id:
			cell.block_id = ""
			cell.piece_instance_id = ""
			cell.ultravibe_id = ""
			cell.variant_id = ""
			cell.tags.clear()
			cleared = true
	player.current_piece_instance_id = ""
	player.is_on_ground = false
	player.lock_delay_expires_at_unscaled_time = 0.0
	player.lock_delay_refresh_count = 0
	return cleared

func _clone_tags(tags: Array) -> Array[String]:
	var copy: Array[String] = []
	for tag in tags:
		var trimmed := str(tag).strip_edges().to_lower()
		if not trimmed.is_empty():
			copy.append(trimmed)
	return copy

func _piece_has_tag(grid: GridState, piece_id: String, tag_id: String) -> bool:
	if piece_id.is_empty() or tag_id.is_empty():
		return false
	for cell in grid.cells:
		if cell == null or cell.is_locked or cell.block_id.is_empty():
			continue
		if cell.piece_instance_id != piece_id:
			continue
		if TraitTags.cell_has_tag(cell, tag_id, _variant_tags_for(cell)):
			return true
	return false

func _can_heavy_crush_target(piece_is_heavy: bool, target_cell: CellState) -> bool:
	if not piece_is_heavy or target_cell == null or target_cell.block_id.is_empty():
		return false
	if not _cell_has_tag(target_cell, "soft"):
		return false
	if _cell_has_tag(target_cell, "hard"):
		return false
	return true

func _cell_has_tag(cell: CellState, tag_id: String) -> bool:
	return TraitTags.cell_has_tag(cell, tag_id, _variant_tags_for(cell))
