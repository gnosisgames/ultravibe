class_name Match3Gameplay
extends RefCounted

## Headless match-3 board simulation (ported from Match3GnosisService.Gameplay).

const Models = preload("res://game/match3/core/match3_models.gd")
const TopologyScript = preload("res://game/match3/core/match3_match_topology.gd")

var width: int = 0
var height: int = 0
var grid: Array = []
var palette: PackedStringArray = PackedStringArray()
var entry_points: Array = []

var moves_performed: int = 0
var current_moves: int = 0
var current_score: int = 0
var target_score: int = 1000
var status: int = Models.STATUS_LEVEL_SELECT_PANEL

var _rng := RandomNumberGenerator.new()
var _move_points_accum: int = 0
var _move_multi_accum: int = 0
var _tile_score_resolver: Callable = Callable()
var _boon_score_finalize_hook: Callable = Callable()
var _boon_resolve_begin_hook: Callable = Callable()
var _boon_resolve_item_destroyed_hook: Callable = Callable()
var _boon_resolve_step_cascade_hook: Callable = Callable()
var _cell_floor_scoring_hook: Callable = Callable()
var _cell_floor_finalize_hook: Callable = Callable()
var _cell_floor_griefing_hook: Callable = Callable()


func configure_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func set_boon_score_finalize_hook(hook: Callable) -> void:
	_boon_score_finalize_hook = hook


func set_boon_resolve_begin_hook(hook: Callable) -> void:
	_boon_resolve_begin_hook = hook


func set_boon_resolve_item_destroyed_hook(hook: Callable) -> void:
	_boon_resolve_item_destroyed_hook = hook


func set_boon_resolve_step_cascade_hook(hook: Callable) -> void:
	_boon_resolve_step_cascade_hook = hook


func set_tile_score_resolver(resolver: Callable) -> void:
	_tile_score_resolver = resolver


func set_cell_floor_scoring_hook(hook: Callable) -> void:
	_cell_floor_scoring_hook = hook


func set_cell_floor_finalize_hook(hook: Callable) -> void:
	_cell_floor_finalize_hook = hook


func set_cell_floor_griefing_hook(hook: Callable) -> void:
	_cell_floor_griefing_hook = hook


func load_level(
	layout: Match3BoardLayout,
	target: int,
	moves_limit: int,
	color_limit: int,
	item_points: Dictionary
) -> void:
	width = maxi(1, layout.width)
	height = maxi(1, layout.height)
	_make_empty_grid()
	moves_performed = 0
	current_moves = maxi(1, moves_limit)
	current_score = 0
	target_score = maxi(1, target)
	status = Models.STATUS_PLAYING
	palette = _resolve_palette(color_limit)
	entry_points = _resolve_entry_points(layout)

	for sq in layout.squares:
		if not _is_valid(sq.x, sq.y):
			continue
		var tile: Models.Match3TileData = grid[sq.y][sq.x]
		tile.slot_type = sq.slot_type
		tile.slot_health = sq.slot_health
		tile.cell_floor_type_id = sq.cell_floor_type_id
		if not sq.item_id.is_empty():
			_set_item(sq.x, sq.y, sq.item_id, Models.KIND_NORMAL, sq.item_type_id, item_points)

	_fill_initial_board_items(item_points)


func get_tile(x: int, y: int) -> Models.Match3TileData:
	if not _is_valid(x, y):
		return null
	return grid[y][x]


func process_move(a: Models.TileCoord, b: Models.TileCoord, item_points: Dictionary) -> Array:
	var results: Array = []
	if status != Models.STATUS_PLAYING or current_moves <= 0 or not _can_swap(a, b):
		return results

	_move_points_accum = 0
	_move_multi_accum = 0
	_swap(a, b)
	var first_match := _find_matches()
	if first_match.matched_tiles.is_empty():
		_swap(a, b)
		return results

	moves_performed += 1
	current_moves -= 1
	_process_step(first_match, results, item_points)
	if not results.is_empty():
		var last: Models.MatchResult = results[results.size() - 1]
		if _cell_floor_finalize_hook.is_valid():
			var floor_delta: Dictionary = _cell_floor_finalize_hook.call(_move_points_accum, _move_multi_accum)
			_move_points_accum += int(floor_delta.get("points", 0))
			_move_multi_accum = maxi(1, _move_multi_accum + int(floor_delta.get("multi", 0)))
			var finalize_steps: Array = floor_delta.get("finalize_steps", [])
			if not finalize_steps.is_empty():
				last.cell_floor_finalize_steps = finalize_steps
		var final_points := _move_points_accum
		var final_multi := maxi(1, _move_multi_accum)
		if _boon_score_finalize_hook.is_valid():
			var adjusted: Dictionary = _boon_score_finalize_hook.call(results, final_points, final_multi)
			final_points = int(adjusted.get("points", final_points))
			final_multi = maxi(1, int(adjusted.get("multi", final_multi)))
			_move_points_accum = final_points
			_move_multi_accum = final_multi
		var score_gain := final_points * final_multi
		last.points_added = _move_points_accum
		last.multi_added = _move_multi_accum
		last.move_points_so_far = _move_points_accum
		last.move_multi_so_far = _move_multi_accum
		last.final_score_for_move = score_gain
		current_score += score_gain

	_evaluate_game_status()
	return results


func _evaluate_game_status() -> void:
	if target_score > 0 and current_score >= target_score:
		status = Models.STATUS_WIN
	elif current_moves <= 0:
		status = Models.STATUS_LOSS
	else:
		status = Models.STATUS_PLAYING


func _process_step(
	current_match: Models.MatchResult,
	results: Array,
	item_points: Dictionary
) -> void:
	results.append(current_match)
	var to_clear: Dictionary = {}
	for coord in current_match.matched_tiles:
		to_clear[_coord_key(coord)] = coord
	var fully_cleared: Dictionary = {}
	var scoring_eligible := 0
	if _boon_resolve_begin_hook.is_valid():
		_boon_resolve_begin_hook.call(current_match, results, _move_points_accum, _move_multi_accum, scoring_eligible)

	while not to_clear.is_empty():
		var key: String = to_clear.keys()[0]
		var coord: Models.TileCoord = to_clear[key]
		to_clear.erase(key)
		if fully_cleared.has(key):
			continue
		var tile := get_tile(coord.x, coord.y)
		if tile == null or tile.is_empty():
			continue
		var points := tile.point_for_item
		var multi := tile.multi_for_item
		current_match.contributions.append({
			"at": coord.to_dict(),
			"itemId": tile.item_id,
			"itemTypeId": tile.item_type_id,
			"pointsAdded": points,
			"multiAdded": multi,
		})
		_move_points_accum += points
		_move_multi_accum += multi
		scoring_eligible += 1
		if _cell_floor_scoring_hook.is_valid():
			var floor_delta: Dictionary = _cell_floor_scoring_hook.call(
				tile, coord, current_match, multi, _move_multi_accum
			)
			_move_points_accum += int(floor_delta.get("points", 0))
			_move_multi_accum += int(floor_delta.get("multi", 0))
		if _cell_floor_griefing_hook.is_valid():
			_cell_floor_griefing_hook.call(tile, coord, current_match)
		if _boon_resolve_item_destroyed_hook.is_valid():
			var boon_totals: Dictionary = _boon_resolve_item_destroyed_hook.call(
				tile.item_id,
				current_match,
				results,
				_move_points_accum,
				_move_multi_accum,
				scoring_eligible
			)
			_move_points_accum = int(boon_totals.get("points", _move_points_accum))
			_move_multi_accum = maxi(1, int(boon_totals.get("multi", _move_multi_accum)))
		fully_cleared[key] = coord

	current_match.scoring_eligible_destroy_count = scoring_eligible
	current_match.cleared_tile_count_this_step = fully_cleared.size()
	if _boon_resolve_step_cascade_hook.is_valid():
		var cascade: Dictionary = _boon_resolve_step_cascade_hook.call(
			current_match,
			results,
			_move_points_accum,
			_move_multi_accum,
			scoring_eligible
		)
		_move_points_accum = int(cascade.get("points", _move_points_accum))
		_move_multi_accum = maxi(1, int(cascade.get("multi", _move_multi_accum)))
		var resolve_steps: Array = cascade.get("boon_resolve_steps", [])
		if not resolve_steps.is_empty():
			current_match.boon_resolve_steps = resolve_steps
	current_match.points_added = _move_points_accum
	current_match.move_points_so_far = _move_points_accum
	current_match.move_multi_so_far = _move_multi_accum

	for coord in fully_cleared.values():
		var tile := get_tile(coord.x, coord.y)
		tile.item_id = ""
		tile.item_kind = Models.KIND_NORMAL
		tile.item_type_id = "plain"

	const MAX_SETTLE := 32
	for _i in MAX_SETTLE:
		var gravity := _apply_gravity()
		if not gravity.movements.is_empty():
			results.append(gravity)
		var refill := _refill_empty_slots(item_points)
		if not refill.new_spawns.is_empty():
			results.append(refill)
		if gravity.movements.is_empty() and refill.new_spawns.is_empty():
			break

	var next_match := _find_matches()
	if not next_match.matched_tiles.is_empty():
		_process_step(next_match, results, item_points)


func _find_matches() -> Models.MatchResult:
	var result := Models.MatchResult.new()
	var matched: Dictionary = {}

	for y in height:
		var x := 0
		while x < width - 2:
			var t1 := get_tile(x, y)
			if t1 == null or not t1.can_be_matched():
				x += 1
				continue
			var nx := x + 1
			while nx < width:
				var tnx := get_tile(nx, y)
				if tnx == null or not tnx.can_be_matched() or tnx.item_id != t1.item_id:
					break
				nx += 1
			if nx - x >= 3:
				for i in range(x, nx):
					matched[_coord_key(Models.TileCoord.new(i, y))] = Models.TileCoord.new(i, y)
				x = nx - 1
			x += 1

	for x in width:
		var y := 0
		while y < height - 2:
			var t1 := get_tile(x, y)
			if t1 == null or not t1.can_be_matched():
				y += 1
				continue
			var ny := y + 1
			while ny < height:
				var tny := get_tile(x, ny)
				if tny == null or not tny.can_be_matched() or tny.item_id != t1.item_id:
					break
				ny += 1
			if ny - y >= 3:
				for i in range(y, ny):
					matched[_coord_key(Models.TileCoord.new(x, i))] = Models.TileCoord.new(x, i)
				y = ny - 1
			y += 1

	for coord in matched.values():
		result.matched_tiles.append(coord)
	TopologyScript.fill_result_topology(result, matched)
	return result


func _can_swap(a: Models.TileCoord, b: Models.TileCoord) -> bool:
	if not _is_valid(a.x, a.y) or not _is_valid(b.x, b.y):
		return false
	if absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	var ta := get_tile(a.x, a.y)
	var tb := get_tile(b.x, b.y)
	return _tile_participates_in_swap(ta) and _tile_participates_in_swap(tb)


func _tile_participates_in_swap(tile: Models.Match3TileData) -> bool:
	return tile != null and tile.can_hold_item() and not tile.item_id.is_empty()


func _swap(a: Models.TileCoord, b: Models.TileCoord) -> void:
	var t1 := get_tile(a.x, a.y)
	var t2 := get_tile(b.x, b.y)
	var tmp_id := t1.item_id
	var tmp_kind := t1.item_kind
	var tmp_type := t1.item_type_id
	var tmp_points := t1.point_for_item
	var tmp_multi := t1.multi_for_item
	t1.item_id = t2.item_id
	t1.item_kind = t2.item_kind
	t1.item_type_id = t2.item_type_id
	t1.point_for_item = t2.point_for_item
	t1.multi_for_item = t2.multi_for_item
	t2.item_id = tmp_id
	t2.item_kind = tmp_kind
	t2.item_type_id = tmp_type
	t2.point_for_item = tmp_points
	t2.multi_for_item = tmp_multi


func _apply_gravity() -> Models.MatchResult:
	var result := Models.MatchResult.new()
	for x in width:
		for y in range(1, height):
			var current := get_tile(x, y)
			if current.is_empty() or not current.can_hold_item():
				continue
			var ty := y
			while ty > 0:
				var above := get_tile(x, ty - 1)
				if above.can_hold_item() and above.is_empty():
					ty -= 1
				else:
					break
			if ty != y:
				var movement := Models.TileMovement.new()
				movement.from_coord = Models.TileCoord.new(x, y)
				movement.to_coord = Models.TileCoord.new(x, ty)
				movement.item_id = current.item_id
				movement.item_kind = current.item_kind
				movement.item_type_id = current.item_type_id
				result.movements.append(movement)
				var dest := get_tile(x, ty)
				dest.item_id = current.item_id
				dest.item_kind = current.item_kind
				dest.item_type_id = current.item_type_id
				dest.point_for_item = current.point_for_item
				dest.multi_for_item = current.multi_for_item
				current.item_id = ""
				current.item_kind = Models.KIND_NORMAL
				current.item_type_id = "plain"
				current.point_for_item = Models.DEFAULT_ITEM_POINTS
				current.multi_for_item = Models.DEFAULT_ITEM_MULTI
	return result


func _refill_empty_slots(item_points: Dictionary) -> Models.MatchResult:
	var result := Models.MatchResult.new()
	if palette.is_empty():
		return result
	for x in width:
		for y in height:
			var tile := get_tile(x, y)
			if tile == null or not tile.can_hold_item() or not tile.is_empty():
				continue
			var item_id := _pick_initial_item_id_avoiding_match(x, y)
			_set_item(x, y, item_id, Models.KIND_NORMAL, "plain", item_points)
			var spawn := Models.TileSpawn.new()
			spawn.at = Models.TileCoord.new(x, y)
			spawn.item_id = item_id
			spawn.item_kind = Models.KIND_NORMAL
			spawn.item_type_id = "plain"
			result.new_spawns.append(spawn)
	return result


func _fill_initial_board_items(item_points: Dictionary) -> void:
	for y in height:
		for x in width:
			var tile := get_tile(x, y)
			if tile == null or not tile.can_hold_item() or not tile.is_empty():
				continue
			var item_id := _pick_initial_item_id_avoiding_match(x, y)
			_set_item(x, y, item_id, Models.KIND_NORMAL, "plain", item_points)


func _pick_initial_item_id_avoiding_match(x: int, y: int) -> String:
	if palette.is_empty():
		return ""
	for _attempt in palette.size() * 2:
		var candidate := palette[_rng.randi_range(0, palette.size() - 1)]
		if not _would_create_immediate_match_at(x, y, candidate):
			return candidate
	for candidate in palette:
		if not _would_create_immediate_match_at(x, y, candidate):
			return candidate
	return palette[_rng.randi_range(0, palette.size() - 1)]


func _would_create_immediate_match_at(x: int, y: int, item_id: String) -> bool:
	if item_id.is_empty():
		return false
	return _count_match_line_through_cell(x, y, item_id, true) >= 3 \
		or _count_match_line_through_cell(x, y, item_id, false) >= 3


func _count_match_line_through_cell(x: int, y: int, item_id: String, horizontal: bool) -> int:
	var dx := 1 if horizontal else 0
	var dy := 0 if horizontal else 1
	return 1 \
		+ _count_matching_neighbors_along_axis(x, y, item_id, dx, dy) \
		+ _count_matching_neighbors_along_axis(x, y, item_id, -dx, -dy)


func _count_matching_neighbors_along_axis(x: int, y: int, item_id: String, dx: int, dy: int) -> int:
	var count := 0
	var cx := x + dx
	var cy := y + dy
	while _is_valid(cx, cy):
		var tile := get_tile(cx, cy)
		if tile == null or not tile.can_be_matched() or tile.item_id.is_empty():
			break
		if tile.item_id != item_id:
			break
		count += 1
		cx += dx
		cy += dy
	return count


func _set_item(
	x: int,
	y: int,
	item_id: String,
	kind: int,
	item_type_id: String,
	item_points: Dictionary
) -> void:
	if not _is_valid(x, y):
		return
	var tile := get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = kind
	tile.item_type_id = item_type_id if not item_type_id.is_empty() else "plain"
	var stats := _resolve_tile_stats(item_id, tile.item_type_id, item_points)
	tile.point_for_item = stats.x
	tile.multi_for_item = stats.y


func _resolve_tile_stats(item_id: String, item_type_id: String, item_points: Dictionary) -> Vector2i:
	if _tile_score_resolver.is_valid():
		var resolved = _tile_score_resolver.call(item_id, item_type_id)
		if resolved is Dictionary:
			return Vector2i(
				int(resolved.get("points", Models.DEFAULT_ITEM_POINTS)),
				int(resolved.get("multi", Models.DEFAULT_ITEM_MULTI))
			)
	var fallback_points := int(item_points.get(item_id, Models.DEFAULT_ITEM_POINTS))
	return Vector2i(fallback_points, Models.DEFAULT_ITEM_MULTI)


func _resolve_palette(color_limit: int) -> PackedStringArray:
	var limit := maxi(1, color_limit)
	var defaults := PackedStringArray(["orange", "red", "purple", "blue", "green", "pink"])
	if limit >= defaults.size():
		return defaults
	return defaults.slice(0, limit)


func _resolve_entry_points(layout: Match3BoardLayout) -> Array:
	var points: Array = []
	for sq in layout.squares:
		if sq.enter_square:
			points.append(Models.TileCoord.new(sq.x, sq.y))
	return points


func _make_empty_grid() -> void:
	grid.clear()
	for y in height:
		var row: Array = []
		for x in width:
			row.append(Models.Match3TileData.new())
		grid.append(row)


func _is_valid(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height


func _coord_key(coord: Models.TileCoord) -> String:
	return "%d,%d" % [coord.x, coord.y]


## Reshuffles existing board items (Unity ShuffleBoard / RebuildGridItems parity).
func shuffle_board(item_points: Dictionary) -> Models.MatchResult:
	var result := Models.MatchResult.new()
	var target_cells: Array[Models.TileCoord] = []
	var preserved_items: Array[Dictionary] = []
	for y in height:
		for x in width:
			var tile := get_tile(x, y)
			if tile == null or not tile.can_hold_item() or tile.is_empty():
				continue
			preserved_items.append({"id": tile.item_id, "type": tile.item_type_id})
			target_cells.append(Models.TileCoord.new(x, y))
	if target_cells.is_empty():
		return result
	const MAX_ATTEMPTS := 30
	for _attempt in MAX_ATTEMPTS:
		for coord in target_cells:
			var tile := get_tile(coord.x, coord.y)
			tile.item_id = ""
			tile.item_kind = Models.KIND_NORMAL
			tile.item_type_id = "plain"
		var remaining: Array[Dictionary] = []
		for entry in preserved_items:
			remaining.append(entry.duplicate())
		result.new_spawns.clear()
		for coord in target_cells:
			var picked := _pick_existing_item_index_avoiding_match(remaining, coord.x, coord.y)
			if picked < 0:
				picked = _rng.randi_range(0, remaining.size() - 1)
			var chosen: Dictionary = remaining[picked]
			remaining.remove_at(picked)
			_set_item(coord.x, coord.y, chosen["id"], Models.KIND_NORMAL, chosen["type"], item_points)
			var spawn := Models.TileSpawn.new()
			spawn.at = coord
			spawn.item_id = chosen["id"]
			spawn.item_kind = Models.KIND_NORMAL
			spawn.item_type_id = chosen["type"]
			result.new_spawns.append(spawn)
		if _find_matches().matched_tiles.is_empty() and _has_any_swappable_match():
			break
	return result


func _pick_existing_item_index_avoiding_match(remaining: Array[Dictionary], x: int, y: int) -> int:
	if remaining.is_empty():
		return -1
	var random_attempts := mini(remaining.size() * 2, 24)
	for _i in random_attempts:
		var idx := _rng.randi_range(0, remaining.size() - 1)
		if not _would_create_immediate_match_at(x, y, remaining[idx]["id"]):
			return idx
	for i in range(remaining.size()):
		if not _would_create_immediate_match_at(x, y, remaining[i]["id"]):
			return i
	return -1


func _has_any_swappable_match() -> bool:
	for y in height:
		for x in width:
			if x + 1 < width and _can_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x + 1, y)):
				_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x + 1, y))
				var has_match := not _find_matches().matched_tiles.is_empty()
				_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x + 1, y))
				if has_match:
					return true
			if y + 1 < height and _can_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x, y + 1)):
				_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x, y + 1))
				var has_match := not _find_matches().matched_tiles.is_empty()
				_swap(Models.TileCoord.new(x, y), Models.TileCoord.new(x, y + 1))
				if has_match:
					return true
	return false
