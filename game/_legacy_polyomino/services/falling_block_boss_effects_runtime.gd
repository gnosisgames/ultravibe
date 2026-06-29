class_name FallingBlockBossEffectsRuntime
extends RefCounted

## Native boss effect execution (Unity BossEffects.Native.partial.cs parity).

const FB := preload("res://game/services/falling_block_ephemeral.gd")
const CellState = FallingBlockModels.CellState

const DEFAULT_ZEUS_MOVE_THRESHOLD := 20
const DEFAULT_TITANOS_AUTO_DROP_SECONDS := 2.25
const DEFAULT_ICARUS_PLACEMENT_SECONDS := 5.5
const DEFAULT_NEMESIS_DISABLE_SECONDS := 4.5
const DEFAULT_HYPNOS_DENY_PERCENT := 18
const DEFAULT_BOREAS_WIND_EVERY_TICKS := 18
const DEFAULT_CHAOS_ROTATION_EVERY_TICKS := 18
const DEFAULT_THEMIS_LINES_PER_TRASH := 3
const DEFAULT_PERSEPHONE_DISCARDS_PER_LINE := 1
const BASE_COLORS := ["red", "green", "orange", "blue"]

var _svc: FallingBlockService
var _boss_chaos_random_rotation := false
var _boss_chaos_rotation_tick := 0
var _boss_chaos_rotation_every := DEFAULT_CHAOS_ROTATION_EVERY_TICKS
var _boss_fates_ghost_only := false
var _boss_riza_base_colors_only := false
var _boss_spawn_replace_negative: Dictionary = {}
var _boss_hypnos_unreliable := false
var _boss_hypnos_deny_percent := DEFAULT_HYPNOS_DENY_PERCENT
var _boss_icarus_timer := false
var _boss_icarus_deadline := 0.0
var _boss_icarus_seconds := DEFAULT_ICARUS_PLACEMENT_SECONDS
var _boss_icarus_tracked_piece := ""
var _boss_themis_trash := false
var _boss_themis_lines_accum := 0
var _boss_themis_lines_per_trash := DEFAULT_THEMIS_LINES_PER_TRASH
var _boss_persephone_tax := false
var _boss_persephone_per_line := DEFAULT_PERSEPHONE_DISCARDS_PER_LINE
var _boss_titanos_auto_drop := false
var _boss_titanos_drop_at := 0.0
var _boss_titanos_seconds := DEFAULT_TITANOS_AUTO_DROP_SECONDS
var _boss_zeus_move_drop := false
var _boss_zeus_move_threshold := DEFAULT_ZEUS_MOVE_THRESHOLD
var _boss_zeus_move_count := 0
var _boss_nemesis_disable := false
var _boss_nemesis_disable_at := 0.0
var _boss_nemesis_seconds := DEFAULT_NEMESIS_DISABLE_SECONDS
var _boss_nemesis_tracked := ""
var _boss_nemesis_applied := false
var _boss_xenon_convert := false
var _boss_boreas_wind := false
var _boss_boreas_tick := 0
var _boss_boreas_every := DEFAULT_BOREAS_WIND_EVERY_TICKS
var _boss_invert_controls := false
var _native_gravity_delta := 0

func _init(service: FallingBlockService) -> void:
	_svc = service

func reset_for_new_run() -> void:
	_boss_chaos_random_rotation = false
	_boss_chaos_rotation_tick = 0
	_boss_fates_ghost_only = false
	_boss_riza_base_colors_only = false
	_boss_spawn_replace_negative.clear()
	_boss_hypnos_unreliable = false
	_boss_hypnos_deny_percent = DEFAULT_HYPNOS_DENY_PERCENT
	_boss_icarus_timer = false
	_boss_icarus_tracked_piece = ""
	_boss_themis_trash = false
	_boss_themis_lines_accum = 0
	_boss_persephone_tax = false
	_boss_titanos_auto_drop = false
	_boss_zeus_move_drop = false
	_boss_zeus_move_count = 0
	_boss_nemesis_disable = false
	_boss_nemesis_tracked = ""
	_boss_nemesis_applied = false
	_boss_xenon_convert = false
	_boss_boreas_wind = false
	_boss_boreas_tick = 0
	_boss_invert_controls = false
	_native_gravity_delta = 0
	FB.set_fb_bool(_svc.context, "bossEffectSuppressGhost", false)

func try_apply_native(effect_id: String, parameters: GnosisNode) -> bool:
	match effect_id.strip_edges():
		"ReduceGravitySpeed":
			var delta := _read_int(parameters, "fallSpeedDelta", 0)
			if delta == 0:
				delta = _read_int(parameters, "deltaLevels", -1)
			_native_gravity_delta += delta
			var offset := FB.get_fb_int(_svc.context, "gravityLevelOffset", 0)
			FB.set_fb_int(_svc.context, "gravityLevelOffset", offset + delta)
			_svc._refresh_gravity_from_run_state()
			return true
		"EnableRandomRotation":
			_boss_chaos_random_rotation = true
			_boss_chaos_rotation_tick = 0
			_boss_chaos_rotation_every = maxi(1, _read_int(parameters, "rotationEveryTicks", DEFAULT_CHAOS_ROTATION_EVERY_TICKS))
			return true
		"GhostOnly":
			_boss_fates_ghost_only = true
			return true
		"ForceBaseColorsOnly":
			_boss_riza_base_colors_only = true
			return true
		"UnreliableInputs":
			_boss_hypnos_unreliable = true
			_boss_hypnos_deny_percent = clampi(_read_int(parameters, "denyPercent", DEFAULT_HYPNOS_DENY_PERCENT), 1, 95)
			return true
		"SpawnTrashLineIfNotPlacedWithin4Seconds":
			_boss_icarus_timer = true
			_boss_icarus_seconds = maxf(0.1, _read_float(parameters, "placementSeconds", DEFAULT_ICARUS_PLACEMENT_SECONDS))
			return true
		"SpawnTrashLineEvery2LinesCleared":
			_boss_themis_trash = true
			_boss_themis_lines_accum = 0
			_boss_themis_lines_per_trash = maxi(1, _read_int(parameters, "linesPerTrash", DEFAULT_THEMIS_LINES_PER_TRASH))
			return true
		"RemoveDiscardsPerLineCleared":
			_boss_persephone_tax = true
			_boss_persephone_per_line = maxi(1, _read_int(parameters, "discardsPerLine", DEFAULT_PERSEPHONE_DISCARDS_PER_LINE))
			return true
		"AutoDropAfterDelay":
			_boss_titanos_auto_drop = true
			_boss_titanos_drop_at = INF
			_boss_titanos_seconds = maxf(0.1, _read_float(parameters, "delaySeconds", DEFAULT_TITANOS_AUTO_DROP_SECONDS))
			return true
		"AutoDropAfterMoveCount":
			_boss_zeus_move_drop = true
			_boss_zeus_move_threshold = maxi(1, _read_int(parameters, "moveCount", DEFAULT_ZEUS_MOVE_THRESHOLD))
			return true
		"DisablePieceAfterDelay":
			_boss_nemesis_disable = true
			_boss_nemesis_disable_at = INF
			_boss_nemesis_seconds = maxf(0.1, _read_float(parameters, "delaySeconds", DEFAULT_NEMESIS_DISABLE_SECONDS))
			return true
		"ConvertRandomBlockToNegativeOnPlacement":
			_boss_xenon_convert = true
			return true
		"ReplaceBaseColorWithNegativeOnSpawn":
			var base_color := _read_string(parameters, "baseColor")
			if base_color.is_empty():
				base_color = _read_string(parameters, "variantId")
			base_color = base_color.strip_edges().to_lower()
			if base_color in BASE_COLORS:
				_boss_spawn_replace_negative[base_color] = true
				return true
			return false
		"EnableWind":
			_boss_boreas_wind = true
			_boss_boreas_tick = 0
			_boss_boreas_every = maxi(1, _read_int(parameters, "windEveryTicks", DEFAULT_BOREAS_WIND_EVERY_TICKS))
			return true
		"DisableGhost":
			FB.set_fb_bool(_svc.context, "bossEffectSuppressGhost", true)
			return true
		"InvertControls":
			_boss_invert_controls = true
			return true
	return false

func try_clear_native(effect_id: String) -> bool:
	match effect_id.strip_edges():
		"ReduceGravitySpeed":
			if _native_gravity_delta != 0:
				var offset := FB.get_fb_int(_svc.context, "gravityLevelOffset", 0)
				FB.set_fb_int(_svc.context, "gravityLevelOffset", offset - _native_gravity_delta)
				_native_gravity_delta = 0
				_svc._refresh_gravity_from_run_state()
			return true
		"EnableRandomRotation":
			_boss_chaos_random_rotation = false
			_boss_chaos_rotation_tick = 0
			return true
		"GhostOnly":
			_boss_fates_ghost_only = false
			return true
		"ForceBaseColorsOnly":
			_boss_riza_base_colors_only = false
			return true
		"UnreliableInputs":
			_boss_hypnos_unreliable = false
			return true
		"SpawnTrashLineIfNotPlacedWithin4Seconds":
			_boss_icarus_timer = false
			_boss_icarus_tracked_piece = ""
			return true
		"SpawnTrashLineEvery2LinesCleared":
			_boss_themis_trash = false
			_boss_themis_lines_accum = 0
			return true
		"RemoveDiscardsPerLineCleared":
			_boss_persephone_tax = false
			return true
		"AutoDropAfterDelay":
			_boss_titanos_auto_drop = false
			return true
		"AutoDropAfterMoveCount":
			_boss_zeus_move_drop = false
			_boss_zeus_move_count = 0
			return true
		"DisablePieceAfterDelay":
			_boss_nemesis_disable = false
			_boss_nemesis_tracked = ""
			_boss_nemesis_applied = false
			return true
		"ConvertRandomBlockToNegativeOnPlacement":
			_boss_xenon_convert = false
			return true
		"ReplaceBaseColorWithNegativeOnSpawn":
			_boss_spawn_replace_negative.clear()
			return true
		"EnableWind":
			_boss_boreas_wind = false
			_boss_boreas_tick = 0
			return true
		"DisableGhost":
			FB.set_fb_bool(_svc.context, "bossEffectSuppressGhost", false)
			return true
		"InvertControls":
			_boss_invert_controls = false
			return true
	return false

func is_ghost_suppressed() -> bool:
	return FB.get_fb_bool(_svc.context, "bossEffectSuppressGhost", false)

func is_active_piece_hidden() -> bool:
	return _boss_fates_ghost_only

func should_hypnos_deny() -> bool:
	if not _boss_hypnos_unreliable:
		return false
	return _svc._rng.randi_range(0, 99) < clampi(_boss_hypnos_deny_percent, 0, 99)

func should_invert_horizontal() -> bool:
	return _boss_invert_controls

func mutate_spawn(variant_id: String) -> String:
	var result := variant_id.strip_edges().to_lower()
	if result.is_empty():
		return result
	if _boss_riza_base_colors_only and not _svc._is_negative_variant(result):
		if result not in BASE_COLORS:
			result = BASE_COLORS[_svc._rng.randi_range(0, BASE_COLORS.size() - 1)]
	if result in BASE_COLORS and _boss_spawn_replace_negative.has(result):
		var neg := _svc._pick_random_variant_by_polarity(true)
		if not neg.is_empty():
			result = neg
	return result

func on_piece_spawned(player: FallingBlockModels.PlayerState) -> void:
	if player == null or player.current_piece_instance_id.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if _boss_icarus_timer:
		_boss_icarus_tracked_piece = player.current_piece_instance_id
		_boss_icarus_deadline = now + _boss_icarus_seconds
	if _boss_titanos_auto_drop:
		_boss_titanos_drop_at = now + _boss_titanos_seconds
	if _boss_zeus_move_drop:
		_boss_zeus_move_count = 0
	if _boss_nemesis_disable:
		_boss_nemesis_tracked = player.current_piece_instance_id
		_boss_nemesis_disable_at = now + _boss_nemesis_seconds
		_boss_nemesis_applied = false

func on_move_input(player: FallingBlockModels.PlayerState) -> void:
	if not _boss_zeus_move_drop or player == null or player.current_piece_instance_id.is_empty():
		return
	_boss_zeus_move_count += 1
	if _boss_zeus_move_count >= _boss_zeus_move_threshold:
		_boss_zeus_move_count = 0
		_svc._execute_hard_drop(player)

func on_player_tick(player: FallingBlockModels.PlayerState) -> void:
	if player == null or player.current_piece_instance_id.is_empty():
		return
	var grid := _svc._runtime_grid_state
	var now := Time.get_ticks_msec() / 1000.0
	if _boss_boreas_wind:
		_boss_boreas_tick += 1
		if _boss_boreas_tick >= _boss_boreas_every:
			_boss_boreas_tick = 0
			if _piece_has_tag(player.current_piece_instance_id, "soft") and not _piece_has_tag(player.current_piece_instance_id, "unpushable"):
				var dir := -1 if _svc._rng.randi_range(0, 1) == 0 else 1
				_svc._piece_lifecycle.try_move_piece(grid, player, Vector2i(dir, 0))
	if _boss_chaos_random_rotation:
		_boss_chaos_rotation_tick += 1
		if _boss_chaos_rotation_tick >= _boss_chaos_rotation_every:
			_boss_chaos_rotation_tick = 0
			var cw := _svc._rng.randi_range(0, 1) == 0
			_svc._piece_lifecycle.try_rotate_piece(grid, player, cw)
	if _boss_icarus_timer and player.current_piece_instance_id == _boss_icarus_tracked_piece and now >= _boss_icarus_deadline:
		_spawn_trash_for_boss(player.player_id, 1)
		_boss_icarus_deadline = now + _boss_icarus_seconds
	if _boss_titanos_auto_drop and now >= _boss_titanos_drop_at:
		_boss_titanos_drop_at = now + _boss_titanos_seconds
		_svc._execute_hard_drop(player)
		return
	if _boss_nemesis_disable and not _boss_nemesis_applied and player.current_piece_instance_id == _boss_nemesis_tracked and now >= _boss_nemesis_disable_at:
		_apply_disabled_to_active_piece(player)
		_boss_nemesis_applied = true

func after_physical_line_cleared(player_id: String, raw_lines: int) -> void:
	if raw_lines <= 0:
		return
	if _boss_themis_trash:
		_boss_themis_lines_accum += raw_lines
		while _boss_themis_lines_accum >= _boss_themis_lines_per_trash:
			_boss_themis_lines_accum -= _boss_themis_lines_per_trash
			_spawn_trash_for_boss(player_id, 1)
	if _boss_persephone_tax:
		var amount := raw_lines * _boss_persephone_per_line
		var params := _svc.context.store.create_object()
		params.set_key(FallingBlockEvents.PAYLOAD_DISCARD_ADD_AMOUNT, float(amount))
		_svc._invocations.invoke("RemoveDiscards", params)

func apply_xenon_on_locked_piece(piece_id: String) -> void:
	if not _boss_xenon_convert or piece_id.is_empty():
		return
	var grid := _svc._runtime_grid_state
	if grid == null:
		return
	var neg := _svc._pick_random_variant_by_polarity(true)
	if neg.is_empty():
		return
	var candidates: Array[int] = []
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell != null and cell.is_locked and not cell.block_id.is_empty():
			candidates.append(i)
	if candidates.is_empty():
		return
	var pick := candidates[_svc._rng.randi_range(0, candidates.size() - 1)]
	var chosen: CellState = grid.cells[pick]
	if chosen != null and not _svc._cell_has_immutable_tag(chosen):
		chosen.variant_id = neg
		chosen.tags = _svc._resolve_variant_color_tags(neg)

func _spawn_trash_for_boss(player_id: String, line_count: int) -> void:
	var params := _svc.context.store.create_object()
	params.set_key("lineCount", line_count)
	params.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player_id)
	_svc._invocations.invoke("SpawnTrashLines", params)

func _apply_disabled_to_active_piece(player: FallingBlockModels.PlayerState) -> void:
	var grid := _svc._runtime_grid_state
	if grid == null or player == null:
		return
	var pid := player.current_piece_instance_id
	for i in range(grid.cells.size()):
		var cell: CellState = grid.cells[i]
		if cell == null or cell.block_id.is_empty() or cell.is_locked:
			continue
		if cell.piece_instance_id != pid:
			continue
		if not _svc._cell_has_immutable_tag(cell):
			cell.variant_id = "disabled"
			cell.tags = []

func _piece_has_tag(piece_id: String, tag: String) -> bool:
	var grid := _svc._runtime_grid_state
	if grid == null:
		return false
	for cell in grid.cells:
		if cell == null or cell.piece_instance_id != piece_id or cell.is_locked:
			continue
		for t in cell.tags:
			if str(t).to_lower() == tag.to_lower():
				return true
	return false

func _read_string(params: GnosisNode, key: String) -> String:
	if params == null or not params.is_valid():
		return ""
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value)
	return ""

func _read_int(params: GnosisNode, key: String, default_val: int) -> int:
	if params == null or not params.is_valid():
		return default_val
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return int(round(float(n.value)))
	return default_val

func _read_float(params: GnosisNode, key: String, default_val: float) -> float:
	if params == null or not params.is_valid():
		return default_val
	var n: GnosisNode = params.get_node(key)
	if n.is_valid() and n.value != null:
		return float(n.value)
	return default_val
