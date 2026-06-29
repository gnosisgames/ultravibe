class_name FallingBlockSpawnResolver
extends RefCounted

## Lane-aware spawn origin resolution (Unity GameplaySession partial parity).

const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")

static func resolve_highest_spawn_origin(
	grid: FallingBlockModels.GridState,
	player_id: String,
	player_count: int,
	offsets: Array,
	grid_system: GridSystem,
	is_spawn_occupied: Callable
) -> Vector2i:
	if grid == null or offsets.is_empty():
		return Vector2i.ZERO
	var bounds := _get_offset_bounds(offsets)
	var min_origin_x: int = -int(bounds.min_x)
	var max_origin_x: int = grid.width - 1 - int(bounds.max_x)
	if min_origin_x > max_origin_x:
		return Vector2i.ZERO
	var clamped := _clamp_spawn_x_for_lane(grid, player_id, player_count, min_origin_x, max_origin_x)
	min_origin_x = int(clamped.min)
	max_origin_x = int(clamped.max)
	if min_origin_x > max_origin_x:
		return Vector2i.ZERO
	var min_origin_y: int = -int(bounds.min_y)
	var max_origin_y: int = grid.height - 1 - int(bounds.max_y)
	if min_origin_y > max_origin_y:
		return Vector2i.ZERO
	var center_x := _lane_center_x(grid, player_id, player_count)
	center_x = clampi(center_x, min_origin_x, max_origin_x)
	for oy in range(max_origin_y, min_origin_y - 1, -1):
		var origin: Variant = _try_spawn_at_column(
			grid, player_id, player_count, offsets, center_x, oy, grid_system, is_spawn_occupied
		)
		if origin != null:
			return origin
		for dx in range(1, max_origin_x - min_origin_x + 1):
			var left := center_x - dx
			if left >= min_origin_x:
				origin = _try_spawn_at_column(
					grid, player_id, player_count, offsets, left, oy, grid_system, is_spawn_occupied
				)
				if origin != null:
					return origin
			var right := center_x + dx
			if right <= max_origin_x:
				origin = _try_spawn_at_column(
					grid, player_id, player_count, offsets, right, oy, grid_system, is_spawn_occupied
				)
				if origin != null:
					return origin
	return Vector2i(center_x, max_origin_y)

static func lane_center_x(grid: FallingBlockModels.GridState, player_id: String, player_count: int) -> int:
	return _lane_center_x(grid, player_id, player_count)

static func lane_divider_columns(grid_width: int, player_count: int) -> Array[int]:
	var dividers: Array[int] = []
	if not PlayerRuntime.uses_split_lanes(player_count) or grid_width <= 0:
		return dividers
	var lane_width := PlayerRuntime.compute_lane_width(grid_width, player_count)
	for lane in range(1, player_count):
		dividers.append(lane * lane_width)
	return dividers

static func _lane_center_x(grid: FallingBlockModels.GridState, player_id: String, player_count: int) -> int:
	var min_x: Array = []
	var max_x: Array = []
	if not PlayerRuntime.try_get_lane_bounds_for_player_id(
		grid.width, player_count, player_id, min_x, max_x
	):
		return grid.width / 2
	return (int(min_x[0]) + int(max_x[0])) / 2

static func _clamp_spawn_x_for_lane(
	grid: FallingBlockModels.GridState,
	player_id: String,
	player_count: int,
	min_origin_x: int,
	max_origin_x: int
) -> Dictionary:
	var lane_min: Array = []
	var lane_max: Array = []
	if not PlayerRuntime.try_get_lane_bounds_for_player_id(
		grid.width, player_count, player_id, lane_min, lane_max
	):
		return {"min": min_origin_x, "max": max_origin_x}
	return {
		"min": maxi(min_origin_x, int(lane_min[0])),
		"max": mini(max_origin_x, int(lane_max[0])),
	}

static func _try_spawn_at_column(
	grid: FallingBlockModels.GridState,
	player_id: String,
	player_count: int,
	offsets: Array,
	origin_x: int,
	origin_y: int,
	grid_system: GridSystem,
	is_spawn_occupied: Callable
) -> Variant:
	var origin := Vector2i(origin_x, origin_y)
	if not _is_spawn_inside_lane(grid, player_id, player_count, origin, offsets):
		return null
	if is_spawn_occupied.call(origin, offsets):
		return null
	return origin

static func _is_spawn_inside_lane(
	grid: FallingBlockModels.GridState,
	player_id: String,
	player_count: int,
	origin: Vector2i,
	offsets: Array
) -> bool:
	var lane_min: Array = []
	var lane_max: Array = []
	if not PlayerRuntime.try_get_lane_bounds_for_player_id(
		grid.width, player_count, player_id, lane_min, lane_max
	):
		return true
	for offset in offsets:
		var x := origin.x + int(offset.x)
		if x < int(lane_min[0]) or x > int(lane_max[0]):
			return false
	return true

static func _get_offset_bounds(offsets: Array) -> Dictionary:
	var min_x := 0
	var max_x := 0
	var min_y := 0
	var max_y := 0
	for offset in offsets:
		var ox := int(offset.x)
		var oy := int(offset.y)
		min_x = mini(min_x, ox)
		max_x = maxi(max_x, ox)
		min_y = mini(min_y, oy)
		max_y = maxi(max_y, oy)
	return {"min_x": min_x, "max_x": max_x, "min_y": min_y, "max_y": max_y}
