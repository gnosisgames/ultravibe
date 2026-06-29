class_name FallingBlockCoop
extends RefCounted

## Local co-op split-lane helpers (Unity FallingBlockPlayerRuntime + Abilities partial parity).

const FB := preload("res://game/services/falling_block_ephemeral.gd")
const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")
const CellState = FallingBlockModels.CellState

var _svc: FallingBlockService

func _init(service: FallingBlockService) -> void:
	_svc = service

func get_player_count() -> int:
	if _svc.context == null:
		return 1
	var eph := _svc.context.state.root.get_node("Ephemeral")
	if not eph.is_valid():
		return 1
	return PlayerRuntime.clamp_player_count(FB.read_int(eph.get_node("playerCount"), 1))

func get_mode() -> String:
	if _svc.context == null:
		return PlayerRuntime.MODE_SOLO
	var eph := _svc.context.state.root.get_node("Ephemeral")
	if not eph.is_valid():
		return PlayerRuntime.MODE_SOLO
	return str(FB.read_string(eph.get_node("mode"), PlayerRuntime.MODE_SOLO))

func uses_split_lanes() -> bool:
	return PlayerRuntime.uses_split_lanes(get_player_count())

func is_row_clearable_for_mode(grid: FallingBlockModels.GridState, y: int) -> bool:
	if grid == null:
		return false
	var count := get_player_count()
	if not PlayerRuntime.uses_split_lanes(count):
		return _svc._grid_system.is_row_clearable(grid, y)
	for lane in range(count):
		var bounds_min: Array = []
		var bounds_max: Array = []
		if not PlayerRuntime.try_get_lane_bounds(grid.width, count, lane, bounds_min, bounds_max):
			continue
		if not _svc._grid_system.is_row_full_in_range(grid, y, bounds_min[0], bounds_max[0]):
			return false
		if not _lane_segment_has_removable_cell(grid, y, bounds_min[0], bounds_max[0]):
			return false
	return true

func clamp_piece_to_lane(player: FallingBlockModels.PlayerState) -> void:
	if not uses_split_lanes() or player == null or player.current_piece_instance_id.is_empty():
		return
	var grid := _svc._runtime_grid_state
	if grid == null:
		return
	var idx: int = PlayerRuntime.player_index_from_id(player.player_id)
	var bounds_min: Array = []
	var bounds_max: Array = []
	if not PlayerRuntime.try_get_lane_bounds(grid.width, get_player_count(), idx, bounds_min, bounds_max):
		return
	var min_x: int = bounds_min[0]
	var max_x: int = bounds_max[0]
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or cell.piece_instance_id != player.current_piece_instance_id or cell.is_locked:
			continue
		var x := i % grid.width
		if x < min_x:
			_svc._piece_lifecycle.try_move_piece(grid, player, Vector2i(min_x - x, 0))
		elif x > max_x:
			_svc._piece_lifecycle.try_move_piece(grid, player, Vector2i(max_x - x, 0))

func execute_grid_shift() -> bool:
	var grid := _svc._runtime_grid_state
	var players: Array = _svc._runtime_players
	if not uses_split_lanes() or grid == null or players.size() < 2:
		return false
	var count := players.size()
	var descriptors: Array = []
	for player in players:
		if player == null or player.current_piece_instance_id.is_empty():
			return false
		var desc := _capture_active_piece(player)
		if desc.is_empty():
			return false
		descriptors.append(desc)
	_shift_locked_lanes_clockwise(grid, count)
	for player in players:
		player.current_piece_instance_id = ""
		player.is_on_ground = false
		_svc._clear_lock_delay(player)
	for i in range(count):
		var player: FallingBlockModels.PlayerState = players[i]
		var desc: Dictionary = descriptors[i]
		_svc._spawn_piece_for_player(player, desc.get("ultravibeId", ""), desc.get("variantId", "blue"))
	var clearable: Array = []
	for y in range(grid.height):
		if is_row_clearable_for_mode(grid, y):
			clearable.append(y)
	if not clearable.is_empty():
		_svc._apply_synthetic_line_clear(clearable, players[0].player_id if players[0] else "")
	return true

func _lane_segment_has_removable_cell(grid: FallingBlockModels.GridState, y: int, x_min: int, x_max: int) -> bool:
	const TraitTags := preload("res://game/services/falling_block_trait_tags.gd")
	for x in range(x_min, x_max + 1):
		var cell: CellState = grid.cells[y * grid.width + x]
		if cell == null or cell.block_id.is_empty():
			return false
		if TraitTags.cell_has_tag(cell, "eternal", _svc._get_variant_tags(cell.variant_id)):
			continue
		return true
	return false

func _capture_active_piece(player: FallingBlockModels.PlayerState) -> Dictionary:
	var grid := _svc._runtime_grid_state
	if grid == null:
		return {}
	var pid := player.current_piece_instance_id
	for cell in grid.cells:
		if cell == null or cell.is_locked or cell.block_id.is_empty():
			continue
		if cell.piece_instance_id == pid:
			return {"ultravibeId": cell.ultravibe_id, "variantId": cell.variant_id}
	return {}

func _shift_locked_lanes_clockwise(grid: FallingBlockModels.GridState, player_count: int) -> void:
	var width := grid.width
	var height := grid.height
	var new_cells: Array = []
	new_cells.resize(grid.cells.size())
	for i in range(new_cells.size()):
		new_cells[i] = CellState.new()
	for target_lane in range(player_count):
		var source_lane := (target_lane + player_count - 1) % player_count
		var src_min: Array = []
		var src_max: Array = []
		var dst_min: Array = []
		var dst_max: Array = []
		if not PlayerRuntime.try_get_lane_bounds(width, player_count, source_lane, src_min, src_max):
			continue
		if not PlayerRuntime.try_get_lane_bounds(width, player_count, target_lane, dst_min, dst_max):
			continue
		var lane_width: int = int(dst_max[0]) - int(dst_min[0]) + 1
		for y in range(height):
			for local_x in range(lane_width):
				var src_x: int = src_min[0] + local_x
				if src_x > src_max[0]:
					break
				var dst_x: int = dst_min[0] + local_x
				var src_cell: CellState = grid.cells[y * width + src_x]
				if src_cell != null and src_cell.is_locked and not src_cell.block_id.is_empty():
					new_cells[y * width + dst_x] = src_cell.duplicate_shallow()
	for i in range(grid.cells.size()):
		var existing: CellState = grid.cells[i]
		if existing != null and not existing.is_locked and not existing.block_id.is_empty():
			new_cells[i] = existing
	grid.cells = new_cells
