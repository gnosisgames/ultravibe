class_name FallingBlockTagSimulation
extends RefCounted

## Post-lock variant tag simulation (Unity GridSimulationTagSteps.partial.cs parity).

const FB := preload("res://game/services/falling_block_ephemeral.gd")
const TraitTags := preload("res://game/services/falling_block_trait_tags.gd")
const CellState = FallingBlockModels.CellState

var _svc: FallingBlockService
var _placement_count := 0

func _init(service: FallingBlockService) -> void:
	_svc = service

func reset_for_new_run() -> void:
	_placement_count = 0

func on_piece_placed(piece_instance_id: String) -> void:
	var grid := _svc._runtime_grid_state
	if grid == null or piece_instance_id.is_empty():
		return
	_tick_ephemeral_blocks(grid)
	_placement_count += 1
	_apply_placement_discard_grant(grid, piece_instance_id)
	_apply_placement_discard_drain(grid, piece_instance_id)
	if not FallingBlockGameFlags.is_include_special_ultravibes(_svc.context):
		_initialize_ephemeral_on_locked_piece(grid, piece_instance_id)
		return
	_apply_healing(grid)
	_apply_poisoning(grid)
	_apply_contagious(grid)
	_apply_expansive(grid)
	_apply_rising(grid)
	_apply_sinking(grid)
	_initialize_ephemeral_on_locked_piece(grid, piece_instance_id)

## Locked blocks with the `slippery` trait (Slime) fall through empty cells below
## until they hit any block. Normal blocks stay anchored (Tetris behaviour).
## Mirrors Unity ApplySlipperyLockedStackGravity (ApplyGravity onlySlimeBlocks).
func apply_slippery_locked_stack_gravity(grid: FallingBlockModels.GridState) -> void:
	if grid == null or grid.width <= 0 or grid.height <= 0:
		return
	for pass_index in range(grid.height):
		var any_moved := false
		for x in range(grid.width):
			for y in range(grid.height):
				var idx := y * grid.width + x
				var cell: CellState = grid.cells[idx]
				if cell == null or cell.block_id.is_empty() or not cell.is_locked:
					continue
				if not _cell_has_tag(cell, "slippery"):
					continue
				var target_y := y
				var below_y := y - 1
				while below_y >= 0:
					var below: CellState = grid.cells[below_y * grid.width + x]
					if below != null and not below.block_id.is_empty():
						break
					target_y = below_y
					below_y -= 1
				if target_y == y:
					continue
				grid.cells[target_y * grid.width + x] = cell
				grid.cells[idx] = CellState.new()
				any_moved = true
		if not any_moved:
			break

## When any line clears, unstable blocks anywhere on the board have a 50% chance
## to destroy themselves.
func apply_unstable_after_line_clear(grid: FallingBlockModels.GridState) -> void:
	if grid == null:
		return
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or cell.block_id.is_empty():
			continue
		if not _cell_has_tag(cell, "unstable"):
			continue
		if _svc._rng.randi_range(0, 99) >= 50:
			continue
		grid.cells[i] = CellState.new()

func _apply_placement_discard_grant(grid: FallingBlockModels.GridState, piece_id: String) -> void:
	var grants := 0
	for cell in grid.cells:
		if cell == null or not cell.is_locked or cell.piece_instance_id != piece_id:
			continue
		var chance := _svc._variant_placement_discard_chance(cell.variant_id)
		if chance <= 0:
			continue
		if _svc._rng.randi_range(0, 99) < chance:
			grants += 1
	if grants > 0:
		_svc._add_discards(float(grants))

func _apply_placement_discard_drain(grid: FallingBlockModels.GridState, piece_id: String) -> void:
	var drains := 0
	for cell in grid.cells:
		if cell == null or not cell.is_locked or cell.piece_instance_id != piece_id:
			continue
		var chance := _svc._variant_placement_discard_drain_chance(cell.variant_id)
		if chance <= 0:
			continue
		if _svc._rng.randi_range(0, 99) < chance:
			drains += 1
	if drains > 0:
		var params := _svc.context.store.create_object()
		params.set_key(FallingBlockEvents.PAYLOAD_DISCARD_ADD_AMOUNT, float(drains))
		_svc._invocations.invoke("RemoveDiscards", params)

func _apply_healing(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChanceHealing", 20)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or not _cell_has_tag(cell, "healing"):
			continue
		if not _roll_trait_chance(grid, chance, true):
			continue
		var target_idx := _pick_locked_cell_by_polarity(grid, true)
		if target_idx < 0:
			continue
		var positive := _svc._pick_random_variant_by_polarity(false)
		if positive.is_empty():
			continue
		var target: CellState = grid.cells[target_idx]
		if target != null and not _svc._cell_has_immutable_tag(target):
			target.variant_id = positive
			target.tags = _svc._resolve_variant_tags(positive)

func _apply_poisoning(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChancePoisoning", 20)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or not _cell_has_tag(cell, "poisoning"):
			continue
		if not _roll_trait_chance(grid, chance, false):
			continue
		var target_idx := _pick_locked_cell_by_polarity(grid, false)
		if target_idx < 0:
			continue
		var negative := _svc._pick_random_variant_by_polarity(true)
		if negative.is_empty():
			continue
		var target: CellState = grid.cells[target_idx]
		if target != null and not _svc._cell_has_immutable_tag(target):
			target.variant_id = negative
			target.tags = _svc._resolve_variant_tags(negative)

func _apply_contagious(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChanceContagious", 8)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or not _cell_has_tag(cell, "contagious"):
			continue
		if not _roll_trait_chance(grid, chance, _svc._is_negative_variant(cell.variant_id)):
			continue
		var x := i % grid.width
		var y := i / grid.width
		var spread_tags := _svc._resolve_variant_tags(cell.variant_id)
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var nx: int = x + ox
				var ny: int = y + oy
				if nx < 0 or nx >= grid.width or ny < 0 or ny >= grid.height:
					continue
				var neighbor: CellState = grid.cells[ny * grid.width + nx]
				if neighbor == null or neighbor.block_id.is_empty() or not neighbor.is_locked:
					continue
				if _svc._cell_has_immutable_tag(neighbor):
					continue
				neighbor.variant_id = cell.variant_id
				neighbor.tags = spread_tags.duplicate()

func _apply_expansive(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChanceExpansive", 15)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or not _cell_has_tag(cell, "expansive"):
			continue
		if not _roll_trait_chance(grid, chance, true):
			continue
		var x := i % grid.width
		var y := i / grid.width
		var spread_tags := _svc._resolve_variant_tags(cell.variant_id)
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + dir.x
			var ny: int = y + dir.y
			if nx < 0 or nx >= grid.width or ny < 0 or ny >= grid.height:
				continue
			var idx: int = ny * grid.width + nx
			var neighbor: CellState = grid.cells[idx]
			if neighbor != null and not neighbor.block_id.is_empty():
				continue
			var moss := CellState.new()
			moss.block_id = str(_svc._new_block_id())
			moss.piece_instance_id = "moss_expand"
			moss.ultravibe_id = "Square4"
			moss.variant_id = cell.variant_id
			moss.tags = spread_tags.duplicate()
			moss.is_locked = true
			grid.cells[idx] = moss

func _apply_rising(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChanceRising", 12)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or not _cell_has_tag(cell, "rising"):
			continue
		if not _roll_trait_chance(grid, chance, _svc._is_negative_variant(cell.variant_id)):
			continue
		var x := i % grid.width
		var y := i / grid.width
		var spread_tags := _svc._resolve_variant_tags(cell.variant_id)
		for dir in [Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + dir.x
			var ny: int = y + dir.y
			if nx < 0 or nx >= grid.width or ny < 0 or ny >= grid.height:
				continue
			var idx: int = ny * grid.width + nx
			var neighbor: CellState = grid.cells[idx]
			if neighbor != null and not neighbor.block_id.is_empty():
				continue
			var rising := CellState.new()
			rising.block_id = str(_svc._new_block_id())
			rising.piece_instance_id = "blightmoss_expand"
			rising.ultravibe_id = "Square4"
			rising.variant_id = cell.variant_id
			rising.tags = spread_tags.duplicate()
			rising.is_locked = true
			grid.cells[idx] = rising

func _apply_sinking(grid: FallingBlockModels.GridState) -> void:
	var chance := FB.get_fb_int(_svc.context, "tagChanceSinking", 12)
	for y in range(grid.height):
		for x in range(grid.width):
			var cell: CellState = grid.cells[y * grid.width + x]
			if cell == null or not cell.is_locked or not _cell_has_tag(cell, "sinking"):
				continue
			if not _roll_trait_chance(grid, chance, true):
				continue
			var ny: int = y - 1
			if ny < 0:
				continue
			var below: CellState = grid.cells[ny * grid.width + x]
			if below != null and not below.block_id.is_empty():
				continue
			grid.cells[ny * grid.width + x] = cell.duplicate_shallow()
			grid.cells[y * grid.width + x] = CellState.new()

func _initialize_ephemeral_on_locked_piece(grid: FallingBlockModels.GridState, piece_id: String) -> void:
	var min_placements := FB.get_fb_int(_svc.context, "tagEphemeralMinPlacements", 3)
	var max_placements := FB.get_fb_int(_svc.context, "tagEphemeralMaxPlacements", 8)
	if max_placements < min_placements:
		max_placements = min_placements
	for cell in grid.cells:
		if cell == null or not cell.is_locked or cell.piece_instance_id != piece_id:
			continue
		if not _cell_has_tag(cell, "ephemeral"):
			continue
		cell.ephemeral_placements_remaining = _svc._rng.randi_range(min_placements, max_placements)

func _tick_ephemeral_blocks(grid: FallingBlockModels.GridState) -> void:
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or cell.ephemeral_placements_remaining <= 0:
			continue
		cell.ephemeral_placements_remaining -= 1
		if cell.ephemeral_placements_remaining <= 0:
			grid.cells[i] = CellState.new()

func _pick_locked_cell_by_polarity(grid: FallingBlockModels.GridState, want_negative: bool) -> int:
	var candidates: Array[int] = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or not cell.is_locked or cell.block_id.is_empty():
			continue
		var is_neg := _svc._is_negative_variant(cell.variant_id)
		if is_neg == want_negative:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	return candidates[_svc._rng.randi_range(0, candidates.size() - 1)]

func _lucky_block_count(grid: FallingBlockModels.GridState) -> int:
	var count := 0
	for cell in grid.cells:
		if cell == null or not cell.is_locked or cell.block_id.is_empty():
			continue
		if _cell_has_tag(cell, "lucky"):
			count += 1
	return count

func _roll_trait_chance(grid: FallingBlockModels.GridState, base_chance: int, is_positive_effect: bool) -> bool:
	var chance := clampi(base_chance, 0, 100)
	var lucky_bonus := _lucky_block_count(grid)
	if is_positive_effect:
		chance = clampi(chance + lucky_bonus, 0, 100)
	else:
		chance = clampi(chance - lucky_bonus, 1, 100)
	return _svc._rng.randi_range(0, 99) < chance

func _cell_has_tag(cell: CellState, tag: String) -> bool:
	return TraitTags.cell_has_tag(cell, tag, _svc._get_variant_tags(cell.variant_id))
