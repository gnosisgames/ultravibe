class_name GridSystem
extends RefCounted

const CellState = FallingBlockModels.CellState
const GridState = FallingBlockModels.GridState
const TraitTags = preload("res://game/services/falling_block_trait_tags.gd")

var _variant_tags_resolver: Callable = Callable()

func bind_variant_tags_resolver(resolver: Callable) -> void:
	_variant_tags_resolver = resolver

func _variant_tags_for(cell: CellState) -> Array:
	if cell == null or cell.variant_id.is_empty() or not _variant_tags_resolver.is_valid():
		return []
	return _variant_tags_resolver.call(cell.variant_id)

func _index_of(grid: GridState, x: int, y: int) -> int:
	return y * grid.width + x

func is_cell_inside(grid: GridState, x: int, y: int) -> bool:
	return x >= 0 and x < grid.width and y >= 0 and y < grid.height

func is_cell_occupied(grid: GridState, x: int, y: int) -> bool:
	if not is_cell_inside(grid, x, y):
		return true
	var cell: CellState = grid.cells[_index_of(grid, x, y)]
	return cell != null and not cell.block_id.is_empty()

func is_cell_occupied_by_locked_block(grid: GridState, x: int, y: int) -> bool:
	if not is_cell_inside(grid, x, y):
		return true
	var cell: CellState = grid.cells[_index_of(grid, x, y)]
	return cell != null and cell.is_locked and not cell.block_id.is_empty()

func get_cell(grid: GridState, x: int, y: int) -> CellState:
	if not is_cell_inside(grid, x, y):
		return null
	return grid.cells[_index_of(grid, x, y)]

func set_cell(grid: GridState, x: int, y: int, state: CellState) -> void:
	if not is_cell_inside(grid, x, y):
		return
	grid.cells[_index_of(grid, x, y)] = state

func clear_piece_from_grid(grid: GridState, piece_instance_id: String) -> void:
	if piece_instance_id.is_empty():
		return
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.piece_instance_id == piece_instance_id:
			grid.cells[i] = CellState.new()

func clear_entire_grid(grid: GridState) -> void:
	for i in range(grid.cells.size()):
		grid.cells[i] = CellState.new()

func is_row_full(grid: GridState, y: int) -> bool:
	return is_row_full_in_range(grid, y, 0, grid.width - 1)

func is_row_full_in_range(grid: GridState, y: int, x_min: int, x_max: int) -> bool:
	if grid == null or y < 0 or y >= grid.height:
		return false
	x_min = clampi(x_min, 0, grid.width - 1)
	x_max = clampi(x_max, 0, grid.width - 1)
	if x_min > x_max:
		var tmp := x_min
		x_min = x_max
		x_max = tmp
	for x in range(x_min, x_max + 1):
		var cell: CellState = grid.cells[_index_of(grid, x, y)]
		if cell == null or cell.block_id.is_empty():
			return false
	return true

func is_row_clearable(grid: GridState, y: int) -> bool:
	if not is_row_full(grid, y):
		return false
	return _row_has_removable_cell(grid, y)

func clear_full_rows_and_collapse(grid: GridState, predetermined_clearable_rows: Array = []) -> int:
	if grid == null or grid.height <= 0:
		return 0
	var clearable_rows: Array[int] = []
	if predetermined_clearable_rows.size() > 0:
		for row in predetermined_clearable_rows:
			clearable_rows.append(int(row))
	else:
		for y in range(grid.height):
			if is_row_clearable(grid, y):
				clearable_rows.append(y)
	if clearable_rows.is_empty():
		return 0
	for y in clearable_rows:
		_clear_row(grid, y)
	_collapse_after_cleared_rows(grid, clearable_rows)
	return clearable_rows.size()

func _cell_has_tag(cell: CellState, tag_id: String) -> bool:
	return TraitTags.cell_has_tag(cell, tag_id, _variant_tags_for(cell))

func clear_cells_at(grid: GridState, positions: Array) -> void:
	for pos in positions:
		if pos is Vector2i:
			set_cell(grid, pos.x, pos.y, CellState.new())

func _row_has_removable_cell(grid: GridState, y: int) -> bool:
	for x in range(grid.width):
		var cell: CellState = grid.cells[_index_of(grid, x, y)]
		if cell == null or cell.block_id.is_empty():
			continue
		if _cell_has_tag(cell, "eternal"):
			continue
		return true
	return false

func _clear_row(grid: GridState, y: int) -> void:
	for x in range(grid.width):
		var cell: CellState = grid.cells[_index_of(grid, x, y)]
		if cell != null and not cell.block_id.is_empty() and _cell_has_tag(cell, "eternal"):
			continue
		grid.cells[_index_of(grid, x, y)] = CellState.new()

func _collapse_after_cleared_rows(grid: GridState, cleared_rows: Array) -> void:
	if cleared_rows.is_empty():
		return
	var cleared_set := {}
	for y in cleared_rows:
		cleared_set[y] = true
	var locked_moves: Array = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or cell.block_id.is_empty() or not cell.is_locked:
			continue
		var x := i % grid.width
		var y := i / grid.width
		var drop := _count_locked_block_drop_rows(y, cleared_rows, cleared_set.has(y))
		if drop <= 0:
			continue
		var new_y := y - drop
		if new_y < 0:
			continue
		locked_moves.append({"x": x, "y": y, "new_y": new_y, "cell": cell})
		grid.cells[i] = CellState.new()
	for move in locked_moves:
		set_cell(grid, move.x, move.new_y, move.cell)

func _count_locked_block_drop_rows(y: int, cleared_rows: Array, is_survivor_in_cleared_row: bool) -> int:
	var drop := count_cleared_rows_below(y, cleared_rows)
	if is_survivor_in_cleared_row:
		drop += 1
	return drop

func count_cleared_rows_below(y: int, cleared_rows: Array) -> int:
	var count := 0
	for row in cleared_rows:
		if int(row) < y:
			count += 1
	return count
