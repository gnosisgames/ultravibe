class_name FallingBlockGravityCurve
extends RefCounted

## Seconds-per-cell gravity from difficulty profile and run progress (Tetris
## Guideline G table). Pure port of FallingBlockGravityCurve.cs.

const DEFAULT_LINES_PER_LEVEL := 10

const HARD_RAMP_RATE := 1.0
const NORMAL_RAMP_RATE := 0.7
const EASY_RAMP_RATE := 0.6

const EASY_FASTEST_SECONDS_PER_CELL := 0.16
const NORMAL_FASTEST_SECONDS_PER_CELL := 0.12
const HARD_FASTEST_SECONDS_PER_CELL := 0.08

const DIFFICULTY_EASY := "easy"
const DIFFICULTY_NORMAL := "normal"
const DIFFICULTY_HARD := "hard"
const DIFFICULTY_DEFAULT := "normal"

const GUIDELINE_GRAVITY_G := [
	0.01667, 0.021017, 0.026977, 0.035256, 0.04693, 0.06361, 0.0879, 0.1236,
	0.1775, 0.2598, 0.388, 0.59, 0.92, 1.46, 2.36, 3.91, 6.61, 11.43, 20.23, 36.6,
]

static func guideline_seconds_per_cell(level: int) -> float:
	level = maxi(1, level)
	var idx := mini(level - 1, GUIDELINE_GRAVITY_G.size() - 1)
	var g: float = GUIDELINE_GRAVITY_G[idx]
	return 1.0 / (g * 60.0)

static func level_from_lines_cleared(total_lines_cleared: int, lines_per_level: int) -> int:
	var interval := maxi(1, lines_per_level)
	return 1 + maxi(0, total_lines_cleared) / interval

static func lines_per_level_for_difficulty(difficulty_id: String, base_lines_per_level: int = DEFAULT_LINES_PER_LEVEL) -> int:
	var ramp_rate := _ramp_rate_for_difficulty(difficulty_id)
	var scaled := int(round(float(maxi(1, base_lines_per_level)) / ramp_rate))
	return maxi(1, scaled)

static func fastest_seconds_per_cell_for_difficulty(difficulty_id: String) -> float:
	var id := _normalize_difficulty_id(difficulty_id)
	match id:
		DIFFICULTY_EASY: return EASY_FASTEST_SECONDS_PER_CELL
		DIFFICULTY_HARD: return HARD_FASTEST_SECONDS_PER_CELL
		_: return NORMAL_FASTEST_SECONDS_PER_CELL

static func resolve_seconds_per_cell(
	difficulty_id: String,
	total_lines_cleared: int,
	level_offset: int,
	base_lines_per_level: int = DEFAULT_LINES_PER_LEVEL
) -> float:
	var id := _normalize_difficulty_id(difficulty_id)
	var lines_per_level := lines_per_level_for_difficulty(id, base_lines_per_level)
	var level := level_from_lines_cleared(total_lines_cleared, lines_per_level) + level_offset
	level = maxi(1, level)
	var seconds := guideline_seconds_per_cell(level)
	var cap := fastest_seconds_per_cell_for_difficulty(id)
	return maxf(cap, seconds)

static func resolve_starting_seconds_per_cell(difficulty_id: String, base_lines_per_level: int = DEFAULT_LINES_PER_LEVEL) -> float:
	return resolve_seconds_per_cell(difficulty_id, 0, 0, base_lines_per_level)

## Slowest (level 1) and fastest (difficulty cap) seconds-per-cell, used to map
## the live gravity onto the 0001-9999 HUD readout. Mirrors GetHudDisplayRange.
static func get_hud_display_range(difficulty_id: String) -> Dictionary:
	var id := _normalize_difficulty_id(difficulty_id)
	return {
		"slowest": guideline_seconds_per_cell(1),
		"fastest": fastest_seconds_per_cell_for_difficulty(id),
	}

static func _ramp_rate_for_difficulty(difficulty_id: String) -> float:
	var id := _normalize_difficulty_id(difficulty_id)
	match id:
		DIFFICULTY_EASY: return EASY_RAMP_RATE
		DIFFICULTY_HARD: return HARD_RAMP_RATE
		_: return NORMAL_RAMP_RATE

static func _normalize_difficulty_id(difficulty_id: String) -> String:
	if difficulty_id.strip_edges().is_empty():
		return DIFFICULTY_DEFAULT
	return difficulty_id.strip_edges().to_lower()
