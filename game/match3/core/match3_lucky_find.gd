class_name Match3LuckyFind
extends RefCounted

## Pity-style cascade assist: rolls on refill to spawn gems that complete a match when possible.
## permanent_chance = baseline; temporary_chance drifts up on non-cascade moves and resets after a lucky chain.

const GameplayScript = preload("res://game/match3/core/match3_gameplay.gd")
const Models = preload("res://game/match3/core/match3_models.gd")

var enabled := true
var permanent_chance_percent := 10.0
var temporary_chance_percent := 10.0
var pity_increment_percent := 5.0
var pending_force := false

var _pity_multiplier := 1.0
var _permanent_bonus_percent := 0.0
var _last_refill_attempted := false
var _last_refill_succeeded := false
var _last_refill_marked_pending := false


func configure(permanent: float, pity_increment: float, start_enabled: bool = true) -> void:
	permanent_chance_percent = maxf(0.0, permanent)
	pity_increment_percent = maxf(0.0, pity_increment)
	enabled = start_enabled
	reset_temporary_to_permanent()


func hydrate(permanent: float, temporary: float, pity_increment: float, pending: bool, start_enabled: bool) -> void:
	permanent_chance_percent = maxf(0.0, permanent)
	temporary_chance_percent = maxf(0.0, temporary)
	pity_increment_percent = maxf(0.0, pity_increment)
	pending_force = pending
	enabled = start_enabled


func snapshot() -> Dictionary:
	return {
		"permanentChancePercent": permanent_chance_percent + _permanent_bonus_percent,
		"temporaryChancePercent": temporary_chance_percent,
		"pityIncrementPercent": pity_increment_percent,
		"pendingForce": pending_force,
		"enabled": enabled,
	}


func reset_temporary_to_permanent() -> void:
	temporary_chance_percent = _effective_permanent()


func add_permanent_bonus_percent(delta: float) -> void:
	_permanent_bonus_percent += delta
	temporary_chance_percent = maxf(temporary_chance_percent, _effective_permanent())


func reset_permanent_bonus() -> void:
	_permanent_bonus_percent = 0.0


func set_pity_increment_multiplier(multiplier: float) -> void:
	_pity_multiplier = maxf(0.0, multiplier)


func consume_last_refill_outcome() -> Dictionary:
	var out := {
		"attempted": _last_refill_attempted,
		"succeeded": _last_refill_succeeded,
		"marked_pending": _last_refill_marked_pending,
	}
	_last_refill_attempted = false
	_last_refill_succeeded = false
	_last_refill_marked_pending = false
	return out


func on_move_finished(cascade_match_steps: int, lucky_cascade_achieved: bool) -> void:
	if not enabled:
		return
	if lucky_cascade_achieved:
		pending_force = false
		reset_temporary_to_permanent()
		return
	if cascade_match_steps <= 0:
		var increment := pity_increment_percent * _pity_multiplier
		temporary_chance_percent += increment


func resolve_refill_plan(
	gameplay: Match3Gameplay,
	empty_cells: Array,
	rng: RandomNumberGenerator
) -> Dictionary:
	_last_refill_attempted = false
	_last_refill_succeeded = false
	_last_refill_marked_pending = false
	if not enabled or empty_cells.is_empty():
		return {"active": false, "assignments": {}, "depth_target": 0}

	var depth_target := _resolve_depth_target(rng)
	var should_force := pending_force
	if not should_force:
		if not _roll_activation(rng):
			return {"active": false, "assignments": {}, "depth_target": 0}
		should_force = true

	_last_refill_attempted = true
	var assignments := _plan_assignments_for_depth(gameplay, empty_cells, depth_target)
	if assignments.is_empty():
		pending_force = true
		_last_refill_marked_pending = true
		return {"active": false, "assignments": {}, "depth_target": depth_target}

	pending_force = false
	_last_refill_succeeded = true
	return {"active": true, "assignments": assignments, "depth_target": depth_target}


func _effective_permanent() -> float:
	return maxf(0.0, permanent_chance_percent + _permanent_bonus_percent)


func _roll_activation(rng: RandomNumberGenerator) -> bool:
	var chance := temporary_chance_percent
	if chance <= 0.0:
		return false
	if chance >= 100.0:
		return true
	return rng.randf() * 100.0 < chance


func _resolve_depth_target(rng: RandomNumberGenerator) -> int:
	var chance := temporary_chance_percent
	if chance <= 100.0:
		return 1
	var guaranteed := int(floor(chance / 100.0))
	var remainder := chance - float(guaranteed) * 100.0
	var extra := 1 if remainder > 0.0 and rng.randf() * 100.0 < remainder else 0
	return maxi(1, guaranteed + extra)


func _plan_assignments_for_depth(
	gameplay: Match3Gameplay,
	empty_cells: Array,
	depth_target: int
) -> Dictionary:
	var assignments := _plan_single_cascade_assignments(gameplay, empty_cells)
	if assignments.is_empty():
		return {}
	if depth_target <= 1:
		return assignments
	# Deeper chains: simulate one lucky refill + clear, then plan again on the next empties.
	var sim := _simulate_assignments(gameplay, empty_cells, assignments)
	if sim.is_empty():
		return assignments
	var next_assignments := _plan_single_cascade_assignments(gameplay, sim.get("next_empty_cells", []))
	if next_assignments.is_empty():
		return assignments
	for key in next_assignments.keys():
		assignments[key] = next_assignments[key]
	return assignments


func _plan_single_cascade_assignments(gameplay: Match3Gameplay, empty_cells: Array) -> Dictionary:
	if empty_cells.is_empty():
		return {}
	var palette := gameplay.palette
	if palette.is_empty():
		return {}

	var ordered := empty_cells.duplicate()
	ordered.sort_custom(func(a, b) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y
	)

	var assignments: Dictionary = {}
	for cell in ordered:
		var picked := _pick_color_for_cell(gameplay, cell, ordered, assignments, palette, true)
		if picked.is_empty():
			picked = _pick_color_for_cell(gameplay, cell, ordered, assignments, palette, false)
		if picked.is_empty():
			return {}
		assignments[_cell_key(cell)] = picked

	if not _assignments_create_match(gameplay, ordered, assignments):
		return {}
	return assignments


func _pick_color_for_cell(
	gameplay: Match3Gameplay,
	cell: Dictionary,
	ordered: Array,
	assignments: Dictionary,
	palette: PackedStringArray,
	prefer_match: bool
) -> String:
	var candidates: Array[String] = []
	for item_id in palette:
		if prefer_match:
			if _would_match_with_assignment(gameplay, cell, item_id, ordered, assignments):
				candidates.append(item_id)
		elif not _would_create_immediate_match_with_assignment(gameplay, cell, item_id, ordered, assignments):
			candidates.append(item_id)
	if prefer_match and not candidates.is_empty():
		return candidates[0]
	if not prefer_match:
		if not candidates.is_empty():
			return candidates[0]
		return palette[0]
	return ""


func _would_match_with_assignment(
	gameplay: Match3Gameplay,
	cell: Dictionary,
	item_id: String,
	ordered: Array,
	assignments: Dictionary
) -> bool:
	return _count_line_through_cell(gameplay, cell, item_id, ordered, assignments, true) >= 3 \
		or _count_line_through_cell(gameplay, cell, item_id, ordered, assignments, false) >= 3


func _would_create_immediate_match_with_assignment(
	gameplay: Match3Gameplay,
	cell: Dictionary,
	item_id: String,
	ordered: Array,
	assignments: Dictionary
) -> bool:
	return _would_match_with_assignment(gameplay, cell, item_id, ordered, assignments)


func _count_line_through_cell(
	gameplay: Match3Gameplay,
	cell: Dictionary,
	item_id: String,
	ordered: Array,
	assignments: Dictionary,
	horizontal: bool
) -> int:
	var dx := 1 if horizontal else 0
	var dy := 0 if horizontal else 1
	return 1 \
		+ _count_axis(gameplay, cell, item_id, ordered, assignments, dx, dy) \
		+ _count_axis(gameplay, cell, item_id, ordered, assignments, -dx, -dy)


func _count_axis(
	gameplay: Match3Gameplay,
	cell: Dictionary,
	item_id: String,
	ordered: Array,
	assignments: Dictionary,
	dx: int,
	dy: int
) -> int:
	var count := 0
	var cx: int = int(cell.x) + dx
	var cy: int = int(cell.y) + dy
	while _cell_item_id(gameplay, cx, cy, ordered, assignments) == item_id:
		count += 1
		cx += dx
		cy += dy
	return count


func _cell_item_id(
	gameplay: Match3Gameplay,
	x: int,
	y: int,
	ordered: Array,
	assignments: Dictionary
) -> String:
	var key := "%d,%d" % [x, y]
	if assignments.has(key):
		return str(assignments[key])
	for cell in ordered:
		if int(cell.x) == x and int(cell.y) == y:
			return ""
	var tile := gameplay.get_tile(x, y)
	if tile == null or not tile.can_be_matched():
		return "__blocked__"
	return tile.item_id


func _assignments_create_match(gameplay: Match3Gameplay, ordered: Array, assignments: Dictionary) -> bool:
	for key in assignments.keys():
		var parts: PackedStringArray = key.split(",")
		if parts.size() != 2:
			continue
		var cell := {"x": int(parts[0]), "y": int(parts[1])}
		var item_id := str(assignments[key])
		if _would_match_with_assignment(gameplay, cell, item_id, ordered, assignments):
			return true
	return false


func _simulate_assignments(gameplay: Match3Gameplay, empty_cells: Array, assignments: Dictionary) -> Dictionary:
	# Lightweight snapshot: only cells touched by this refill batch.
	var backups: Dictionary = {}
	for cell in empty_cells:
		var tile := gameplay.get_tile(int(cell.x), int(cell.y))
		if tile == null:
			continue
		backups[_cell_key(cell)] = {
			"item_id": tile.item_id,
			"item_kind": tile.item_kind,
			"item_type_id": tile.item_type_id,
		}
		var item_id := str(assignments.get(_cell_key(cell), ""))
		if item_id.is_empty():
			continue
		tile.item_id = item_id
		tile.item_kind = Models.KIND_NORMAL
		tile.item_type_id = "plain"

	var matched := gameplay.find_matches()
	var next_empty: Array = []
	if matched is Match3Models.MatchResult and not matched.matched_tiles.is_empty():
		for coord in matched.matched_tiles:
			var tile := gameplay.get_tile(coord.x, coord.y)
			if tile != null:
				tile.item_id = ""
				tile.item_kind = Models.KIND_NORMAL
				tile.item_type_id = "plain"
		for cell in empty_cells:
			var tile := gameplay.get_tile(int(cell.x), int(cell.y))
			if tile != null and tile.is_empty() and tile.can_hold_item():
				next_empty.append(cell)

	for key in backups.keys():
		var parts: PackedStringArray = key.split(",")
		var tile := gameplay.get_tile(int(parts[0]), int(parts[1]))
		if tile == null:
			continue
		var backup: Dictionary = backups[key]
		tile.item_id = str(backup.get("item_id", ""))
		tile.item_kind = int(backup.get("item_kind", Models.KIND_NORMAL))
		tile.item_type_id = str(backup.get("item_type_id", "plain"))

	if next_empty.is_empty():
		return {}
	return {"next_empty_cells": next_empty}


static func _cell_key(cell: Dictionary) -> String:
	return "%d,%d" % [int(cell.x), int(cell.y)]
