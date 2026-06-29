class_name FallingBlockInvocations
extends RefCounted

## Board manipulation and run-state invocations (Unity Consumables/Discard/VariantLevels partials).

const FB := preload("res://game/services/falling_block_ephemeral.gd")
const CellState = FallingBlockModels.CellState
const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")

var _svc: FallingBlockService

func _init(service: FallingBlockService) -> void:
	_svc = service

func invoke(name: String, parameters: GnosisNode) -> GnosisFunctionResult:
	match name:
		"SetFallingPieceVariant":
			return _set_falling_piece_variant(parameters)
		"AddVariantLevelDelta":
			return _add_variant_level_delta(parameters)
		"DestroyCurrentPiece":
			return _destroy_current_piece(parameters)
		"DuplicateCurrentDeckEntry":
			return _duplicate_current_deck_entry(parameters)
		"PlayFallingPieceFeedback":
			return _play_falling_piece_feedback(parameters)
		"ClearEntireGridAndRespawn":
			return _clear_entire_grid_and_respawn(parameters)
		"ChangeFallSpeed":
			return _change_fall_speed(parameters)
		"SpawnTrashLines":
			return _spawn_trash_lines(parameters)
		"ExecuteGridShiftAbility", "ExecuteGridSwapAbility":
			return _execute_grid_shift_ability(parameters)
		"ClearRandomNonEmptyLockedRows":
			return _clear_random_non_empty_locked_rows(parameters)
		"ClearRowsAboveLowestNonEmptyColumnHeight":
			return _clear_rows_above_lowest_column(parameters)
		"FillSingleGapsInNonEmptyRowsAndClear":
			return _fill_single_gaps_and_clear(parameters)
		"ApplyStackGravityAndClear":
			return _apply_stack_gravity_and_clear(parameters)
		"MirrorRightHalfToLeftAndClear":
			return _mirror_right_half_and_clear(parameters)
		"AddDiscards":
			return _add_discards(parameters)
		"RemoveDiscards":
			return _remove_discards(parameters)
		"AddBaseDiscardsDelta":
			return _add_base_discards_delta(parameters)
		"ResetCurrentDiscardsToBase":
			return _reset_current_discards_to_base()
		"GrantRandomEligibleUpgrade":
			return _grant_random_eligible_upgrade(parameters)
		"AddObjectiveProgress":
			return _add_objective_progress(parameters)
		"AddPendingPoints":
			return _add_pending_points(parameters)
	return GnosisFunctionResult.fail("Unknown FallingBlock function '%s'." % name)

func _store() -> GnosisStore:
	return _svc.context.store if _svc.context else null

func _grid() -> FallingBlockModels.GridState:
	return _svc._runtime_grid_state

func _rng_int(from_inclusive: int, to_exclusive: int, default_val: int) -> int:
	if to_exclusive <= from_inclusive:
		return default_val
	return _svc._rng.randi_range(from_inclusive, to_exclusive - 1)

func _read_string(params: GnosisNode, key: String) -> String:
	if params == null or not params.is_valid():
		return ""
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value).strip_edges()
	return ""

func _read_int(params: GnosisNode, key: String, default_val: int = 0) -> int:
	if params == null or not params.is_valid():
		return default_val
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return int(round(float(n.value)))
	return default_val

func _read_float(params: GnosisNode, key: String, default_val: float = 0.0) -> float:
	if params == null or not params.is_valid():
		return default_val
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return float(n.value)
	return default_val

func _resolve_player(params: GnosisNode) -> FallingBlockModels.PlayerState:
	var pid := _read_string(params, FallingBlockEvents.PAYLOAD_PLAYER_ID)
	if pid.is_empty():
		pid = _read_string(params, "playerId")
	return _svc._resolve_player(pid)

func _add_discards(parameters: GnosisNode) -> GnosisFunctionResult:
	var amount := _read_float(parameters, FallingBlockEvents.PAYLOAD_DISCARD_ADD_AMOUNT, 1.0)
	if amount <= 0.0:
		amount = _read_float(parameters, "amount", 1.0)
	if amount <= 0.0:
		return GnosisFunctionResult.fail("AddDiscards requires positive amount.")
	_svc._add_discards(amount)
	var payload := _store().create_object()
	payload.set_key("gained", amount)
	return GnosisFunctionResult.ok(payload)

func _remove_discards(parameters: GnosisNode) -> GnosisFunctionResult:
	var amount := _read_float(parameters, FallingBlockEvents.PAYLOAD_DISCARD_ADD_AMOUNT, 1.0)
	if amount <= 0.0:
		amount = _read_float(parameters, "amount", 1.0)
	if amount <= 0.0:
		return GnosisFunctionResult.fail("RemoveDiscards requires positive amount.")
	var bounds := _svc._read_discard_bounds()
	var min_d: float = bounds[0]
	var max_d: float = bounds[1]
	var current := clampf(FB.get_fb_float(_svc.context, "currentDiscards", max_d), min_d, max_d)
	var next := clampf(current - amount, min_d, max_d)
	FB.set_fb_float(_svc.context, "currentDiscards", next)
	var removed := current - next
	if removed > 0.0001:
		_svc._play_animation_feedback("discardsRemoved")
	var payload := _store().create_object()
	payload.set_key("removed", removed)
	return GnosisFunctionResult.ok(payload)

func _add_base_discards_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _read_float(parameters, "delta", 0.0)
	if delta <= 0.0:
		delta = _read_float(parameters, FallingBlockEvents.PAYLOAD_DISCARD_ADD_AMOUNT, 0.0)
	if delta <= 0.0:
		return GnosisFunctionResult.fail("AddBaseDiscardsDelta requires positive delta.")
	var bounds := _svc._read_discard_bounds()
	var min_d: float = bounds[0]
	var max_d: float = bounds[1]
	var base_val := clampf(FB.get_fb_float(_svc.context, "baseDiscards", max_d), min_d, max_d)
	var new_base := clampf(base_val + delta, min_d, max_d)
	var applied := new_base - base_val
	FB.set_fb_float(_svc.context, "baseDiscards", new_base)
	var current := clampf(FB.get_fb_float(_svc.context, "currentDiscards", max_d), min_d, max_d)
	FB.set_fb_float(_svc.context, "currentDiscards", clampf(current + applied, min_d, max_d))
	if applied > 0.0001:
		_svc._play_animation_feedback("discardsAdded")
	var payload := _store().create_object()
	payload.set_key("applied", applied)
	payload.set_key("baseDiscards", new_base)
	return GnosisFunctionResult.ok(payload)

func _reset_current_discards_to_base() -> GnosisFunctionResult:
	_svc._reset_current_discards_to_base()
	return GnosisFunctionResult.ok(_store().create_value(true))

func _add_variant_level_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	if not FallingBlockGameFlags.is_include_upgrades(_svc.context):
		return GnosisFunctionResult.fail("Upgrades are disabled for this run.")
	var raw := _read_string(parameters, FallingBlockEvents.PAYLOAD_VARIANT_ID)
	if raw.is_empty():
		raw = _read_string(parameters, "variantId")
	if raw.is_empty():
		return GnosisFunctionResult.fail("AddVariantLevelDelta requires variantId.")
	var normalized := raw.strip_edges().to_lower()
	if not _svc._is_levelable_variant(normalized):
		return GnosisFunctionResult.fail("variantId '%s' cannot be leveled." % raw)
	var delta := _read_int(parameters, "delta", 1)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddVariantLevelDelta requires positive delta.")
	var previous := _svc._resolve_variant_level(normalized)
	var next := previous + delta
	_svc._write_variant_level(normalized, next)
	var payload := _store().create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_VARIANT_ID, normalized)
	payload.set_key("previousLevel", previous)
	payload.set_key("level", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)

func _play_falling_piece_feedback(parameters: GnosisNode) -> GnosisFunctionResult:
	var feedback_id := _read_string(parameters, "feedbackId")
	if feedback_id.is_empty():
		feedback_id = _read_string(parameters, "id")
	if feedback_id.is_empty():
		return GnosisFunctionResult.fail("PlayFallingPieceFeedback requires feedbackId.")
	_svc._play_animation_feedback(feedback_id.strip_edges())
	return GnosisFunctionResult.ok()

func _set_falling_piece_variant(parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	var player: FallingBlockModels.PlayerState = _resolve_player(parameters)
	if player == null:
		return GnosisFunctionResult.fail("Unknown player for SetFallingPieceVariant.")
	var variant_id := _read_string(parameters, FallingBlockEvents.PAYLOAD_VARIANT_ID)
	if variant_id.is_empty():
		variant_id = _read_string(parameters, "variantId")
	if variant_id.is_empty():
		return GnosisFunctionResult.fail("SetFallingPieceVariant requires variantId.")
	variant_id = variant_id.strip_edges().to_lower()
	if not _svc._variant_exists(variant_id):
		return GnosisFunctionResult.fail("Unknown variantId '%s'." % variant_id)
	var piece_id := player.current_piece_instance_id
	if piece_id.is_empty():
		return GnosisFunctionResult.fail("No active falling piece.")
	var updated := 0
	var tags := _svc._resolve_variant_color_tags(variant_id)
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or cell.block_id.is_empty():
			continue
		if cell.piece_instance_id != piece_id or cell.is_locked:
			continue
		if _svc._cell_has_immutable_tag(cell):
			continue
		cell.variant_id = variant_id
		cell.tags = tags.duplicate()
		updated += 1
	if updated == 0:
		return GnosisFunctionResult.fail("No unlocked cells updated.")
	var payload := _store().create_object()
	payload.set_key("updatedCells", updated)
	payload.set_key(FallingBlockEvents.PAYLOAD_VARIANT_ID, variant_id)
	return GnosisFunctionResult.ok(payload)

func _destroy_current_piece(parameters: GnosisNode) -> GnosisFunctionResult:
	var player: FallingBlockModels.PlayerState = _resolve_player(parameters)
	if player == null or player.current_piece_instance_id.is_empty():
		return GnosisFunctionResult.fail("No active piece to destroy.")
	_svc._piece_lifecycle.clear_active_piece(_grid(), player)
	_svc._publish_spawn_needed(player.player_id, "destroy_current_piece")
	if player.current_piece_instance_id.is_empty():
		_svc._spawn_piece_for_player(player)
	return GnosisFunctionResult.ok(_store().create_value(true))

func _duplicate_current_deck_entry(_parameters: GnosisNode) -> GnosisFunctionResult:
	# Deck row duplication is handled by Deck service when integrated; acknowledge success for VFX chain.
	return GnosisFunctionResult.ok(_store().create_value(true))

func _clear_entire_grid_and_respawn(_parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	_svc._grid_system.clear_entire_grid(grid)
	for player in _svc._runtime_players:
		if player == null:
			continue
		player.current_piece_instance_id = ""
		player.current_piece_deck_entry_id = ""
		player.is_on_ground = false
		_svc._clear_lock_delay(player)
		_svc._publish_spawn_needed(player.player_id, "bomba")
		if player.current_piece_instance_id.is_empty():
			_svc._spawn_piece_for_player(player)
	return GnosisFunctionResult.ok(_store().create_value(true))

func _change_fall_speed(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _read_int(parameters, "deltaLevels", 0)
	if delta == 0:
		delta = _read_int(parameters, "delta", 0)
	var current_offset := FB.get_fb_int(_svc.context, "gravityLevelOffset", 0)
	FB.set_fb_int(_svc.context, "gravityLevelOffset", current_offset + delta)
	_svc._refresh_gravity_from_run_state()
	var payload := _store().create_object()
	payload.set_key("gravityLevelOffset", current_offset + delta)
	return GnosisFunctionResult.ok(payload)

func _spawn_trash_lines(parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	var line_count := clampi(_read_int(parameters, "lineCount", 1), 1, 50)
	var variant_id := _read_string(parameters, FallingBlockEvents.PAYLOAD_VARIANT_ID)
	if variant_id.is_empty():
		variant_id = "disabled"
	variant_id = variant_id.strip_edges().to_lower()
	var min_gaps := maxi(1, _read_int(parameters, "minGaps", 1))
	var max_gaps := maxi(min_gaps, _read_int(parameters, "maxGaps", 3))
	var stick_prob := clampf(_read_float(parameters, "gapColumnStickProbability", 0.55), 0.0, 1.0)
	var player_id := _read_string(parameters, FallingBlockEvents.PAYLOAD_PLAYER_ID)
	if player_id.is_empty() and not _svc._runtime_players.is_empty() and _svc._runtime_players[0]:
		player_id = _svc._runtime_players[0].player_id
	var lines_spawned := 0
	var total_cleared := 0
	for _i in range(line_count):
		var gap_count := _choose_trash_gap_count(grid.width, min_gaps, max_gaps)
		var last_gap := FB.get_fb_int(_svc.context, "tetrisTrashLineLastGapColumn", -1)
		var gap_cols := _choose_trash_gap_columns(grid.width, gap_count, last_gap, stick_prob)
		if not gap_cols.is_empty():
			FB.set_fb_int(_svc.context, "tetrisTrashLineLastGapColumn", gap_cols[0])
		_shift_grid_rows_up(grid)
		_bump_player_origins_y(1)
		_fill_bottom_trash_row(grid, gap_cols, variant_id)
		var cleared := _svc._process_grid_line_clears(player_id)
		total_cleared += cleared
		lines_spawned += 1
		if _svc._has_top_out():
			break
	var payload := _store().create_object()
	payload.set_key("linesSpawned", lines_spawned)
	payload.set_key("linesClearedFromTrash", total_cleared)
	return GnosisFunctionResult.ok(payload)

func _clear_random_non_empty_locked_rows(parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	var min_clear := maxi(1, _read_int(parameters, "minLines", 2))
	var max_clear := maxi(min_clear, _read_int(parameters, "maxLines", 8))
	var candidates: Array[int] = []
	for y in range(grid.height):
		if _row_has_locked_block(y):
			candidates.append(y)
	if candidates.is_empty():
		var noop := _store().create_object()
		noop.set_key("linesCleared", 0)
		return GnosisFunctionResult.ok(noop)
	var target := clampi(_rng_int(min_clear, max_clear + 1, min_clear), 1, candidates.size())
	candidates.shuffle()
	var rows: Array = candidates.slice(0, target)
	var cleared := _clear_selected_rows(rows)
	var payload := _store().create_object()
	payload.set_key("linesCleared", cleared)
	return GnosisFunctionResult.ok(payload)

func _clear_rows_above_lowest_column(_parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	var lowest := _lowest_nonempty_column_height(grid)
	if lowest < 0:
		var noop := _store().create_object()
		noop.set_key("linesCleared", 0)
		return GnosisFunctionResult.ok(noop)
	var rows: Array = []
	for y in range(lowest, grid.height):
		if _row_has_locked_block(y):
			rows.append(y)
	var cleared := _clear_selected_rows(rows)
	var payload := _store().create_object()
	payload.set_key("linesCleared", cleared)
	payload.set_key("lowestColumnHeight", lowest)
	return GnosisFunctionResult.ok(payload)

func _fill_single_gaps_and_clear(_parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	var fills := 0
	var completed: Array = []
	for y in range(grid.height):
		var empty_count := 0
		var empty_x := -1
		var has_locked := false
		var row_start := y * grid.width
		for x in range(grid.width):
			var cell: CellState = grid.cells[row_start + x]
			if cell != null and cell.is_locked and not cell.block_id.is_empty():
				has_locked = true
			else:
				empty_count += 1
				empty_x = x
		if has_locked and empty_count == 1 and empty_x >= 0:
			var gum := CellState.new()
			gum.block_id = str(_svc._new_block_id())
			gum.piece_instance_id = "gum_ability"
			gum.ultravibe_id = "gum_ability"
			gum.variant_id = "red"
			gum.tags = _svc._resolve_variant_color_tags("red")
			gum.is_locked = true
			grid.cells[row_start + empty_x] = gum
			fills += 1
			completed.append(y)
	var cleared := _clear_selected_rows(completed) if not completed.is_empty() else 0
	var payload := _store().create_object()
	payload.set_key("gapsFilled", fills)
	payload.set_key("linesCleared", cleared)
	return GnosisFunctionResult.ok(payload)

func _apply_stack_gravity_and_clear(parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null:
		return GnosisFunctionResult.fail("Grid not bound.")
	_svc._tag_sim.apply_slippery_locked_stack_gravity(grid)
	var full_rows: Array = []
	for y in range(grid.height):
		var full := true
		for x in range(grid.width):
			var cell: CellState = grid.cells[y * grid.width + x]
			if cell == null or cell.block_id.is_empty() or not cell.is_locked:
				full = false
				break
		if full:
			full_rows.append(y)
	var cleared := _clear_selected_rows(full_rows)
	var payload := _store().create_object()
	payload.set_key("linesCleared", cleared)
	return GnosisFunctionResult.ok(payload)

func _mirror_right_half_and_clear(_parameters: GnosisNode) -> GnosisFunctionResult:
	var grid := _grid()
	if grid == null or grid.width <= 1:
		return GnosisFunctionResult.fail("Invalid grid size.")
	var left_half := grid.width / 2
	var source := []
	for c in grid.cells:
		source.append(c.duplicate_shallow() if c != null else CellState.new())
	var changed := 0
	for y in range(grid.height):
		var row := y * grid.width
		for x in range(left_half):
			var left_idx := row + x
			var left_cell: CellState = grid.cells[left_idx]
			if left_cell != null and not left_cell.is_locked and not left_cell.block_id.is_empty():
				continue
			var right_x := grid.width - 1 - x
			var right_src: CellState = source[row + right_x]
			var right_locked := right_src != null and right_src.is_locked and not right_src.block_id.is_empty()
			var left_locked := left_cell != null and left_cell.is_locked and not left_cell.block_id.is_empty()
			if not right_locked:
				if left_locked:
					grid.cells[left_idx] = CellState.new()
					changed += 1
				continue
			var mirrored := CellState.new()
			mirrored.block_id = str(_svc._new_block_id())
			mirrored.piece_instance_id = right_src.piece_instance_id if not right_src.piece_instance_id.is_empty() else "butterfly_%d_%d" % [x, y]
			mirrored.ultravibe_id = right_src.ultravibe_id
			mirrored.variant_id = right_src.variant_id
			mirrored.tags = right_src.tags.duplicate()
			mirrored.is_locked = true
			grid.cells[left_idx] = mirrored
			changed += 1
	var full_rows: Array = []
	for y in range(grid.height):
		var full := true
		for x in range(grid.width):
			var cell: CellState = grid.cells[y * grid.width + x]
			if cell == null or cell.block_id.is_empty() or not cell.is_locked:
				full = false
				break
		if full:
			full_rows.append(y)
	var cleared := _clear_selected_rows(full_rows)
	var payload := _store().create_object()
	payload.set_key("changedLockedCells", changed)
	payload.set_key("linesCleared", cleared)
	return GnosisFunctionResult.ok(payload)

func _execute_grid_shift_ability(_parameters: GnosisNode) -> GnosisFunctionResult:
	if not _svc._coop.execute_grid_shift():
		return GnosisFunctionResult.fail("GridShift ability execution failed.")
	_svc._play_animation_feedback("shuffle")
	var payload := _store().create_object()
	payload.set_key("abilityId", "gridShift")
	return GnosisFunctionResult.ok(payload)

func _grant_random_eligible_upgrade(parameters: GnosisNode) -> GnosisFunctionResult:
	var res = _svc.call_service("Upgrade", "GetRandomEligibleUpgrade", parameters)
	if res == null:
		return GnosisFunctionResult.fail("GetRandomEligibleUpgrade failed.")
	if res is GnosisFunctionResult and not res.is_ok:
		return res
	var upgrade_id := ""
	if res is GnosisNode and res.is_valid():
		var n: GnosisNode = res.get_node("upgradeId")
		if n.is_valid():
			upgrade_id = str(n.value)
	if upgrade_id.is_empty():
		return GnosisFunctionResult.fail("No eligible upgrade.")
	var add := _store().create_object()
	add.set_key("upgradeId", upgrade_id)
	add.set_key("categoryId", "default")
	return _svc.call_service("Upgrade", "AddUpgrade", add)

func _add_pending_points(_parameters: GnosisNode) -> GnosisFunctionResult:
	return GnosisFunctionResult.ok(_store().create_value(true))

func _add_objective_progress(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := FB.read_scalable(parameters.get_node("delta") if parameters else GnosisNode.new(null))
	if delta.compare_to(GnosisScalableValue.zero()) <= 0:
		delta = FB.read_scalable(parameters.get_node("objectiveDelta") if parameters else GnosisNode.new(null))
	if delta.compare_to(GnosisScalableValue.zero()) <= 0:
		delta = FB.read_scalable(parameters.get_node("amount") if parameters else GnosisNode.new(null))
	if delta.compare_to(GnosisScalableValue.zero()) <= 0:
		return GnosisFunctionResult.fail("AddObjectiveProgress requires delta.")
	var lines := maxi(0, delta.to_int())
	var player: FallingBlockModels.PlayerState = _svc._runtime_players[0] if not _svc._runtime_players.is_empty() else null
	if player:
		_svc._apply_round_progress_after_line_clear(player, lines, GnosisScalableValue.zero())
	var payload := _store().create_object()
	payload.set_key("delta", lines)
	return GnosisFunctionResult.ok(payload)

func _clear_selected_rows(rows: Array) -> int:
	if rows.is_empty():
		return 0
	var player_id := ""
	if not _svc._runtime_players.is_empty() and _svc._runtime_players[0]:
		player_id = _svc._runtime_players[0].player_id
	return _svc._apply_synthetic_line_clear(rows, player_id)

func _row_has_locked_block(y: int) -> bool:
	var grid := _grid()
	if grid == null:
		return false
	var row_start := y * grid.width
	for x in range(grid.width):
		var cell: CellState = grid.cells[row_start + x]
		if cell != null and cell.is_locked and not cell.block_id.is_empty():
			return true
	return false

func _lowest_nonempty_column_height(grid: FallingBlockModels.GridState) -> int:
	var lowest := 999999
	for x in range(grid.width):
		var highest := -1
		for y in range(grid.height):
			var cell: CellState = grid.cells[y * grid.width + x]
			if cell != null and cell.is_locked and not cell.block_id.is_empty():
				highest = y
		if highest >= 0:
			lowest = mini(lowest, highest + 1)
	return lowest if lowest != 999999 else -1

func _choose_trash_gap_count(width: int, min_gaps: int, max_gaps: int) -> int:
	var max_possible := maxi(0, width - 1)
	if max_possible <= 0:
		return 0
	var mn := clampi(min_gaps, 1, max_possible)
	var mx := clampi(maxi(max_gaps, mn), mn, max_possible)
	return _rng_int(mn, mx + 1, mn)

func _choose_trash_gap_columns(width: int, gap_count: int, last_gap: int, stick_prob: float) -> Array[int]:
	var chosen: Array[int] = []
	if gap_count <= 0 or width <= 0:
		return chosen
	var set := {}
	if _rng_int(0, 100, 0) < int(round(stick_prob * 100.0)) and last_gap >= 0 and last_gap < width:
		set[last_gap] = true
		chosen.append(last_gap)
	while set.size() < gap_count:
		var x := _rng_int(0, width, 0)
		if not set.has(x):
			set[x] = true
			chosen.append(x)
	return chosen

func _shift_grid_rows_up(grid: FallingBlockModels.GridState) -> void:
	var w := grid.width
	var h := grid.height
	for y in range(h - 1, 0, -1):
		var dst := y * w
		var src := (y - 1) * w
		for x in range(w):
			grid.cells[dst + x] = grid.cells[src + x]
	for x in range(w):
		grid.cells[x] = CellState.new()

func _bump_player_origins_y(delta_y: int) -> void:
	if delta_y == 0:
		return
	for player in _svc._runtime_players:
		if player == null:
			continue
		player.current_piece_origin.y += delta_y

func _fill_bottom_trash_row(grid: FallingBlockModels.GridState, gap_cols: Array, variant_id: String) -> void:
	var gap_set := {}
	for c in gap_cols:
		gap_set[c] = true
	var piece_id := "trash_%d" % (_svc._piece_instance_counter + 1)
	for x in range(grid.width):
		if gap_set.has(x):
			grid.cells[x] = CellState.new()
			continue
		var trash := CellState.new()
		trash.block_id = str(_svc._new_block_id())
		trash.piece_instance_id = piece_id
		trash.ultravibe_id = "Line5"
		trash.variant_id = variant_id
		trash.tags = _svc._resolve_variant_color_tags(variant_id)
		trash.is_locked = true
		grid.cells[x] = trash
