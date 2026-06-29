class_name FallingBlockModels
extends RefCounted

enum InputType {
	MOVE_LEFT,
	MOVE_RIGHT,
	SOFT_DROP,
	HARD_DROP,
	ROTATE_CW,
	ROTATE_CCW,
	DISCARD,
	USE_CONSUMABLE,
	CONSUMABLE_NEXT,
	CONSUMABLE_PREVIOUS,
	ABILITY,
	ABILITY_NEXT,
	ABILITY_PREVIOUS
}

class UltravibeInfo:
	var ultravibe_id: String = ""
	var block_count: int = 0
	var block_offsets: Array[Vector2i] = []
	var tags: Array[String] = []

class RunState:
	var run_id: String = ""
	var is_game_over: bool = false

class CellState:
	var block_id: String = ""
	var piece_instance_id: String = ""
	var ultravibe_id: String = ""
	var variant_id: String = ""
	var tags: Array[String] = []
	var is_locked: bool = false
	## Remaining placement ticks before an ephemeral block vanishes. 0 means the
	## block is not ephemeral (or has already expired).
	var ephemeral_placements_remaining: int = 0

	func duplicate_shallow() -> CellState:
		var copy := CellState.new()
		copy.block_id = block_id
		copy.piece_instance_id = piece_instance_id
		copy.ultravibe_id = ultravibe_id
		copy.variant_id = variant_id
		copy.tags = tags.duplicate()
		copy.is_locked = is_locked
		copy.ephemeral_placements_remaining = ephemeral_placements_remaining
		return copy

class GridState:
	var width: int = 0
	var height: int = 0
	var hidden_rows: int = 0
	var cells: Array = []

	func ensure_cells() -> void:
		var count := width * height
		if count <= 0:
			cells = []
			return
		if cells.size() != count:
			cells.resize(count)
			for i in range(count):
				if cells[i] == null:
					cells[i] = CellState.new()

class PlayerState:
	var player_id: String = ""
	var current_piece_instance_id: String = ""
	var current_piece_deck_entry_id: String = ""
	var held_piece_instance_id: String = ""
	var current_piece_origin: Vector2i = Vector2i.ZERO
	var current_piece_rotation: int = 0
	var is_on_ground: bool = false
	var lock_delay_expires_at_unscaled_time: float = 0.0
	var piece_spawn_grace_ticks_remaining: int = 0
	var piece_spawn_grace_last_decrement_frame: int = -1
	var piece_session_horizontal_moves: int = 0
	var piece_session_rotation_count: int = 0
	var piece_session_soft_drop_cells: int = 0
	var piece_session_gravity_cells: int = 0
	var lock_delay_refresh_count: int = 0
	var piece_spawned_at_unscaled_time: float = 0.0
	var hard_drop_allowed_after_unscaled_time: float = 0.0
	var last_hard_drop_accepted_at_unscaled_time: float = 0.0
	var lock_delay_allowed_after_unscaled_time: float = 0.0
	var is_game_over: bool = false

class InputEventData:
	var player_id: String = ""
	var type: int = InputType.MOVE_LEFT
