class_name Match3Models
extends RefCounted

## Core data types ported from Unity GnosisMatch3.Core.

const SLOT_NONE := 0
const SLOT_ACTIVE := 1
const SLOT_INDESTRUCTIBLE := 2
const SLOT_DESTRUCTIBLE := 3

const KIND_NORMAL := 0

const STATUS_PLAYING := 0
const STATUS_WIN := 1
const STATUS_LOSS := 2
const STATUS_REGEN := 3
const STATUS_PAUSED := 4
const STATUS_LEVEL_SELECT_PANEL := 5
const STATUS_REWARD_PANEL := 6
const STATUS_SHOP_PANEL := 7
const STATUS_LOSE_PANEL := 8

const DEFAULT_ITEM_POINTS := 10
const DEFAULT_ITEM_MULTI := 1

class TileCoord:
	var x: int
	var y: int

	func _init(px: int = 0, py: int = 0) -> void:
		x = px
		y = py

	func equals(other: TileCoord) -> bool:
		return other != null and x == other.x and y == other.y

	func to_dict() -> Dictionary:
		return {"x": x, "y": y}

	static func from_dict(d: Dictionary) -> TileCoord:
		return TileCoord.new(int(d.get("x", 0)), int(d.get("y", 0)))


class Match3TileData:
	var slot_type: int = SLOT_ACTIVE
	var slot_health: int = 0
	var item_id: String = ""
	var item_kind: int = KIND_NORMAL
	var item_type_id: String = "plain"
	var cell_floor_type_id: String = ""
	var point_for_item: int = DEFAULT_ITEM_POINTS
	var multi_for_item: int = DEFAULT_ITEM_MULTI

	func is_empty() -> bool:
		return item_id.is_empty() and slot_type == SLOT_ACTIVE

	func can_hold_item() -> bool:
		return slot_type == SLOT_ACTIVE

	func can_be_matched() -> bool:
		return slot_type == SLOT_ACTIVE and not item_id.is_empty()

	func duplicate() -> Match3TileData:
		var copy := Match3TileData.new()
		copy.slot_type = slot_type
		copy.slot_health = slot_health
		copy.item_id = item_id
		copy.item_kind = item_kind
		copy.item_type_id = item_type_id
		copy.cell_floor_type_id = cell_floor_type_id
		copy.point_for_item = point_for_item
		copy.multi_for_item = multi_for_item
		return copy


class TileMovement:
	var from_coord: Match3Models.TileCoord
	var to_coord: Match3Models.TileCoord
	var item_id: String = ""
	var item_kind: int = KIND_NORMAL
	var item_type_id: String = "plain"


class TileSpawn:
	var at: Match3Models.TileCoord
	var item_id: String = ""
	var item_kind: int = KIND_NORMAL
	var item_type_id: String = "plain"


class TileContribution:
	var at: Match3Models.TileCoord
	var item_id: String = ""
	var points_added: int = 0
	var multi_added: int = 0


class MatchResult:
	var matched_tiles: Array = []
	var contributions: Array = []
	var movements: Array = []
	var new_spawns: Array = []
	var points_added: int = 0
	var multi_added: int = 0
	var move_points_so_far: int = 0
	var move_multi_so_far: int = 0
	var final_score_for_move: int = 0
	var scoring_eligible_destroy_count: int = 0
	var cleared_tile_count_this_step: int = 0
	var floor_float_pops: Array = []
	var floor_cells_cleared: Array = []
	var cell_floor_finalize_steps: Array = []
	var cell_floor_lucky_successful_trigger_count: int = 0
	var boon_resolve_steps: Array = []
	var boon_finalize_steps: Array = []
	var topology_components: Array = []
