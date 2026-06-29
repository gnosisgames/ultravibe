class_name FallingBlockPlayerRuntime
extends RefCounted

## Shared player-id and split-lane helpers (Unity FallingBlockPlayerRuntime.cs parity).

const MIN_PLAYERS := 1
const MAX_PLAYERS := 4
const PLAYER_ID_PREFIX := "P"
const MODE_SOLO := "solo"
const MODE_COOP := "coop"
## Co-op widens the board so each player gets their own full lane (Unity parity):
## the configured solo width is treated as the per-player lane width, and the
## total board grows with the player count -- 2P -> 20, 3P -> 30, 4P -> 32 (8 each,
## because the total is capped so 4 lanes still fit on screen).
const COOP_MAX_TOTAL_COLUMNS := 32

static func build_player_id(index: int) -> String:
	return "%s%d" % [PLAYER_ID_PREFIX, index]

static func try_parse_player_index(player_id: String, out_index: Array) -> bool:
	out_index.clear()
	var trimmed := player_id.strip_edges()
	if trimmed.length() < 2 or not trimmed.to_lower().begins_with(PLAYER_ID_PREFIX.to_lower()):
		return false
	var suffix := trimmed.substr(1)
	if not suffix.is_valid_int():
		return false
	var index := suffix.to_int()
	if index < 0 or index >= MAX_PLAYERS:
		return false
	out_index.append(index)
	return true

static func clamp_player_count(count: int) -> int:
	return clampi(count, MIN_PLAYERS, MAX_PLAYERS)

static func resolve_player_count(mode: String, configured: int) -> int:
	if mode.strip_edges().to_lower() == MODE_SOLO:
		return MIN_PLAYERS
	if configured >= 2:
		return clamp_player_count(configured)
	return 2

static func uses_split_lanes(player_count: int) -> bool:
	return player_count >= 2

## Lane width given a TOTAL board width (e.g. 32 cols across 4 players -> 8).
static func compute_lane_width(grid_width: int, player_count: int) -> int:
	if player_count <= 1 or grid_width <= 0:
		return grid_width
	return maxi(1, grid_width / player_count)

## Widens the board for co-op: `base_lane_width` is the per-player (solo) width and
## the total grows with the player count, capped so all lanes still fit on screen.
## e.g. base 10 -> 2P:20, 3P:30, 4P:32 (8 each).
static func adjust_grid_width_for_player_count(base_lane_width: int, player_count: int) -> int:
	if player_count <= 1 or base_lane_width <= 0:
		return base_lane_width
	var lane_width := mini(base_lane_width, COOP_MAX_TOTAL_COLUMNS / player_count)
	lane_width = maxi(1, lane_width)
	return lane_width * player_count

static func try_get_lane_bounds(
	grid_width: int,
	player_count: int,
	player_index: int,
	out_min_x: Array,
	out_max_x: Array
) -> bool:
	out_min_x.clear()
	out_max_x.clear()
	if not uses_split_lanes(player_count) or grid_width <= 0 or player_index < 0 or player_index >= player_count:
		return false
	var lane_width := compute_lane_width(grid_width, player_count)
	var lane_min_x := player_index * lane_width
	var lane_max_x := mini(grid_width - 1, lane_min_x + lane_width - 1)
	out_min_x.append(lane_min_x)
	out_max_x.append(lane_max_x)
	return lane_min_x <= lane_max_x

static func try_get_lane_bounds_for_player_id(
	grid_width: int,
	player_count: int,
	player_id: String,
	out_min_x: Array,
	out_max_x: Array
) -> bool:
	var idx_arr: Array = []
	if not try_parse_player_index(player_id, idx_arr):
		return false
	return try_get_lane_bounds(grid_width, player_count, int(idx_arr[0]), out_min_x, out_max_x)

static func player_index_from_id(player_id: String) -> int:
	var idx_arr: Array = []
	if try_parse_player_index(player_id, idx_arr):
		return int(idx_arr[0])
	return 0

## Maps Rewired-style ids (Player1..Player4) and runtime ids (P0..P3) to P0..P3.
static func normalize_runtime_player_id(player_id: String) -> String:
	var trimmed := player_id.strip_edges()
	if trimmed.is_empty():
		return trimmed
	var lower := trimmed.to_lower()
	if lower.begins_with("player") and trimmed.length() > 6:
		var suffix := trimmed.substr(6)
		if suffix.is_valid_int():
			var index := int(suffix) - 1
			if index >= 0 and index < MAX_PLAYERS:
				return build_player_id(index)
	var idx_arr: Array = []
	if try_parse_player_index(trimmed, idx_arr):
		return build_player_id(int(idx_arr[0]))
	return trimmed
