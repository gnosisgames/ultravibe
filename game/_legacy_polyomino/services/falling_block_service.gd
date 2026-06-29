class_name FallingBlockService
extends GnosisService

const LOCK_DELAY_SECONDS := 0.5
const DEFAULT_GRID_WIDTH := 10
const DEFAULT_GRID_VISIBLE_HEIGHT := 20
const DEFAULT_GRID_HIDDEN_ROWS := 4
const MIN_GRID_WIDTH := 4
const MAX_GRID_WIDTH := 64
const PIECE_SPAWN_LOCK_GRACE_TICKS := 2
const MIN_SECONDS_AFTER_SPAWN_BEFORE_HARD_DROP := 0.15
const MIN_SECONDS_AFTER_SPAWN_BEFORE_LOCK_DELAY := 0.15
const MIN_SECONDS_BETWEEN_PLAYER_HARD_DROPS := 0.05
const GRAVITY_TICK_SECONDS := 0.5
const MAX_LOCK_DELAY_REFRESHES_PER_PIECE := 15

const RunState = FallingBlockModels.RunState
const GridState = FallingBlockModels.GridState
const PlayerState = FallingBlockModels.PlayerState
const InputEventData = FallingBlockModels.InputEventData
const E = preload("res://game/services/falling_block_events.gd")
const FB = preload("res://game/services/falling_block_ephemeral.gd")
const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")
const RunSnapshot = preload("res://game/services/falling_block_run_snapshot.gd")
const SpawnResolver = preload("res://game/services/falling_block_spawn_resolver.gd")

const DEFAULT_VARIANT_BASE_POINTS := 10
const DEFAULT_VARIANT_BASE_MULTI := 1.0
const MAX_ROUNDS_ADVANCED_PER_SCORE_BURST := 1

# Ephemeral.fallingBlock leaf keys (mirror FallingBlockEphemeralPaths.cs)
const EPHEMERAL_CURRENT_ROUND := "currentRound"
const EPHEMERAL_ROUND_LINES_CURRENT := "roundLinesCurrent"
const EPHEMERAL_ROUND_LINES_NEEDED := "roundLinesNeeded"
const EPHEMERAL_RUN_TOTAL_SCORE := "runTotalScore"
const EPHEMERAL_ROUNDS_FINISHED := "roundsFinishedThisRun"
const EPHEMERAL_VARIANT_LEVELS := "variantLevels"
const EPHEMERAL_LAST_GAME_OVER_SUMMARY := "lastGameOverSummary"

# Fall speed (gravity) ephemeral leaf keys (mirror FallingBlockEphemeralPaths.cs)
const EPHEMERAL_FALL_SPEED_DIFFICULTY := "fallSpeedDifficulty"
const EPHEMERAL_GRAVITY_SECONDS_PER_CELL := "gravitySecondsPerCell"
const EPHEMERAL_GRAVITY_SECONDS_PER_CELL_STARTING := "gravitySecondsPerCellStarting"
const EPHEMERAL_GRAVITY_LEVEL_OFFSET := "gravityLevelOffset"
const EPHEMERAL_RUN_SCALING_LINES_PER_INTERVAL := "runScalingLinesPerInterval"
const EPHEMERAL_RUN_SCALING_LAST_LINE_INTERVAL_INDEX := "runScalingLastLineIntervalIndex"
const EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_INCREMENT := "negativeUltravibeChanceIncrement"
const EPHEMERAL_NEGATIVE_SCALING_LINES_PER_INTERVAL := "negativeScalingLinesPerInterval"
const EPHEMERAL_NEGATIVE_SCALING_LAST_LINE_INTERVAL_INDEX := "negativeScalingLastLineIntervalIndex"
const PACED_CLIMB_UPGRADE_ID := "pacedClimbUpgrade"
const PACED_CLIMB_LINES_PER_INTERVAL_BONUS_PER_STACK := 2
const DARK_PRESSURE_VALVE_UPGRADE_ID := "darkPressureValveUpgrade"
const DARK_PRESSURE_VALVE_LINES_PER_INTERVAL_BONUS_PER_STACK := 2
const STAT_LINES_CLEARED_TOTAL := "tetris.linesCleared.total"
const MIN_GRAVITY_SECONDS_PER_CELL := 0.01

# Discard ephemeral leaf keys (mirror FallingBlockGnosisService.Discard.Constants.partial.cs)
const EPHEMERAL_CURRENT_DISCARDS := "currentDiscards"
const EPHEMERAL_MIN_DISCARDS := "minDiscards"
const EPHEMERAL_MAX_DISCARDS := "maxDiscards"
const EPHEMERAL_BASE_DISCARDS := "baseDiscards"
const EPHEMERAL_PERSIST_DISCARDS := "persistDiscards"
const EPHEMERAL_SELECTED_CONSUMABLE_SLOT := "selectedConsumableSlotIndex"
const STAT_TOTAL_DISCARDS_USED := "totalDiscardsUsed"
const STAT_TOTAL_DISCARDS_ADDED := "totalDiscardsAdded"
const DISCARD_EPSILON := 0.0001

# Active boss/level effects registered via ApplyEffect/RemoveEffect invocations.
const EPHEMERAL_ACTIVE_EFFECTS := "activeEffects"

var _variant_base_points := {}
var _variant_base_multi := {}
var _variant_points_per_level := {}
var _variant_multi_per_level := {}

var _grid_system := GridSystem.new()
var _piece_lifecycle: PieceLifecycleSystem
var _ultravibe_registry := UltravibeRegistry.new()
var _rng := RandomNumberGenerator.new()
var _rewards: FallingBlockRewards = null
var _boon_score: FallingBlockBoonScore = null
var _bosses: FallingBlockBosses = null
var _invocations: FallingBlockInvocations = null
var _boss_fx: FallingBlockBossEffectsRuntime = null
var _tag_sim: FallingBlockTagSimulation = null
var _coop: FallingBlockCoop = null
var _gameplay_audio: FallingBlockGameplayAudio = null
var _variant_tags := {}
var _run_elapsed_seconds := 0.0

## Shared ability cooldown, in run-elapsed seconds. Using any ability puts ALL
## abilities on the same cooldown, so the cycler shows them all charging together.
var _ability_cooldown_ready_at := 0.0
var _ability_cooldown_total := 0.0
const DEFAULT_ABILITY_COOLDOWN_SECONDS := 90.0

var _runtime_run_state: RunState
var _runtime_grid_state: GridState
var _runtime_players: Array = []
var _piece_instance_counter := 0
var _gravity_accumulator := 0.0

var _input_subscription: RefCounted = null
var _spawn_ready_subscription: RefCounted = null

func _init() -> void:
	super("FallingBlock", GnosisLifetime.TRANSIENT)
	_piece_lifecycle = PieceLifecycleSystem.new(_grid_system)
	var variant_tags_resolver := func(variant_id: String): return _get_variant_tags(variant_id)
	_grid_system.bind_variant_tags_resolver(variant_tags_resolver)
	_piece_lifecycle.bind_variant_tags_resolver(variant_tags_resolver)
	_rng.randomize()
	_rewards = FallingBlockRewards.new(self)
	_boon_score = FallingBlockBoonScore.new(self)
	_bosses = FallingBlockBosses.new(self, _boon_score)
	_invocations = FallingBlockInvocations.new(self)
	_boss_fx = FallingBlockBossEffectsRuntime.new(self)
	_tag_sim = FallingBlockTagSimulation.new(self)
	_coop = FallingBlockCoop.new(self)
	_gameplay_audio = FallingBlockGameplayAudio.new()
	_gameplay_audio.bind_service(self)

func on_initialize() -> void:
	_ultravibe_registry.load_shapes()
	if context and context.event_bus:
		_input_subscription = context.event_bus.subscribe(
			FallingBlockEvents.REQUEST_FALLING_BLOCK_INPUT,
			_on_falling_block_input_requested,
			10
		)
		# The Deck service draws from FACT_FALLING_BLOCK_SPAWN_NEEDED and publishes
		# FACT_FALLING_BLOCK_SPAWN_PIECE_READY with the resolved ultravibe + variant.
		_spawn_ready_subscription = context.event_bus.subscribe(
			FallingBlockEvents.FACT_FALLING_BLOCK_SPAWN_PIECE_READY,
			_on_spawn_piece_ready,
			0
		)

func on_shutdown() -> void:
	_dispose_subscription(_input_subscription)
	_dispose_subscription(_spawn_ready_subscription)
	_input_subscription = null
	_spawn_ready_subscription = null

func on_run_started() -> void:
	# Continue restores runtime mirrors after adapters rebind; fresh runs are
	# seeded from the UI once Ephemeral settings are written.
	pass

func get_functions() -> Array:
	return [
		"ApplyEffect", "RemoveEffect", "GetBossPreviewHudState", "GetRunSummary",
		"SetFallingPieceVariant", "AddVariantLevelDelta", "DestroyCurrentPiece",
		"DuplicateCurrentDeckEntry", "PlayFallingPieceFeedback",
		"ClearEntireGridAndRespawn", "ChangeFallSpeed", "SpawnTrashLines",
		"ExecuteGridShiftAbility", "ExecuteGridSwapAbility",
		"ClearRandomNonEmptyLockedRows", "ClearRowsAboveLowestNonEmptyColumnHeight",
		"FillSingleGapsInNonEmptyRowsAndClear", "ApplyStackGravityAndClear",
		"MirrorRightHalfToLeftAndClear", "AddDiscards", "RemoveDiscards",
		"AddBaseDiscardsDelta", "ResetCurrentDiscardsToBase",
		"GrantRandomEligibleUpgrade", "AddObjectiveProgress", "AddPendingPoints",
	]

func invoke_function(name: String, parameters: GnosisNode) -> Variant:
	match name:
		"ApplyEffect":
			return _fn_apply_effect(parameters)
		"RemoveEffect":
			return _fn_remove_effect(parameters)
		"GetBossPreviewHudState":
			return _fn_get_boss_preview_hud_state()
		"GetRunSummary":
			return _fn_get_run_summary()
	if _invocations:
		return _invocations.invoke(name, parameters)
	return GnosisFunctionResult.fail("Unknown FallingBlock function '%s'." % name)

# Registers a named effect into Ephemeral.fallingBlock.activeEffects so boss/level
# invocations succeed and the run state reflects the active effect. Per-effect
# gameplay mutation is applied where the relevant system reads activeEffects.
func _fn_apply_effect(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store missing.")
	var effect_id := FB.read_string(parameters.get_node("effectId"), "").strip_edges() if parameters != null else ""
	if effect_id.is_empty():
		return GnosisFunctionResult.fail("effectId missing.")
	var effects := FB.get_fb_node(context, EPHEMERAL_ACTIVE_EFFECTS)
	if not effects.is_valid() or effects.get_type() != GnosisValueType.OBJECT:
		effects = context.store.create_object()
		FB.set_fb_node(context, EPHEMERAL_ACTIVE_EFFECTS, effects)
	var entry := context.store.create_object()
	if parameters != null and parameters.is_valid() and parameters.get_type() == GnosisValueType.OBJECT:
		for key in parameters.get_keys():
			entry.set_key(key, parameters.get_node(key))
	effects.set_key(effect_id, entry)
	var apply_result := _apply_catalog_falling_block_effect(effect_id, parameters)
	if apply_result != null and apply_result is GnosisFunctionResult and not apply_result.is_ok:
		return apply_result
	return GnosisFunctionResult.ok(context.store.create_value(true))

func _fn_remove_effect(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store missing.")
	var effect_id := FB.read_string(parameters.get_node("effectId"), "").strip_edges() if parameters != null else ""
	if effect_id.is_empty():
		return GnosisFunctionResult.fail("effectId missing.")
	var effects := FB.get_fb_node(context, EPHEMERAL_ACTIVE_EFFECTS)
	if effects.is_valid() and effects.get_type() == GnosisValueType.OBJECT and typeof(effects.value) == TYPE_DICTIONARY:
		effects.value.erase(effect_id)
	var clear_result := _clear_catalog_falling_block_effect(effect_id)
	if clear_result != null and clear_result is GnosisFunctionResult and not clear_result.is_ok:
		return clear_result
	return GnosisFunctionResult.ok(context.store.create_value(true))

func _resolve_falling_block_effect_handler(effect_id: String) -> String:
	var key := effect_id.strip_edges()
	if key.is_empty():
		return ""
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return "native"
	var effect_node := config_root.get_node("fallingBlockEffects").get_node(key)
	if not effect_node.is_valid() or effect_node.get_type() != GnosisValueType.OBJECT:
		return "native"
	return FB.read_string(effect_node.get_node("handler"), "native").strip_edges().to_lower()

func _resolve_rule_ids_for_effect(effect_id: String) -> Array[String]:
	var ids: Array[String] = []
	var key := effect_id.strip_edges()
	if key.is_empty():
		return ids
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return ids
	var effect_node := config_root.get_node("fallingBlockEffects").get_node(key)
	if not effect_node.is_valid() or effect_node.get_type() != GnosisValueType.OBJECT:
		return ids
	var params := effect_node.get_node("parameters")
	if not params.is_valid() or params.get_type() != GnosisValueType.OBJECT:
		return ids
	var rule_ids := params.get_node("ruleIds")
	if not rule_ids.is_valid() or rule_ids.get_type() != GnosisValueType.LIST:
		return ids
	for i in range(rule_ids.get_count()):
		var item := rule_ids.get_node(i)
		if item.is_valid() and item.get_type() == GnosisValueType.STRING:
			var rid := str(item.value).strip_edges()
			if not rid.is_empty():
				ids.append(rid)
	return ids

func _add_rule_by_template_id(rule_id: String) -> GnosisFunctionResult:
	var template := _load_rule_template(rule_id)
	if template == null or not template.is_valid():
		return GnosisFunctionResult.fail("Rule template '%s' not found." % rule_id)
	var rule_svc := context.engine.get_service("Rule") as GnosisRuleService if context and context.engine else null
	if rule_svc == null:
		return GnosisFunctionResult.fail("Rule service missing.")
	var args := context.store.create_object()
	args.set_key("definition", template)
	var result = rule_svc.invoke_function("AddRule", args)
	if result is GnosisFunctionResult:
		return result
	if result is GnosisNode and result.is_valid():
		return GnosisFunctionResult.ok(result)
	return GnosisFunctionResult.fail("AddRule failed.")

func _remove_rule_by_template_id(rule_id: String) -> GnosisFunctionResult:
	var rule_svc := context.engine.get_service("Rule") as GnosisRuleService if context and context.engine else null
	if rule_svc == null:
		return GnosisFunctionResult.fail("Rule service missing.")
	var args := context.store.create_object()
	args.set_key("ruleId", rule_id)
	var result = rule_svc.invoke_function("RemoveRuleById", args)
	if result is GnosisFunctionResult:
		return result
	if result is bool and result:
		return GnosisFunctionResult.ok(context.store.create_value(true))
	return GnosisFunctionResult.fail("RemoveRuleById failed for '%s'." % rule_id)

func _load_rule_template(rule_id: String) -> GnosisNode:
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return GnosisNode.new(null, context.store if context else null)
	var rules_root := config_root.get_node("rules")
	if not rules_root.is_valid():
		return GnosisNode.new(null, context.store)
	var template := rules_root.get_node(rule_id)
	if template.is_valid() and template.get_type() == GnosisValueType.OBJECT:
		return template
	return GnosisNode.new(null, context.store)

func _apply_catalog_falling_block_effect(effect_id: String, parameters: GnosisNode) -> GnosisFunctionResult:
	var handler := _resolve_falling_block_effect_handler(effect_id)
	if handler == "rule":
		for rule_id in _resolve_rule_ids_for_effect(effect_id):
			var res := _add_rule_by_template_id(rule_id)
			if not res.is_ok:
				return GnosisFunctionResult.fail(
					"ApplyEffect '%s' failed on rule '%s': %s" % [effect_id, rule_id, res.error]
				)
		return GnosisFunctionResult.ok(context.store.create_value(true))
	if _boss_fx and _boss_fx.try_apply_native(effect_id, parameters):
		return GnosisFunctionResult.ok(context.store.create_value(true))
	if handler == "native":
		return GnosisFunctionResult.fail("Unknown native effect '%s'." % effect_id)
	return GnosisFunctionResult.ok(context.store.create_value(true))

func _clear_catalog_falling_block_effect(effect_id: String) -> GnosisFunctionResult:
	var handler := _resolve_falling_block_effect_handler(effect_id)
	if handler == "rule":
		for rule_id in _resolve_rule_ids_for_effect(effect_id):
			var res := _remove_rule_by_template_id(rule_id)
			if res is GnosisFunctionResult and not res.is_ok:
				return GnosisFunctionResult.fail(
					"RemoveEffect '%s' failed on rule '%s'." % [effect_id, rule_id]
				)
		return GnosisFunctionResult.ok(context.store.create_value(true))
	if _boss_fx and _boss_fx.try_clear_native(effect_id):
		return GnosisFunctionResult.ok(context.store.create_value(true))
	return GnosisFunctionResult.ok(context.store.create_value(true))

func _fn_get_boss_preview_hud_state() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store missing.")
	var payload := context.store.create_object()
	payload.set_key("hasBoss", FB.get_fb_bool(context, "bossPreviewHasBoss", false))
	payload.set_key("showsCurrentEncounter", FB.get_fb_bool(context, "bossPreviewShowsCurrentEncounter", false))
	payload.set_key("secondsUntil", max(0, FB.get_fb_int(context, "bossPreviewSecondsUntil", 0)))
	payload.set_key("levelId", FB.get_fb_string(context, "bossPreviewLevelId", ""))
	payload.set_key("glyph", FB.get_fb_string(context, "bossPreviewGlyph", ""))
	payload.set_key("color", FB.get_fb_string(context, "bossPreviewColor", ""))
	return GnosisFunctionResult.ok(payload)

func _fn_get_run_summary() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store missing.")
	return GnosisFunctionResult.ok(_build_run_summary(_runtime_players[0] if not _runtime_players.is_empty() else null))

func set_runtime_references(
	run_state: RunState,
	grid_state: GridState,
	players: Array,
	_ultravibe_registry_external: UltravibeRegistry = null
) -> void:
	_runtime_run_state = run_state
	_runtime_grid_state = grid_state
	_runtime_players = players
	if _ultravibe_registry_external != null:
		_ultravibe_registry = _ultravibe_registry_external

func capture_runtime_snapshot() -> Dictionary:
	return RunSnapshot.capture(self)

func resume_saved_run(snapshot: Dictionary) -> void:
	if snapshot.is_empty() or _runtime_grid_state == null:
		return
	RunSnapshot.restore(self, snapshot)
	_cache_variant_score_from_configuration()
	if _bosses:
		_bosses.advance(int(floor(_run_elapsed_seconds)))

func is_run_game_over() -> bool:
	if _runtime_run_state and _runtime_run_state.is_game_over:
		return true
	for player in _runtime_players:
		if player and player.is_game_over:
			return true
	return false

func get_run_state() -> RunState:
	return _runtime_run_state

func get_piece_instance_counter() -> int:
	return _piece_instance_counter

func set_piece_instance_counter(value: int) -> void:
	_piece_instance_counter = maxi(0, value)

func get_gravity_accumulator() -> float:
	return _gravity_accumulator

func set_gravity_accumulator(value: float) -> void:
	_gravity_accumulator = max(0.0, value)

func get_run_elapsed_seconds() -> float:
	return _run_elapsed_seconds

func set_run_elapsed_seconds(value: float) -> void:
	_run_elapsed_seconds = max(0.0, value)
	_write_run_elapsed_seconds(_run_elapsed_seconds)

func get_ability_cooldown_ready_at() -> float:
	return _ability_cooldown_ready_at

func get_ability_cooldown_total() -> float:
	return _ability_cooldown_total

func set_ability_cooldown_state(ready_at: float, total: float) -> void:
	_ability_cooldown_ready_at = max(0.0, ready_at)
	_ability_cooldown_total = max(0.0, total)

func reduce_ability_cooldown_remaining_seconds(seconds: float) -> void:
	if seconds <= 0.0 or _ability_cooldown_ready_at <= _run_elapsed_seconds:
		return
	_ability_cooldown_ready_at = maxf(_run_elapsed_seconds, _ability_cooldown_ready_at - seconds)

func handle_run_started() -> void:
	if _runtime_grid_state == null:
		return
	_reset_theme_to_default_for_run_boundary()
	var player_count := _coop.get_player_count() if _coop else 1
	_sync_runtime_player_count(player_count)
	var grid_width := _read_configured_grid_width(player_count)
	var visible_height := _read_configured_visible_height()
	var hidden_rows := _read_configured_hidden_rows()
	_runtime_grid_state.width = grid_width
	_runtime_grid_state.hidden_rows = hidden_rows
	_runtime_grid_state.height = visible_height + hidden_rows
	FB.set_fb_int(context, "tetrisGridWidth", grid_width)
	FB.set_fb_int(context, "tetrisGridVisibleHeight", visible_height)
	FB.set_fb_int(context, "tetrisGridHiddenRows", hidden_rows)
	_runtime_grid_state.ensure_cells()
	# Start every run from a truly empty board. ensure_cells() only allocates when
	# the dimensions change, so without this an immediate restart (same grid size)
	# would inherit the previous run's leftover non-locked piece and the first
	# spawn would render merged into it.
	_grid_system.clear_entire_grid(_runtime_grid_state)
	if _runtime_run_state:
		_runtime_run_state.is_game_over = false
	for player in _runtime_players:
		if player:
			player.is_game_over = false
			player.current_piece_instance_id = ""
			player.is_on_ground = false
	_piece_instance_counter = 0
	_gravity_accumulator = 0.0
	_run_elapsed_seconds = 0.0
	_write_run_elapsed_seconds(0.0)
	_ability_cooldown_ready_at = 0.0
	_ability_cooldown_total = 0.0
	FB.set_fb_node(context, EPHEMERAL_LAST_GAME_OVER_SUMMARY, context.store.create_object())
	_cache_variant_score_from_configuration()
	_reset_round_progress_for_new_run()
	_reset_fall_speed_for_new_run()
	_reset_run_scaling_for_new_run()
	if _bosses:
		_bosses.reset_for_new_run()
	if _boss_fx:
		_boss_fx.reset_for_new_run()
	if _tag_sim:
		_tag_sim.reset_for_new_run()
	if _rewards:
		_rewards.ensure_offers_on_run_start()
	for player in _runtime_players:
		if player and not player.player_id.is_empty():
			_publish_spawn_needed(player.player_id, "run_started")

func process_frame(delta: float) -> void:
	if _runtime_run_state and _runtime_run_state.is_game_over:
		return
	_advance_run_elapsed(delta)
	_gravity_accumulator += delta
	var tick_seconds := _get_gravity_tick_interval_seconds()
	while _gravity_accumulator >= tick_seconds:
		_gravity_accumulator -= tick_seconds
		handle_tick()
		handle_lock_delay()
	for player in _runtime_players:
		if player == null or player.is_game_over:
			continue
		if _boss_fx:
			_boss_fx.on_player_tick(player)

# Run-elapsed-seconds clock (Ephemeral.timers.tetrisRunElapsed) drives the boss schedule.
func _advance_run_elapsed(delta: float) -> void:
	if delta <= 0.0:
		return
	var before := int(floor(_run_elapsed_seconds))
	_run_elapsed_seconds += delta
	var after := int(floor(_run_elapsed_seconds))
	_write_run_elapsed_seconds(_run_elapsed_seconds)
	if _bosses and after != before:
		_bosses.advance(after)

func _write_run_elapsed_seconds(value: float) -> void:
	if context == null or context.store == null or context.state == null:
		return
	var ep := context.state.root.get_node("Ephemeral")
	if not ep.is_valid() or ep.get_type() != GnosisValueType.OBJECT:
		return
	var timers := ep.get_node("timers")
	if not timers.is_valid() or timers.get_type() != GnosisValueType.OBJECT:
		timers = context.store.create_object()
		ep.set_node("timers", timers)
	timers.set_key("tetrisRunElapsed", value)

func read_run_elapsed_whole_seconds() -> int:
	return int(floor(_run_elapsed_seconds))

## HUD accessor: the live fall speed mapped onto the 0001-9999 readout, exactly
## like Unity (slowest level-1 gravity -> the difficulty's fastest cap).
func read_fall_speed_hud_display() -> int:
	if not context:
		return FallingBlockFallSpeedDisplay.HUD_DISPLAY_MIN
	var difficulty := _read_fall_speed_difficulty_id()
	var seconds := _read_gravity_seconds_per_cell()
	return FallingBlockFallSpeedDisplay.seconds_per_cell_to_hud_display(seconds, difficulty)

## HUD accessor: the negative-ultravibe chance mapped onto the 0001-9999 readout
## (run min -> max percent), matching Unity.
func read_negative_chance_hud_display() -> int:
	if not context:
		return FallingBlockNegativeChanceDisplay.HUD_DISPLAY_MIN
	var percent := maxi(0, FB.get_fb_int(context, "negativeUltravibeChance", 0))
	var min_percent := FB.get_fb_int(context, "negativeUltravibeChanceMin", FallingBlockNegativeChanceDisplay.DEFAULT_MIN_PERCENT)
	var max_percent := FB.get_fb_int(context, "negativeUltravibeChanceMax", FallingBlockNegativeChanceDisplay.DEFAULT_MAX_PERCENT)
	return FallingBlockNegativeChanceDisplay.percent_to_hud_display(percent, min_percent, max_percent)

## Test/back-door: advance the boss schedule to an explicit elapsed-seconds value.
func debug_set_run_elapsed_seconds(seconds: float) -> void:
	_run_elapsed_seconds = max(0.0, seconds)
	_write_run_elapsed_seconds(_run_elapsed_seconds)
	if _bosses:
		_bosses.advance(int(floor(_run_elapsed_seconds)))

func handle_tick() -> void:
	if _runtime_grid_state == null or _runtime_players.is_empty():
		return
	for player in _runtime_players:
		if player == null or player.is_game_over:
			continue
		if player.current_piece_instance_id.is_empty():
			continue
		if _piece_lifecycle.can_move_piece(_runtime_grid_state, player, Vector2i(0, -1)):
			_piece_lifecycle.try_move_piece(_runtime_grid_state, player, Vector2i(0, -1))
			player.piece_session_gravity_cells += 1
			player.is_on_ground = false
			_clear_lock_delay(player)
			continue
		if player.piece_spawn_grace_ticks_remaining > 0:
			var frame := Engine.get_frames_drawn()
			if player.piece_spawn_grace_last_decrement_frame != frame:
				player.piece_spawn_grace_ticks_remaining -= 1
				player.piece_spawn_grace_last_decrement_frame = frame
			player.is_on_ground = false
			_clear_lock_delay(player)
			continue
		var now := Time.get_ticks_msec() / 1000.0
		if now < player.lock_delay_allowed_after_unscaled_time:
			player.is_on_ground = false
			_clear_lock_delay(player)
			continue
		if not player.is_on_ground:
			player.is_on_ground = true
			_arm_lock_delay(player)

func handle_lock_delay() -> void:
	if _runtime_grid_state == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	for player in _runtime_players:
		if player == null or player.is_game_over or player.current_piece_instance_id.is_empty():
			continue
		if not player.is_on_ground or player.lock_delay_expires_at_unscaled_time <= 0.0:
			continue
		if player.piece_spawn_grace_ticks_remaining > 0:
			continue
		if now < player.lock_delay_allowed_after_unscaled_time:
			continue
		if _piece_lifecycle.can_move_piece(_runtime_grid_state, player, Vector2i(0, -1)):
			player.is_on_ground = false
			_clear_lock_delay(player)
			continue
		if now < player.lock_delay_expires_at_unscaled_time:
			continue
		var locking_piece_id: String = player.current_piece_instance_id
		_piece_lifecycle.lock_current_piece(_runtime_grid_state, player)
		_run_after_lock(player, locking_piece_id, "lock_delay", 0, false)

func handle_input(input: InputEventData) -> int:
	if _runtime_grid_state == null or input == null:
		return 0
	var player := _resolve_player(input.player_id)
	if player == null or player.is_game_over:
		return 0
	if _boss_fx and _boss_fx.should_hypnos_deny():
		return 0
	if _should_deny_input_for_active_effect(input.type):
		return 0
	var invert := _boss_fx.should_invert_horizontal() if _boss_fx else false
	match input.type:
		FallingBlockModels.InputType.MOVE_LEFT:
			if invert:
				input.type = FallingBlockModels.InputType.MOVE_RIGHT
			else:
				input.type = FallingBlockModels.InputType.MOVE_LEFT
		FallingBlockModels.InputType.MOVE_RIGHT:
			if invert:
				input.type = FallingBlockModels.InputType.MOVE_LEFT
			else:
				input.type = FallingBlockModels.InputType.MOVE_RIGHT
	match input.type:
		FallingBlockModels.InputType.MOVE_LEFT:
			if _piece_lifecycle.try_move_piece(_runtime_grid_state, player, Vector2i(-1, 0)):
				if _boss_fx:
					_boss_fx.on_move_input(player)
				if _coop:
					_coop.clamp_piece_to_lane(player)
				_refresh_lock_delay_after_move(player)
				if _gameplay_audio:
					_gameplay_audio.play_move()
		FallingBlockModels.InputType.MOVE_RIGHT:
			if _piece_lifecycle.try_move_piece(_runtime_grid_state, player, Vector2i(1, 0)):
				if _boss_fx:
					_boss_fx.on_move_input(player)
				if _coop:
					_coop.clamp_piece_to_lane(player)
				_refresh_lock_delay_after_move(player)
				if _gameplay_audio:
					_gameplay_audio.play_move()
		FallingBlockModels.InputType.SOFT_DROP:
			if not _piece_lifecycle.try_move_piece(_runtime_grid_state, player, Vector2i(0, -1)):
				if not player.is_on_ground:
					player.is_on_ground = true
					_arm_lock_delay(player)
			else:
				player.piece_session_soft_drop_cells += 1
				player.is_on_ground = false
				_clear_lock_delay(player)
		FallingBlockModels.InputType.HARD_DROP:
			if not _try_accept_hard_drop(player):
				return 0
			return _execute_hard_drop(player)
		FallingBlockModels.InputType.ROTATE_CW:
			if _piece_lifecycle.try_rotate_piece(_runtime_grid_state, player, true):
				_refresh_lock_delay_after_move(player)
				if _gameplay_audio:
					_gameplay_audio.play_rotate()
		FallingBlockModels.InputType.ROTATE_CCW:
			if _piece_lifecycle.try_rotate_piece(_runtime_grid_state, player, false):
				_refresh_lock_delay_after_move(player)
				if _gameplay_audio:
					_gameplay_audio.play_rotate()
		FallingBlockModels.InputType.DISCARD:
			return _handle_discard_input(player)
		FallingBlockModels.InputType.USE_CONSUMABLE:
			return _handle_use_consumable(player)
		FallingBlockModels.InputType.CONSUMABLE_NEXT:
			_cycle_consumable_selection(1)
		FallingBlockModels.InputType.CONSUMABLE_PREVIOUS:
			_cycle_consumable_selection(-1)
		FallingBlockModels.InputType.ABILITY:
			return _handle_use_ability(player)
		FallingBlockModels.InputType.ABILITY_NEXT:
			_cycle_ability_selection(1)
		FallingBlockModels.InputType.ABILITY_PREVIOUS:
			_cycle_ability_selection(-1)
	return 0

func get_grid_state() -> GridState:
	return _runtime_grid_state

func get_players() -> Array:
	return _runtime_players

## True while a boss effect (e.g. Mnemos/Skia blackout) hides the landing ghost.
func is_ghost_suppressed() -> bool:
	return _boss_fx != null and _boss_fx.is_ghost_suppressed()

func _should_deny_input_for_active_effect(input_type: int) -> bool:
	if _is_active_effect("DisableRotation"):
		if input_type == FallingBlockModels.InputType.ROTATE_CW or input_type == FallingBlockModels.InputType.ROTATE_CCW:
			return true
	if _is_active_effect("DisableDiscard") and input_type == FallingBlockModels.InputType.DISCARD:
		return true
	if _is_active_effect("DisableConsumables"):
		match input_type:
			FallingBlockModels.InputType.USE_CONSUMABLE, \
			FallingBlockModels.InputType.CONSUMABLE_NEXT, \
			FallingBlockModels.InputType.CONSUMABLE_PREVIOUS:
				return true
	return false

func _is_active_effect(effect_id: String) -> bool:
	if context == null:
		return false
	var effects := FB.get_fb_node(context, EPHEMERAL_ACTIVE_EFFECTS)
	return effects.is_valid() and effects.get_type() == GnosisValueType.OBJECT and effects.get_node(effect_id).is_valid()

func has_pending_reward_selection() -> bool:
	return _rewards != null and _rewards.has_pending_selection()

func select_reward_slot(index: int) -> void:
	if _rewards:
		_rewards.select_slot(index)

## Sets the active consumable slot (clamped to the owned list). Used by the
## bottom-bar consumables inventory: a click on a non-selected icon selects it.
func select_consumable_slot(index: int) -> void:
	var count := _consumable_list_count()
	if count <= 0:
		return
	FB.set_fb_int(context, EPHEMERAL_SELECTED_CONSUMABLE_SLOT, clampi(index, 0, count - 1))

func get_selected_consumable_slot() -> int:
	var count := _consumable_list_count()
	if count <= 0:
		return 0
	return clampi(FB.read_int(FB.get_fb_node(context, EPHEMERAL_SELECTED_CONSUMABLE_SLOT), 0), 0, count - 1)

## Requests using the currently selected consumable through the normal input
## pipeline, so boss restrictions (DisableConsumables / Hypnos) still apply.
func request_use_selected_consumable() -> void:
	var pid := ""
	if not _runtime_players.is_empty() and _runtime_players[0]:
		pid = _runtime_players[0].player_id
	publish_input_from_adapter(pid, FallingBlockModels.InputType.USE_CONSUMABLE)

## Returns owned ability catalog ids in bag list order.
func get_ability_ids() -> Array:
	return _ability_ids()

## Returns the currently selected ability id, or "" when none.
func get_selected_ability_id() -> String:
	if context == null or context.store == null:
		return ""
	var sel = call_service("Ability", "GetSelectedAbility", context.store.create_object())
	if sel is GnosisNode and sel.is_valid():
		var n: GnosisNode = sel.get_node("abilityId")
		if n.is_valid() and n.get_type() == GnosisValueType.STRING:
			return str(n.value)
	return ""

## Selects an owned ability by catalog id (used by the bottom-bar ability cycler).
func select_ability_id(ability_id: String) -> void:
	if ability_id.is_empty() or context == null or context.store == null:
		return
	var params := context.store.create_object()
	params.set_key("bucketId", "default")
	params.set_key("abilityId", ability_id)
	call_service("Ability", "SetSelectedAbility", params)

## Requests using the currently selected ability through the normal input pipeline.
func request_use_selected_ability() -> void:
	var pid := ""
	if not _runtime_players.is_empty() and _runtime_players[0]:
		pid = _runtime_players[0].player_id
	publish_input_from_adapter(pid, FallingBlockModels.InputType.ABILITY)

func claim_reward_offer(index: int) -> bool:
	if not _rewards:
		return false
	_rewards.select_slot(index)
	var claimed := _rewards.claim_selected_reward()
	if claimed:
		_publish_round_lines_updated(_runtime_players[0] if not _runtime_players.is_empty() else null)
	return claimed

func _execute_hard_drop(player: PlayerState) -> int:
	var cells_moved := 0
	while _piece_lifecycle.try_move_piece(_runtime_grid_state, player, Vector2i(0, -1)):
		cells_moved += 1
	var locking_piece_id := player.current_piece_instance_id
	_piece_lifecycle.lock_current_piece(_runtime_grid_state, player)
	_run_after_lock(player, locking_piece_id, "hard_drop", cells_moved, true)
	return cells_moved

func _run_after_lock(player: PlayerState, locking_piece_id: String, spawn_reason: String, _hard_drop_cells: int, from_hard_drop: bool) -> void:
	# Snapshot the just-placed footprint BEFORE tag sim (slippery gravity etc.) can
	# move it, so the placement flash anchors to the actual landing spot.
	var placement_flash := _capture_placement_flash(locking_piece_id, _hard_drop_cells, from_hard_drop)
	if _boss_fx:
		_boss_fx.apply_xenon_on_locked_piece(locking_piece_id)
	if _tag_sim:
		_tag_sim.on_piece_placed(locking_piece_id)
		_tag_sim.apply_slippery_locked_stack_gravity(_runtime_grid_state)
	if _boon_score:
		var placement_ctx := _build_placement_context(locking_piece_id, from_hard_drop)
		placement_ctx["player_id"] = player.player_id if player else ""
		_boon_score.apply_on_placement(placement_ctx)
	_publish_piece_locked(player, locking_piece_id, from_hard_drop, _hard_drop_cells, placement_flash)
	if from_hard_drop and _gameplay_audio:
		_gameplay_audio.play_hard_drop()

	# Compute clearable rows BEFORE collapsing so tag context stays readable for rules.
	var clearable := _compute_clearable_rows()
	var line_ctx := {}
	var clear_cells: Array = []
	if not clearable.is_empty():
		line_ctx = _build_line_clear_context(clearable)
		_apply_linked_cascade_before_clear(clearable)
		# Snapshot the about-to-clear cells (position + variant) so the renderer can
		# play the legacy white flash; they are gone after the collapse below.
		clear_cells = _capture_line_clear_cells(clearable)

	var cleared := _grid_system.clear_full_rows_and_collapse(_runtime_grid_state, clearable)
	if cleared > 0 and _tag_sim:
		_tag_sim.apply_unstable_after_line_clear(_runtime_grid_state)
	if cleared > 0:
		_emit_line_clear_callout(player, cleared, clear_cells)
		line_ctx["raw_lines"] = cleared
		_on_physical_lines_cleared(player, cleared, line_ctx)

	if _has_top_out():
		if _runtime_run_state:
			_runtime_run_state.is_game_over = true
		player.is_game_over = true
		_publish_game_over(player)
		return
	_publish_spawn_needed(player.player_id, spawn_reason)

func _compute_clearable_rows() -> Array:
	var rows: Array = []
	if _runtime_grid_state == null:
		return rows
	for y in range(_runtime_grid_state.height):
		if _coop and _coop.uses_split_lanes():
			if _coop.is_row_clearable_for_mode(_runtime_grid_state, y):
				rows.append(y)
		elif _grid_system.is_row_clearable(_runtime_grid_state, y):
			rows.append(y)
	return rows

func _emit_line_clear_callout(player: PlayerState, cleared: int, clear_cells: Array = []) -> void:
	if _gameplay_audio:
		_gameplay_audio.play_line_clear(cleared)
	if not context or not context.event_bus or not context.store:
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_RAW_LINES_CLEARED, float(cleared))
	var cells_list := context.store.create_list()
	for cell in clear_cells:
		var cell_node := context.store.create_object()
		cell_node.set_key(FallingBlockEvents.PAYLOAD_CLEAR_CELL_GRID_X, int(cell.get("x", 0)))
		cell_node.set_key(FallingBlockEvents.PAYLOAD_CLEAR_CELL_GRID_Y, int(cell.get("y", 0)))
		cell_node.set_key(FallingBlockEvents.PAYLOAD_CLEAR_CELL_VARIANT_ID, str(cell.get("variant", "")))
		cells_list.add(cell_node)
	payload.set_key(FallingBlockEvents.PAYLOAD_CLEAR_CELLS, cells_list)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_LINE_CLEAR_CALLOUT, payload, false))

## Snapshots every occupied cell in the about-to-clear rows as
## {x, y, variant}. Read before the grid collapses so the variant art is intact.
func _capture_line_clear_cells(rows: Array) -> Array:
	var cells: Array = []
	if _runtime_grid_state == null:
		return cells
	var width := _runtime_grid_state.width
	for y_raw in rows:
		var y := int(y_raw)
		if y < 0 or y >= _runtime_grid_state.height:
			continue
		for x in range(width):
			var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[y * width + x]
			if cell == null or cell.block_id.is_empty():
				continue
			cells.append({"x": x, "y": y, "variant": cell.variant_id})
	return cells

func _publish_piece_locked(player: PlayerState, piece_id: String, from_hard_drop: bool, hard_drop_cells: int, placement_flash: Dictionary = {}) -> void:
	if not context or not context.event_bus or not context.store:
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id if player else "")
	payload.set_key("pieceInstanceId", piece_id)
	payload.set_key("fromHardDrop", from_hard_drop)
	payload.set_key(FallingBlockEvents.PAYLOAD_DROP_DISTANCE, float(hard_drop_cells))
	if not placement_flash.is_empty():
		payload.set_key(FallingBlockEvents.PAYLOAD_CENTER_GRID_X, float(placement_flash.get("center_x", 0.0)))
		payload.set_key(FallingBlockEvents.PAYLOAD_BOTTOM_GRID_Y, int(placement_flash.get("bottom_y", 0)))
		payload.set_key(FallingBlockEvents.PAYLOAD_COLUMN_COUNT, int(placement_flash.get("columns", 1)))
		payload.set_key(FallingBlockEvents.PAYLOAD_DROP_DISTANCE, float(placement_flash.get("drop", float(hard_drop_cells))))
		payload.set_key(FallingBlockEvents.PAYLOAD_VARIANT_ID, str(placement_flash.get("variant", "")))
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_PIECE_LOCKED, payload, false))

## Computes the placement-flash geometry for the just-locked piece: horizontal
## center column, bottom row (landing), occupied column count, drop distance
## (hard-drop cells, or a minimal value for soft locks), and variant. Mirrors the
## Unity RequestBlockPlacementFlash footprint scan.
func _capture_placement_flash(piece_id: String, hard_drop_cells: int, from_hard_drop: bool) -> Dictionary:
	if _runtime_grid_state == null or piece_id.is_empty():
		return {}
	var width := _runtime_grid_state.width
	var min_x := 2147483647
	var max_x := -2147483648
	var min_y := 2147483647
	var columns := {}
	var variant := ""
	for i in range(_runtime_grid_state.cells.size()):
		var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[i]
		if cell == null or cell.piece_instance_id != piece_id or cell.block_id.is_empty():
			continue
		var x := i % width
		var y := i / width
		min_x = mini(min_x, x)
		max_x = maxi(max_x, x)
		min_y = mini(min_y, y)
		columns[x] = true
		if variant.is_empty() and not cell.variant_id.is_empty():
			variant = cell.variant_id
	if columns.is_empty():
		return {}
	var drop := float(maxi(0, hard_drop_cells)) if from_hard_drop else 1.0
	return {
		"center_x": (float(min_x) + float(max_x)) * 0.5,
		"bottom_y": min_y,
		"columns": columns.size(),
		"drop": drop,
		"variant": variant,
	}

# --- Scoring / objective / round progression (ported from PointsScoring + RoundProgress partials) ---

func _cache_variant_score_from_configuration() -> void:
	_variant_base_points.clear()
	_variant_base_multi.clear()
	_variant_points_per_level.clear()
	_variant_multi_per_level.clear()
	if not context:
		return
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return
	var variants := config_root.get_node("variants")
	if not variants.is_valid() or variants.get_type() != GnosisValueType.OBJECT:
		return
	for variant_id in variants.get_keys():
		if String(variant_id).is_empty():
			continue
		var variant := variants.get_node(variant_id)
		if not variant.is_valid() or variant.get_type() != GnosisValueType.OBJECT:
			continue
		var key := String(variant_id).to_lower()
		_variant_base_points[key] = FB.read_int(variant.get_node("basePoints"), DEFAULT_VARIANT_BASE_POINTS)
		_variant_base_multi[key] = FB.read_float(variant.get_node("baseMulti"), DEFAULT_VARIANT_BASE_MULTI)
		_variant_points_per_level[key] = FB.read_int(variant.get_node("pointsPerLevel"), 0)
		_variant_multi_per_level[key] = FB.read_float(variant.get_node("multiPerLevel"), 0)
		var tags_list: Array = []
		var tags_node := variant.get_node("tags")
		if tags_node.is_valid() and tags_node.get_type() == GnosisValueType.LIST:
			for ti in range(tags_node.get_count()):
				var tnode := tags_node.get_node(ti)
				if tnode.is_valid() and tnode.get_type() == GnosisValueType.STRING:
					tags_list.append(str(tnode.value))
		_variant_tags[key] = tags_list

func _resolve_variant_level(key: String) -> int:
	if not context:
		return 1
	var levels := FB.get_fb_node(context, EPHEMERAL_VARIANT_LEVELS)
	if levels.is_valid() and levels.get_type() == GnosisValueType.OBJECT:
		var node := levels.get_node(key)
		if node.is_valid():
			return maxi(1, FB.read_int(node, 1))
	return 1

func _get_variant_base_points(variant_id: String) -> int:
	if variant_id.strip_edges().is_empty():
		return DEFAULT_VARIANT_BASE_POINTS
	var key := variant_id.strip_edges().to_lower()
	var base_points: int = _variant_base_points.get(key, DEFAULT_VARIANT_BASE_POINTS)
	var level_offset := maxi(0, _resolve_variant_level(key) - 1)
	var per_level: int = _variant_points_per_level.get(key, 0)
	return base_points + per_level * level_offset

func _get_variant_base_multi(variant_id: String) -> float:
	if variant_id.strip_edges().is_empty():
		return DEFAULT_VARIANT_BASE_MULTI
	var key := variant_id.strip_edges().to_lower()
	var base_multi: float = _variant_base_multi.get(key, DEFAULT_VARIANT_BASE_MULTI)
	var level_offset := maxi(0, _resolve_variant_level(key) - 1)
	var per_level: float = _variant_multi_per_level.get(key, 0.0)
	return base_multi + per_level * level_offset

## Returns [points: GnosisScalableValue, multi: GnosisScalableValue] for cells of one piece.
func _sum_score_for_piece(piece_instance_id: String) -> Array:
	var points := GnosisScalableValue.zero()
	var multi := GnosisScalableValue.zero()
	if _runtime_grid_state == null or piece_instance_id.is_empty():
		return [points, multi]
	for cell in _runtime_grid_state.cells:
		if cell == null or cell.block_id.is_empty():
			continue
		if cell.piece_instance_id != piece_instance_id:
			continue
		points = points.add(GnosisScalableValue.from_int(_get_variant_base_points(cell.variant_id)))
		multi = multi.add(GnosisScalableValue.from_float(_get_variant_base_multi(cell.variant_id)))
	return [points, multi]

## Returns [points, multi] summed over all occupied cells in the given rows.
func _sum_score_in_rows(rows: Array) -> Array:
	var points := GnosisScalableValue.zero()
	var multi := GnosisScalableValue.zero()
	if _runtime_grid_state == null or rows.is_empty():
		return [points, multi]
	var width := _runtime_grid_state.width
	for y in rows:
		if y < 0 or y >= _runtime_grid_state.height:
			continue
		var row_start := int(y) * width
		for x in range(width):
			var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[row_start + x]
			if cell == null or cell.block_id.is_empty():
				continue
			points = points.add(GnosisScalableValue.from_int(_get_variant_base_points(cell.variant_id)))
			multi = multi.add(GnosisScalableValue.from_float(_get_variant_base_multi(cell.variant_id)))
	return [points, multi]

## Variant tags configured for a variant id (e.g. ["neutral","soft","color_red"]).
func _get_variant_tags(variant_id: String) -> Array:
	if variant_id.strip_edges().is_empty():
		return []
	return _variant_tags.get(variant_id.strip_edges().to_lower(), [])

## Builds the on_line_clear boon-score context from cleared rows (pre-collapse).
func _build_line_clear_context(rows: Array) -> Dictionary:
	var tags := {}
	var variants := {}
	var block_count := 0
	if _runtime_grid_state == null:
		return {"tags": tags, "cleared_block_count": 0, "distinct_variant_count": 0, "rgb_only": false, "cleared_line_max_grid_y": -1}
	var width := _runtime_grid_state.width
	var max_grid_y := -1
	for y in rows:
		if y < 0 or y >= _runtime_grid_state.height:
			continue
		max_grid_y = maxi(max_grid_y, int(y))
		var row_start := int(y) * width
		for x in range(width):
			var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[row_start + x]
			if cell == null or cell.block_id.is_empty():
				continue
			block_count += 1
			var vid := cell.variant_id.strip_edges().to_lower()
			if not vid.is_empty():
				variants[vid] = true
			for tag in _get_variant_tags(vid):
				tags[tag] = int(tags.get(tag, 0)) + 1
	var rgb_only: bool = tags.has("color_red") and tags.has("color_green") and tags.has("color_blue")
	return {
		"tags": tags,
		"cleared_block_count": block_count,
		"distinct_variant_count": variants.size(),
		"rgb_only": rgb_only,
		"cleared_line_max_grid_y": max_grid_y,
	}

## Builds the on_placement boon-score context from the locked piece's cells.
func _build_placement_context(piece_instance_id: String, from_hard_drop: bool) -> Dictionary:
	var tags := {}
	var block_count := 0
	var ultravibe_id := ""
	var variant_id := ""
	if _runtime_grid_state != null and not piece_instance_id.is_empty():
		for cell: FallingBlockModels.CellState in _runtime_grid_state.cells:
			if cell == null or cell.block_id.is_empty():
				continue
			if cell.piece_instance_id != piece_instance_id:
				continue
			block_count += 1
			if ultravibe_id.is_empty():
				ultravibe_id = cell.ultravibe_id
			if variant_id.is_empty():
				variant_id = cell.variant_id
			var vid := cell.variant_id.strip_edges().to_lower()
			for tag in _get_variant_tags(vid):
				tags[tag] = int(tags.get(tag, 0)) + 1
	return {
		"block_count": block_count,
		"hard_drop": from_hard_drop,
		"ultravibe_id": ultravibe_id,
		"variant_id": variant_id,
		"tags": tags,
	}

func _accrue_pending_score_from_locked_piece(piece_instance_id: String) -> void:
	var delta := _sum_score_for_piece(piece_instance_id)
	_add_to_pending_score(delta[0] as GnosisScalableValue, delta[1] as GnosisScalableValue)

func _add_to_pending_score(points: GnosisScalableValue, multi: GnosisScalableValue) -> void:
	var one := GnosisScalableValue.from_int(1)
	if not points.is_zero():
		var pending := FB.get_fb_scalable(context, "pendingPoints").add(points)
		if pending.compare_to(one) < 0:
			pending = one
		FB.set_fb_scalable(context, "pendingPoints", pending)
	if not multi.is_zero():
		var pending_multi := FB.get_fb_scalable(context, "pendingMulti").add(multi)
		if pending_multi.compare_to(one) < 0:
			pending_multi = one
		FB.set_fb_scalable(context, "pendingMulti", pending_multi)

func _clear_pending_score() -> void:
	FB.set_fb_scalable(context, "pendingPoints", GnosisScalableValue.zero())
	FB.set_fb_scalable(context, "pendingMulti", GnosisScalableValue.zero())

## points x max(1, multi)
func _final_score(points: GnosisScalableValue, multi: GnosisScalableValue) -> GnosisScalableValue:
	if points.compare_to(GnosisScalableValue.zero()) <= 0:
		return GnosisScalableValue.zero()
	var one := GnosisScalableValue.from_int(1)
	var effective_multi := one if multi.compare_to(one) < 0 else multi
	return points.mul(effective_multi)

func _on_physical_lines_cleared(player: PlayerState, raw_lines: int, line_ctx: Dictionary = {}) -> void:
	if raw_lines <= 0:
		return
	if _boss_fx and player:
		_boss_fx.after_physical_line_cleared(player.player_id, raw_lines)
	# Record cumulative lines cleared (drives run scaling ramps) and apply interval steps.
	_increment_lines_cleared_statistic(raw_lines)
	_try_apply_run_scaling_from_lines_cleared()
	var line_score := FallingBlockLineScoring.score_as_scalable(raw_lines)
	if _boon_score:
		var adjusted := _boon_score.apply_on_line_clear(line_score, GnosisScalableValue.zero(), line_ctx)
		if adjusted.size() > 0 and adjusted[0] is GnosisScalableValue:
			line_score = adjusted[0]
	_publish_objective_resolved(player, raw_lines, line_score)
	_apply_round_progress_after_line_clear(player, raw_lines, line_score)

func _resolve_objective_delta_from_line_clear(player: PlayerState, raw_lines: int, points: GnosisScalableValue, multi: GnosisScalableValue) -> GnosisScalableValue:
	var baseline_final := _final_score(points, multi)
	if not context or not context.event_bus or not context.store:
		return baseline_final
	# Publish the interceptable REQUEST so future boon rules can adjust points/multi/delta.
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_RAW_LINES_CLEARED, float(raw_lines))
	_write_scalable_to_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_POINTS, points)
	_write_scalable_to_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_MULTI, multi)
	_write_scalable_to_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_DELTA, baseline_final)
	var result := context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.REQUEST_OBJECTIVE_CONTRIBUTION_FROM_LINE_CLEAR, payload, false))
	var final_data := payload
	if result and result.final_event and result.final_event.data:
		final_data = result.final_event.data
	return _resolve_final_score_from_payload(final_data, points, multi, baseline_final)

func _resolve_final_score_from_payload(payload: GnosisNode, baseline_points: GnosisScalableValue, baseline_multi: GnosisScalableValue, baseline_final: GnosisScalableValue) -> GnosisScalableValue:
	var points := _read_scalable_from_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_POINTS, baseline_points)
	var multi := _read_scalable_from_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_MULTI, baseline_multi)
	var delta_field := _read_scalable_from_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_DELTA, baseline_final)
	var touched := not points.is_equal(baseline_points) or not multi.is_equal(baseline_multi)
	var resolved := _final_score(points, multi) if touched else delta_field
	var zero := GnosisScalableValue.zero()
	if baseline_final.compare_to(zero) > 0 and resolved.compare_to(baseline_final) < 0:
		resolved = baseline_final
	return zero if resolved.compare_to(zero) <= 0 else resolved

func _apply_round_progress_after_line_clear(player: PlayerState, raw_lines: int, line_score: GnosisScalableValue) -> void:
	if line_score.compare_to(GnosisScalableValue.zero()) > 0:
		_apply_run_total_score_delta(line_score)
	var current := FB.get_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, 0) + maxi(0, raw_lines)
	FB.set_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, current)
	var round_number := maxi(1, FB.get_fb_int(context, EPHEMERAL_CURRENT_ROUND, 1))
	_apply_round_progress_loop(player, round_number, current)
	_publish_round_lines_updated(player)

## Legacy invocation hook: treats delta as additional lines toward the current round.
func _apply_round_progress_after_objective_delta(player: PlayerState, objective_delta: GnosisScalableValue) -> void:
	var lines := maxi(0, objective_delta.to_int())
	_apply_round_progress_after_line_clear(player, lines, GnosisScalableValue.zero())

func _apply_round_progress_loop(player: PlayerState, round_number: int, current: int) -> void:
	var rounds_completed := 0
	if _rewards:
		_rewards.reset_burst()
	while true:
		var needed := FB.get_fb_int(
			context,
			EPHEMERAL_ROUND_LINES_NEEDED,
			FallingBlockRoundLines.BASE_LINES_PER_ROUND
		)
		if needed <= 0:
			break
		if current < needed:
			break
		var completed_needed := needed
		current = 0
		FB.set_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, 0)
		var completed_round := round_number
		FB.set_fb_int(context, EPHEMERAL_ROUNDS_FINISHED, FB.get_fb_int(context, EPHEMERAL_ROUNDS_FINISHED, 0) + 1)
		if _rewards:
			if rounds_completed == 0:
				_rewards.grant_on_round_advance(true)
			else:
				_rewards.grant_on_round_advance(false)
		rounds_completed += 1
		round_number += 1
		FB.set_fb_int(context, EPHEMERAL_CURRENT_ROUND, round_number)
		FB.set_fb_int(
			context,
			EPHEMERAL_ROUND_LINES_NEEDED,
			completed_needed + FallingBlockRoundLines.LINES_PER_ROUND_INCREMENT
		)
		_publish_round_advanced(player, round_number, completed_round, completed_needed)
		if rounds_completed >= MAX_ROUNDS_ADVANCED_PER_SCORE_BURST:
			break
	if rounds_completed > 0:
		_reset_current_discards_to_base()
		if _gameplay_audio:
			_gameplay_audio.play_level_finished()
		if _rewards and FallingBlockGameFlags.is_include_rewards(context):
			_rewards.refresh_offers()

func _apply_run_total_score_delta(objective_delta: GnosisScalableValue) -> void:
	var total := FB.get_fb_scalable(context, EPHEMERAL_RUN_TOTAL_SCORE).add(objective_delta)
	FB.set_fb_scalable(context, EPHEMERAL_RUN_TOTAL_SCORE, total)

func _reset_round_progress_for_new_run() -> void:
	if not context:
		return
	if _gameplay_audio:
		_gameplay_audio.reset_streaks()
	FB.set_fb_scalable(context, EPHEMERAL_RUN_TOTAL_SCORE, GnosisScalableValue.zero())
	FB.set_fb_int(context, EPHEMERAL_CURRENT_ROUND, 1)
	FB.set_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, 0)
	FB.set_fb_int(context, EPHEMERAL_ROUND_LINES_NEEDED, FallingBlockRoundLines.BASE_LINES_PER_ROUND)
	FB.set_fb_int(context, EPHEMERAL_ROUNDS_FINISHED, 0)
	_publish_round_lines_updated(null)

func _publish_objective_resolved(player: PlayerState, raw_lines: int, objective_delta: GnosisScalableValue) -> void:
	if not context or not context.event_bus or not context.store:
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_RAW_LINES_CLEARED, float(raw_lines))
	_write_scalable_to_payload(payload, FallingBlockEvents.PAYLOAD_OBJECTIVE_DELTA, objective_delta)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_OBJECTIVE_FROM_LINE_CLEAR_RESOLVED, payload, false))

func _publish_round_advanced(player: PlayerState, new_round: int, completed_round: int, completed_lines_needed: int) -> void:
	if not context or not context.event_bus or not context.store:
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id if player else "")
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_NUMBER, new_round)
	payload.set_key(FallingBlockEvents.PAYLOAD_COMPLETED_ROUND, completed_round)
	payload.set_key(FallingBlockEvents.PAYLOAD_COMPLETED_ROUND_LINES_NEEDED, completed_lines_needed)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_ROUND_ADVANCED, payload, false))
	if _boon_score:
		_boon_score.apply_on_round_advanced({
			"player_id": player.player_id if player else "",
			"round_number": new_round,
			"completed_round": completed_round,
			"completed_lines_needed": completed_lines_needed,
		})

func _publish_round_lines_updated(player: PlayerState) -> void:
	if not context or not context.event_bus or not context.store:
		return
	var current := FB.get_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, 0)
	var needed := FB.get_fb_int(context, EPHEMERAL_ROUND_LINES_NEEDED, FallingBlockRoundLines.BASE_LINES_PER_ROUND)
	var round_number := FB.get_fb_int(context, EPHEMERAL_CURRENT_ROUND, 1)
	var payload := context.store.create_object()
	if player:
		payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_LINES_CURRENT, current)
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_LINES_NEEDED, needed)
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_NUMBER, round_number)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_ROUND_LINES_UPDATED, payload, false))

func _publish_game_over(player: PlayerState) -> void:
	if not context or not context.event_bus or not context.store:
		return
	_reset_theme_to_default_for_run_boundary()
	if _gameplay_audio:
		_gameplay_audio.play_game_over()
	var payload := _build_run_summary(player)
	FB.set_fb_node(context, EPHEMERAL_LAST_GAME_OVER_SUMMARY, payload)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_GAME_OVER, payload, false))

func _reset_theme_to_default_for_run_boundary() -> void:
	if context == null or context.store == null:
		return
	var args := context.store.create_object()
	args.set_key("themeId", GnosisThemeService.DEFAULT_THEME_ID)
	call_service("Theme", "SetCurrentTheme", args)

func _build_run_summary(player: PlayerState) -> GnosisNode:
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id if player else "")
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_NUMBER, FB.get_fb_int(context, EPHEMERAL_CURRENT_ROUND, 1))
	payload.set_key("roundsFinished", FB.get_fb_int(context, EPHEMERAL_ROUNDS_FINISHED, 0))
	payload.set_key(FallingBlockEvents.PAYLOAD_ELAPSED_SEC, read_run_elapsed_whole_seconds())
	_write_scalable_to_payload(payload, "runTotalScore", FB.get_fb_scalable(context, EPHEMERAL_RUN_TOTAL_SCORE))
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_LINES_CURRENT, FB.get_fb_int(context, EPHEMERAL_ROUND_LINES_CURRENT, 0))
	payload.set_key(FallingBlockEvents.PAYLOAD_ROUND_LINES_NEEDED, FB.get_fb_int(context, EPHEMERAL_ROUND_LINES_NEEDED, FallingBlockRoundLines.BASE_LINES_PER_ROUND))
	payload.set_key("linesClearedTotal", _read_lines_cleared_total())
	# Extra HUD-parity stats so the game-over summary can mirror the topbar/sidebar.
	payload.set_key("currentDiscards", int(round(FB.get_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, 0.0))))
	payload.set_key("fallSpeedDisplay", read_fall_speed_hud_display())
	payload.set_key("negativeChanceDisplay", read_negative_chance_hud_display())
	payload.set_key("deckSize", _read_deck_size())
	return payload

## Current deck size for the run summary: prefers the live deckEntries list,
## falling back to the cached deckLength leaf.
func _read_deck_size() -> int:
	var entries := FB.get_fb_node(context, "deckEntries")
	if entries.is_valid() and entries.get_type() == GnosisValueType.LIST:
		return entries.get_count()
	return maxi(0, FB.get_fb_int(context, "deckLength", 0))

func _write_scalable_to_payload(payload: GnosisNode, key: String, value: GnosisScalableValue) -> void:
	var node := context.store.create_object()
	node.set_key("coefficient", value.coefficient)
	node.set_key("suffixIndex", value.suffix_index)
	node.set_key("formatted", value.to_formatted_string())
	payload.set_key(key, node)

func _read_scalable_from_payload(payload: GnosisNode, key: String, default_value: GnosisScalableValue) -> GnosisScalableValue:
	if not payload.is_valid():
		return default_value
	var node := payload.get_node(key)
	if not node.is_valid():
		return default_value
	if node.get_type() == GnosisValueType.OBJECT:
		return FB.read_scalable(node)
	if node.get_type() == GnosisValueType.INT or node.get_type() == GnosisValueType.LONG or node.get_type() == GnosisValueType.FLOAT:
		return GnosisScalableValue.from_float(float(node.value))
	return default_value

func _spawn_piece_for_player(player: PlayerState, ultravibe_id: String = "", variant_id: String = "blue") -> void:
	if player == null or _runtime_grid_state == null:
		return
	if ultravibe_id.is_empty():
		ultravibe_id = _ultravibe_registry.get_random_shape_id(_rng)
	if _boss_fx:
		variant_id = _boss_fx.mutate_spawn(variant_id)
	var poly_info := _ultravibe_registry.get_shape(ultravibe_id)
	if poly_info == null:
		return
	var spawn_origin := _resolve_spawn_origin_for_player(player, poly_info)
	var piece_instance_id := "piece_%d" % (_piece_instance_counter + 1)
	var ok := _piece_lifecycle.try_spawn_piece(
		_runtime_grid_state,
		player,
		poly_info,
		variant_id,
		_resolve_variant_tags(variant_id),
		spawn_origin,
		piece_instance_id,
		func(): return _new_block_id()
	)
	if not ok:
		if _runtime_run_state:
			_runtime_run_state.is_game_over = true
		player.is_game_over = true
		_publish_game_over(player)
		return
	_piece_instance_counter += 1
	_apply_spawn_guards(player)
	if _boss_fx:
		_boss_fx.on_piece_spawned(player)
	if _coop:
		_coop.clamp_piece_to_lane(player)

func _resolve_variant_tags(variant_id: String) -> Array[String]:
	var tags: Array[String] = []
	if not context or variant_id.is_empty():
		return tags
	var config_root := get_node("configuration", true)
	var variant := config_root.get_node("variants").get_node(variant_id.to_lower())
	if not variant.is_valid() or variant.get_type() != GnosisValueType.OBJECT:
		return tags
	var tags_node := variant.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return tags
	for i in range(tags_node.get_count()):
		var item := tags_node.get_node(i)
		if item.is_valid() and item.get_type() == GnosisValueType.STRING:
			var t := str(item.value).strip_edges().to_lower()
			if not t.is_empty():
				tags.append(t)
	return tags

func _resolve_variant_color_tags(variant_id: String) -> Array[String]:
	return _resolve_variant_tags(variant_id)

func _resolve_spawn_origin_for_player(player: PlayerState, poly_info: FallingBlockModels.UltravibeInfo) -> Vector2i:
	if player == null or _runtime_grid_state == null or poly_info == null:
		return Vector2i.ZERO
	var player_count := _coop.get_player_count() if _coop else 1
	var occupied_check := func(origin: Vector2i, offsets: Array) -> bool:
		for offset in offsets:
			var x := origin.x + int(offset.x)
			var y := origin.y + int(offset.y)
			if _grid_system.is_cell_occupied_by_locked_block(_runtime_grid_state, x, y):
				return true
		return false
	return SpawnResolver.resolve_highest_spawn_origin(
		_runtime_grid_state,
		player.player_id,
		player_count,
		poly_info.block_offsets,
		_grid_system,
		occupied_check
	)

func _resolve_spawn_origin(poly_info: FallingBlockModels.UltravibeInfo) -> Vector2i:
	var max_y := 0
	for offset in poly_info.block_offsets:
		max_y = maxi(max_y, offset.y)
	var origin_y := _runtime_grid_state.height - 1 - max_y
	var center_x := _runtime_grid_state.width / 2
	return Vector2i(center_x, origin_y)

func _new_block_id() -> String:
	return "%d" % (_rng.randi())

func _apply_spawn_guards(player: PlayerState) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	player.piece_spawned_at_unscaled_time = now
	player.piece_spawn_grace_ticks_remaining = PIECE_SPAWN_LOCK_GRACE_TICKS
	player.piece_spawn_grace_last_decrement_frame = -1
	player.hard_drop_allowed_after_unscaled_time = now + MIN_SECONDS_AFTER_SPAWN_BEFORE_HARD_DROP
	player.lock_delay_allowed_after_unscaled_time = now + MIN_SECONDS_AFTER_SPAWN_BEFORE_LOCK_DELAY
	player.is_on_ground = false
	_clear_lock_delay(player)

func _has_top_out() -> bool:
	var top_out_start_y := maxi(0, _runtime_grid_state.height - _runtime_grid_state.hidden_rows)
	for y in range(top_out_start_y, _runtime_grid_state.height):
		for x in range(_runtime_grid_state.width):
			var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[y * _runtime_grid_state.width + x]
			if cell != null and cell.is_locked and not cell.block_id.is_empty():
				return true
	return false

# --- Fall speed / gravity curve (ported from FallSpeed partial + GravityCurve) ---

func _get_gravity_tick_interval_seconds() -> float:
	if not context or not context.store:
		return FallingBlockGravityCurve.guideline_seconds_per_cell(1)
	return _read_gravity_seconds_per_cell()

func _reset_fall_speed_for_new_run() -> void:
	if not context:
		return
	FB.set_fb_int(context, EPHEMERAL_GRAVITY_LEVEL_OFFSET, 0)
	var difficulty := _read_fall_speed_difficulty_id()
	var lines_per_interval := maxi(1, FB.get_fb_int(context, EPHEMERAL_RUN_SCALING_LINES_PER_INTERVAL, FallingBlockGravityCurve.DEFAULT_LINES_PER_LEVEL))
	var starting := FallingBlockGravityCurve.resolve_starting_seconds_per_cell(difficulty, lines_per_interval)
	FB.set_fb_float(context, EPHEMERAL_GRAVITY_SECONDS_PER_CELL_STARTING, starting)
	FB.set_fb_float(context, EPHEMERAL_GRAVITY_SECONDS_PER_CELL, starting)
	_refresh_gravity_from_run_state()

func _reset_run_scaling_for_new_run() -> void:
	if not context:
		return
	FB.set_fb_int(context, EPHEMERAL_RUN_SCALING_LAST_LINE_INTERVAL_INDEX, 0)
	FB.set_fb_int(context, EPHEMERAL_NEGATIVE_SCALING_LAST_LINE_INTERVAL_INDEX, 0)

func _try_apply_run_scaling_from_lines_cleared() -> void:
	if not context or not context.store:
		return
	var total_lines := maxi(0, _read_lines_cleared_total())
	var applied := false

	var speed_lines_per_interval := maxi(1, FB.get_fb_int(context, EPHEMERAL_RUN_SCALING_LINES_PER_INTERVAL, 10))
	var paced_climb_stacks := _get_run_upgrade_stack_count(PACED_CLIMB_UPGRADE_ID)
	if paced_climb_stacks > 0:
		speed_lines_per_interval += paced_climb_stacks * PACED_CLIMB_LINES_PER_INTERVAL_BONUS_PER_STACK
	var speed_current_interval_index := total_lines / speed_lines_per_interval
	var speed_last_interval_index := FB.get_fb_int(context, EPHEMERAL_RUN_SCALING_LAST_LINE_INTERVAL_INDEX, 0)
	if speed_current_interval_index > speed_last_interval_index:
		FB.set_fb_int(context, EPHEMERAL_RUN_SCALING_LAST_LINE_INTERVAL_INDEX, speed_current_interval_index)
		_refresh_gravity_from_run_state()
		applied = true

	var negative_lines_per_interval := maxi(1, FB.get_fb_int(context, EPHEMERAL_NEGATIVE_SCALING_LINES_PER_INTERVAL, 10))
	var dark_pressure_stacks := _get_run_upgrade_stack_count(DARK_PRESSURE_VALVE_UPGRADE_ID)
	if dark_pressure_stacks > 0:
		negative_lines_per_interval += dark_pressure_stacks * DARK_PRESSURE_VALVE_LINES_PER_INTERVAL_BONUS_PER_STACK
	var negative_current_interval_index := total_lines / negative_lines_per_interval
	var negative_last_interval_index := FB.get_fb_int(context, EPHEMERAL_NEGATIVE_SCALING_LAST_LINE_INTERVAL_INDEX, 0)
	if negative_current_interval_index > negative_last_interval_index:
		var negative_intervals_to_apply := negative_current_interval_index - negative_last_interval_index
		FB.set_fb_int(context, EPHEMERAL_NEGATIVE_SCALING_LAST_LINE_INTERVAL_INDEX, negative_current_interval_index)
		var negative_delta_per_interval := FB.get_fb_int(context, EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_INCREMENT, 0)
		if negative_delta_per_interval != 0:
			var params := context.store.create_object()
			params.set_key("delta", negative_delta_per_interval * negative_intervals_to_apply)
			var result = call_service("Deck", "ChangeNegativeUltravibeChance", params)
			if result and result.is_ok:
				applied = true

	if applied and context.engine:
		context.engine.commit("fallingBlock")

func _get_run_upgrade_stack_count(upgrade_id: String) -> int:
	if not FallingBlockGameFlags.is_include_upgrades(context):
		return 0
	if upgrade_id.strip_edges().is_empty() or not context or not context.state:
		return 0
	var ephemeral := context.state.root.get_node("Ephemeral")
	if not ephemeral.is_valid() or ephemeral.get_type() != GnosisValueType.OBJECT:
		return 0
	var bag := ephemeral.get_at_path("upgrades.run")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return 0
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST or list.get_count() == 0:
		return 0
	var target := upgrade_id.strip_edges().to_lower()
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var id := FB.read_string(entry.get_node("id"), "")
		if id.is_empty():
			id = FB.read_string(entry.get_node("upgradeId"), "")
		if id.is_empty():
			id = FB.read_string(entry.get_node("itemId"), "")
		if id.strip_edges().to_lower() != target:
			continue
		return maxi(0, FB.read_int(entry.get_node("currentCount"), 1))
	return 0

func _refresh_gravity_from_run_state() -> void:
	if not context:
		return
	var difficulty := _read_fall_speed_difficulty_id()
	if FallingBlockGameFlags.is_max_speed_only(context):
		var max_speed := FallingBlockGravityCurve.fastest_seconds_per_cell_for_difficulty(difficulty)
		FB.set_fb_float(context, EPHEMERAL_GRAVITY_SECONDS_PER_CELL, max_speed)
		return
	var lines_per_interval := maxi(1, FB.get_fb_int(context, EPHEMERAL_RUN_SCALING_LINES_PER_INTERVAL, FallingBlockGravityCurve.DEFAULT_LINES_PER_LEVEL))
	var total_lines := _read_lines_cleared_total()
	var level_offset := FB.get_fb_int(context, EPHEMERAL_GRAVITY_LEVEL_OFFSET, 0)
	var seconds := FallingBlockGravityCurve.resolve_seconds_per_cell(difficulty, total_lines, level_offset, lines_per_interval)
	FB.set_fb_float(context, EPHEMERAL_GRAVITY_SECONDS_PER_CELL, seconds)

func _read_gravity_seconds_per_cell() -> float:
	var current := FB.get_fb_float(context, EPHEMERAL_GRAVITY_SECONDS_PER_CELL, -1.0)
	if current > 0.0:
		return maxf(MIN_GRAVITY_SECONDS_PER_CELL, current)
	var difficulty := _read_fall_speed_difficulty_id()
	var lines_per_interval := maxi(1, FB.get_fb_int(context, EPHEMERAL_RUN_SCALING_LINES_PER_INTERVAL, FallingBlockGravityCurve.DEFAULT_LINES_PER_LEVEL))
	return FallingBlockGravityCurve.resolve_starting_seconds_per_cell(difficulty, lines_per_interval)

func _read_fall_speed_difficulty_id() -> String:
	var node := FB.get_fb_node(context, EPHEMERAL_FALL_SPEED_DIFFICULTY)
	var difficulty := ""
	if node.is_valid() and node.get_type() == GnosisValueType.STRING:
		difficulty = str(node.value)
	if difficulty.strip_edges().is_empty():
		return FallingBlockGravityCurve.DIFFICULTY_DEFAULT
	return difficulty.strip_edges().to_lower()

func _increment_lines_cleared_statistic(raw_lines: int) -> void:
	_increment_stat(STAT_LINES_CLEARED_TOTAL, float(raw_lines))

func _increment_stat(key: String, delta: float) -> void:
	if not context or not context.store or delta == 0.0:
		return
	var params := context.store.create_object()
	params.set_key("persistent", false)
	params.set_key("key", key)
	params.set_key("delta", delta)
	call_service("Statistic", "IncrementCounter", params)

func _read_lines_cleared_total() -> int:
	if not context or not context.state:
		return 0
	var ephemeral := context.state.root.get_node("Ephemeral")
	if not ephemeral.is_valid() or ephemeral.get_type() != GnosisValueType.OBJECT:
		return 0
	var node := ephemeral.get_at_path("statistics." + STAT_LINES_CLEARED_TOTAL)
	if node.is_valid() and node.value != null:
		var t := node.get_type()
		if t == GnosisValueType.INT or t == GnosisValueType.LONG:
			return int(node.value)
		if t == GnosisValueType.FLOAT:
			return int(round(node.value))
	return 0

# --- Discards (ported from Discard partial) ---

func _read_discard_bounds() -> Array:
	var min_d := FB.get_fb_float(context, EPHEMERAL_MIN_DISCARDS, 0.0)
	var max_d := FB.get_fb_float(context, EPHEMERAL_MAX_DISCARDS, 0.0)
	if max_d < min_d:
		var tmp := max_d
		max_d = min_d
		min_d = tmp
	return [min_d, max_d]

func _handle_discard_input(player: PlayerState) -> int:
	if not FallingBlockGameFlags.is_include_discards(context):
		return 0
	if player.current_piece_instance_id.is_empty():
		return 0
	var bounds := _read_discard_bounds()
	var min_d: float = bounds[0]
	var max_d: float = bounds[1]
	var current := clampf(FB.get_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, max_d), min_d, max_d)
	var infinite := FallingBlockGameFlags.is_infinite_discards(context)
	if not infinite and current <= min_d + DISCARD_EPSILON:
		return 0
	_piece_lifecycle.clear_active_piece(_runtime_grid_state, player)
	if not infinite:
		current = clampf(current - 1.0, min_d, max_d)
		FB.set_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, current)
		_increment_stat(STAT_TOTAL_DISCARDS_USED, 1.0)
	_publish_spawn_needed(player.player_id, "discard")
	if _gameplay_audio:
		_gameplay_audio.play_discard()
	# Minimal harnesses have no deck service to answer the spawn request.
	if player.current_piece_instance_id.is_empty():
		_spawn_piece_for_player(player)
	_publish_round_lines_updated(player)
	return 1

func _add_discards(amount: float) -> void:
	if amount <= 0.0 or not context:
		return
	var bounds := _read_discard_bounds()
	var min_d: float = bounds[0]
	var max_d: float = bounds[1]
	var current := clampf(FB.get_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, max_d), min_d, max_d)
	var next := clampf(current + amount, min_d, max_d)
	if next != current:
		FB.set_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, next)
		_increment_stat(STAT_TOTAL_DISCARDS_ADDED, next - current)
		_play_animation_feedback("discardsAdded")

func _play_animation_feedback(feedback_id: String) -> void:
	if not context or not context.store or feedback_id.is_empty():
		return
	var payload := context.store.create_object()
	payload.set_key("id", feedback_id)
	call_service("Animation", "PlayFeedback", payload)

func _reset_current_discards_to_base() -> void:
	if not context:
		return
	var persist := FB.read_bool(FB.get_fb_node(context, EPHEMERAL_PERSIST_DISCARDS), false)
	if persist:
		return
	var bounds := _read_discard_bounds()
	var min_d: float = bounds[0]
	var max_d: float = bounds[1]
	var base_val := clampf(FB.get_fb_float(context, EPHEMERAL_BASE_DISCARDS, max_d), min_d, max_d)
	FB.set_fb_float(context, EPHEMERAL_CURRENT_DISCARDS, base_val)

# --- Consumables / abilities use (ported from input wiring) ---

func _read_inventory_selected_id(root_key: String, selected_index: int) -> String:
	var ep := context.state.root.get_node("Ephemeral")
	if not ep.is_valid() or ep.get_type() != GnosisValueType.OBJECT:
		return ""
	var buckets := ep.get_node(root_key)
	if not buckets.is_valid() or buckets.get_type() != GnosisValueType.OBJECT:
		return ""
	var bag := buckets.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return ""
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST or list.get_count() == 0:
		return ""
	var idx := clampi(selected_index, 0, list.get_count() - 1)
	var entry := list.get_node(idx)
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return ""
	var id_node := entry.get_node("id")
	if id_node.is_valid() and id_node.get_type() == GnosisValueType.STRING:
		return str(id_node.value)
	return ""

func _consumable_list_count() -> int:
	var ep := context.state.root.get_node("Ephemeral")
	if not ep.is_valid():
		return 0
	var buckets := ep.get_node("consumables")
	if not buckets.is_valid() or buckets.get_type() != GnosisValueType.OBJECT:
		return 0
	var bag := buckets.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return 0
	var list := bag.get_node("list")
	if list.is_valid() and list.get_type() == GnosisValueType.LIST:
		return list.get_count()
	return 0

func _handle_use_consumable(player: PlayerState) -> int:
	if not FallingBlockGameFlags.is_include_consumables(context):
		return 0
	var selected_index := FB.read_int(FB.get_fb_node(context, EPHEMERAL_SELECTED_CONSUMABLE_SLOT), 0)
	var consumable_id := _read_inventory_selected_id("consumables", selected_index)
	if consumable_id.is_empty():
		return 0
	var params := context.store.create_object()
	params.set_key("consumableId", consumable_id)
	params.set_key("bucketId", "default")
	params.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	var res = call_service("Consumable", "ConsumeConsumable", params)
	if res == null:
		return 0
	if _boon_score:
		_boon_score.apply_on_consumable_use()
	_publish_round_lines_updated(player)
	return 1

func _cycle_consumable_selection(direction: int) -> void:
	var count := _consumable_list_count()
	if count <= 0:
		return
	var current := FB.read_int(FB.get_fb_node(context, EPHEMERAL_SELECTED_CONSUMABLE_SLOT), 0)
	var next := ((current + direction) % count + count) % count
	FB.set_fb_int(context, EPHEMERAL_SELECTED_CONSUMABLE_SLOT, next)

func _handle_use_ability(player: PlayerState) -> int:
	if not FallingBlockGameFlags.is_include_abilities(context):
		return 0
	# Shared cooldown: deny while any ability is still charging.
	if is_ability_on_cooldown():
		return 0
	var params := context.store.create_object()
	params.set_key("bucketId", "default")
	params.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player.player_id)
	var res = call_service("Ability", "UseSelectedAbility", params)
	if res == null:
		return 0
	_start_ability_cooldown()
	return 1

## Begins the shared cooldown from the configured global duration (run-elapsed clock).
func _start_ability_cooldown() -> void:
	var cd := _read_global_ability_cooldown_seconds()
	if cd <= 0.0:
		return
	_ability_cooldown_total = cd
	_ability_cooldown_ready_at = _run_elapsed_seconds + cd

func _read_global_ability_cooldown_seconds() -> float:
	if context == null or context.state == null:
		return DEFAULT_ABILITY_COOLDOWN_SECONDS
	var ep := context.state.root.get_node("Ephemeral")
	if not ep.is_valid():
		return DEFAULT_ABILITY_COOLDOWN_SECONDS
	var bag := ep.get_node("abilities").get_node("default")
	if bag.is_valid():
		var n := bag.get_node("globalCooldownSeconds")
		if n.is_valid() and n.value != null and float(n.value) > 0.0:
			return float(n.value)
	return DEFAULT_ABILITY_COOLDOWN_SECONDS

## --- Shared ability cooldown (read by the bottom-bar ability cycler) ---

func get_ability_cooldown_total_seconds() -> float:
	return _ability_cooldown_total

func get_ability_cooldown_remaining_seconds() -> float:
	if _ability_cooldown_total <= 0.0:
		return 0.0
	return maxf(0.0, _ability_cooldown_ready_at - _run_elapsed_seconds)

func is_ability_on_cooldown() -> bool:
	return get_ability_cooldown_remaining_seconds() > 0.0

func _ability_ids() -> Array:
	var ids: Array = []
	var ep := context.state.root.get_node("Ephemeral")
	if not ep.is_valid():
		return ids
	var buckets := ep.get_node("abilities")
	if not buckets.is_valid() or buckets.get_type() != GnosisValueType.OBJECT:
		return ids
	var bag := buckets.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return ids
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return ids
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var id_node := entry.get_node("id")
		if not id_node.is_valid() or id_node.get_type() != GnosisValueType.STRING:
			id_node = entry.get_node("abilityId")
		if id_node.is_valid() and id_node.get_type() == GnosisValueType.STRING:
			ids.append(str(id_node.value))
	return ids

func _cycle_ability_selection(direction: int) -> void:
	var ids := _ability_ids()
	if ids.is_empty():
		return
	var sel = call_service("Ability", "GetSelectedAbility", context.store.create_object())
	var current_id := ""
	if sel is GnosisNode and sel.is_valid():
		var n: GnosisNode = sel.get_node("abilityId")
		if n.is_valid() and n.get_type() == GnosisValueType.STRING:
			current_id = str(n.value)
	var current_index := ids.find(current_id)
	if current_index < 0:
		current_index = 0
	var next := ((current_index + direction) % ids.size() + ids.size()) % ids.size()
	var params := context.store.create_object()
	params.set_key("bucketId", "default")
	params.set_key("abilityId", str(ids[next]))
	call_service("Ability", "SetSelectedAbility", params)

func _publish_spawn_needed(player_id: String, spawn_reason: String) -> void:
	if not context or not context.event_bus or not context.store:
		_spawn_piece_for_player(_resolve_player(player_id))
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_SPAWN_REASON, spawn_reason)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_SPAWN_NEEDED, payload, false))

func _on_spawn_piece_ready(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	var player_id := _read_string(event.data, FallingBlockEvents.PAYLOAD_PLAYER_ID)
	var ultravibe_id := _read_string(event.data, FallingBlockEvents.PAYLOAD_ULTRAVIBE_ID)
	var variant_id := _read_string(event.data, FallingBlockEvents.PAYLOAD_VARIANT_ID)
	if variant_id.is_empty():
		variant_id = "blue"
	var player := _resolve_player(player_id)
	if player:
		_spawn_piece_for_player(player, ultravibe_id, variant_id)

func _on_falling_block_input_requested(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	var allowed := _read_bool(event.data, FallingBlockEvents.PAYLOAD_ALLOWED, true)
	var player_id := _read_string(event.data, FallingBlockEvents.PAYLOAD_PLAYER_ID)
	var input_type_str := _read_string(event.data, FallingBlockEvents.PAYLOAD_INPUT_TYPE)
	if not allowed:
		return
	var input_type := _parse_input_type(input_type_str)
	if input_type < 0:
		return
	var input := InputEventData.new()
	input.player_id = player_id
	input.type = input_type
	var hard_drop_cells := handle_input(input)
	if context and context.event_bus and context.store:
		var payload := context.store.create_object()
		payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player_id)
		payload.set_key(FallingBlockEvents.PAYLOAD_INPUT_TYPE, input_type_str)
		payload.set_key(FallingBlockEvents.PAYLOAD_DROP_DISTANCE, float(hard_drop_cells))
		context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_INPUT_PROCESSED, payload, false))

func publish_input_from_adapter(player_id: String, input_type: int) -> void:
	if not context or not context.store or not context.event_bus:
		return
	var payload := context.store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_PLAYER_ID, player_id)
	payload.set_key(FallingBlockEvents.PAYLOAD_INPUT_TYPE, _input_type_to_string(input_type))
	payload.set_key(FallingBlockEvents.PAYLOAD_ALLOWED, true)
	context.event_bus.publish(GnosisEvent.new(FallingBlockEvents.REQUEST_FALLING_BLOCK_INPUT, payload, false))

# Adapters build the runtime player array while binding, which happens during
# restart_ephemeral_run() before the chosen playerCount is written to Ephemeral.
# Resize the shared array in-place here so the live run matches the selected
# player count (it is the same Array object the adapter renders from).
func _sync_runtime_player_count(player_count: int) -> void:
	var desired := PlayerRuntime.clamp_player_count(player_count)
	while _runtime_players.size() > desired:
		_runtime_players.pop_back()
	for i in range(_runtime_players.size()):
		var existing := _runtime_players[i] as PlayerState
		if existing:
			existing.player_id = PlayerRuntime.build_player_id(i)
	while _runtime_players.size() < desired:
		var ps := PlayerState.new()
		ps.player_id = PlayerRuntime.build_player_id(_runtime_players.size())
		_runtime_players.append(ps)

func _resolve_player(player_id: String) -> PlayerState:
	if _runtime_players.is_empty():
		return null
	var normalized := PlayerRuntime.normalize_runtime_player_id(player_id)
	if not normalized.is_empty():
		for player in _runtime_players:
			if player and player.player_id == normalized:
				return player
	return _runtime_players[0]

func _read_configured_grid_width(player_count: int) -> int:
	var width := clampi(
		FB.get_fb_int(context, "tetrisGridWidth", DEFAULT_GRID_WIDTH),
		MIN_GRID_WIDTH,
		MAX_GRID_WIDTH
	)
	if PlayerRuntime.uses_split_lanes(player_count):
		width = PlayerRuntime.adjust_grid_width_for_player_count(width, player_count)
	return width

func _read_configured_visible_height() -> int:
	return clampi(
		FB.get_fb_int(context, "tetrisGridVisibleHeight", DEFAULT_GRID_VISIBLE_HEIGHT),
		4,
		64
	)

func _read_configured_hidden_rows() -> int:
	return clampi(
		FB.get_fb_int(context, "tetrisGridHiddenRows", DEFAULT_GRID_HIDDEN_ROWS),
		0,
		16
	)

func _try_accept_hard_drop(player: PlayerState) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if player.current_piece_instance_id.is_empty():
		return false
	if now < player.hard_drop_allowed_after_unscaled_time:
		return false
	if player.last_hard_drop_accepted_at_unscaled_time > 0.0 and now - player.last_hard_drop_accepted_at_unscaled_time < MIN_SECONDS_BETWEEN_PLAYER_HARD_DROPS:
		return false
	player.last_hard_drop_accepted_at_unscaled_time = now
	return true

func _refresh_lock_delay_after_move(player: PlayerState) -> void:
	if _piece_lifecycle.can_move_piece(_runtime_grid_state, player, Vector2i(0, -1)):
		player.is_on_ground = false
		_clear_lock_delay(player)
	else:
		var was_already_grounded := player.is_on_ground or player.lock_delay_expires_at_unscaled_time > 0.0
		player.is_on_ground = true
		if was_already_grounded:
			_refresh_grounded_lock_delay(player)
		else:
			_arm_lock_delay(player)

func _clear_lock_delay(player: PlayerState) -> void:
	player.lock_delay_expires_at_unscaled_time = 0.0

func _refresh_grounded_lock_delay(player: PlayerState) -> void:
	if player.lock_delay_refresh_count >= MAX_LOCK_DELAY_REFRESHES_PER_PIECE:
		return
	player.lock_delay_refresh_count += 1
	_arm_lock_delay(player)

func _arm_lock_delay(player: PlayerState) -> void:
	player.lock_delay_expires_at_unscaled_time = Time.get_ticks_msec() / 1000.0 + LOCK_DELAY_SECONDS

func _parse_input_type(value: String) -> int:
	match value.to_lower().replace("_", ""):
		"moveleft": return FallingBlockModels.InputType.MOVE_LEFT
		"moveright": return FallingBlockModels.InputType.MOVE_RIGHT
		"softdrop": return FallingBlockModels.InputType.SOFT_DROP
		"harddrop": return FallingBlockModels.InputType.HARD_DROP
		"rotatecw": return FallingBlockModels.InputType.ROTATE_CW
		"rotateccw": return FallingBlockModels.InputType.ROTATE_CCW
		"discard": return FallingBlockModels.InputType.DISCARD
		"useconsumable": return FallingBlockModels.InputType.USE_CONSUMABLE
		"consumablenext": return FallingBlockModels.InputType.CONSUMABLE_NEXT
		"consumableprevious": return FallingBlockModels.InputType.CONSUMABLE_PREVIOUS
		"ability", "abilityuse":
			return FallingBlockModels.InputType.ABILITY
		"abilitynext": return FallingBlockModels.InputType.ABILITY_NEXT
		"abilityprevious": return FallingBlockModels.InputType.ABILITY_PREVIOUS
	return -1

func _input_type_to_string(input_type: int) -> String:
	match input_type:
		FallingBlockModels.InputType.MOVE_LEFT: return "MoveLeft"
		FallingBlockModels.InputType.MOVE_RIGHT: return "MoveRight"
		FallingBlockModels.InputType.SOFT_DROP: return "SoftDrop"
		FallingBlockModels.InputType.HARD_DROP: return "HardDrop"
		FallingBlockModels.InputType.ROTATE_CW: return "RotateCW"
		FallingBlockModels.InputType.ROTATE_CCW: return "RotateCCW"
		FallingBlockModels.InputType.DISCARD: return "Discard"
		FallingBlockModels.InputType.USE_CONSUMABLE: return "UseConsumable"
		FallingBlockModels.InputType.CONSUMABLE_NEXT: return "ConsumableNext"
		FallingBlockModels.InputType.CONSUMABLE_PREVIOUS: return "ConsumablePrevious"
		FallingBlockModels.InputType.ABILITY: return "Ability"
		FallingBlockModels.InputType.ABILITY_NEXT: return "AbilityNext"
		FallingBlockModels.InputType.ABILITY_PREVIOUS: return "AbilityPrevious"
	return ""

func _read_string(data: GnosisNode, key: String) -> String:
	if not data.is_valid():
		return ""
	var node := data.get_node(key)
	if node.is_valid() and node.value != null:
		return str(node.value)
	return ""

func _read_bool(data: GnosisNode, key: String, default_value: bool) -> bool:
	if not data.is_valid():
		return default_value
	var node := data.get_node(key)
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return default_value

func _dispose_subscription(sub: RefCounted) -> void:
	if sub and sub.has_method("dispose"):
		sub.dispose()

# --- Parity helpers (invocations, boss effects, co-op, tag sim) ---

func _variant_exists(variant_id: String) -> bool:
	if not context:
		return false
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return false
	var variant := config_root.get_node("variants").get_node(variant_id.strip_edges().to_lower())
	return variant.is_valid() and variant.get_type() == GnosisValueType.OBJECT

func _is_levelable_variant(variant_id: String) -> bool:
	if variant_id in ["ghost", "disabled"]:
		return false
	if _is_negative_variant(variant_id):
		return false
	return _variant_exists(variant_id)

func _write_variant_level(variant_id: String, level: int) -> void:
	var levels := FB.get_fb_node(context, EPHEMERAL_VARIANT_LEVELS)
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		levels = context.store.create_object()
		FB.set_fb_node(context, EPHEMERAL_VARIANT_LEVELS, levels)
	levels.set_key(variant_id.strip_edges().to_lower(), maxi(1, level))

func _cell_has_immutable_tag(cell: FallingBlockModels.CellState) -> bool:
	if cell == null:
		return false
	return FallingBlockTraitTags.cell_has_tag(cell, "immutable", _get_variant_tags(cell.variant_id))

func _apply_linked_cascade_before_clear(clearable_rows: Array) -> void:
	if _runtime_grid_state == null or clearable_rows.is_empty():
		return
	var extra_positions: Array[Vector2i] = []
	var marked := {}
	for y_raw in clearable_rows:
		var y := int(y_raw)
		if y < 0 or y >= _runtime_grid_state.height:
			continue
		for x in range(_runtime_grid_state.width):
			var idx: int = y * _runtime_grid_state.width + x
			var cell: FallingBlockModels.CellState = _runtime_grid_state.cells[idx]
			if cell == null or cell.block_id.is_empty():
				continue
			if not FallingBlockTraitTags.cell_has_tag(cell, "linked", _get_variant_tags(cell.variant_id)):
				continue
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					if ox == 0 and oy == 0:
						continue
					var nx: int = x + ox
					var ny: int = y + oy
					if nx < 0 or nx >= _runtime_grid_state.width or ny < 0 or ny >= _runtime_grid_state.height:
						continue
					var key := "%d,%d" % [nx, ny]
					if marked.has(key):
						continue
					var neighbor: FallingBlockModels.CellState = _runtime_grid_state.cells[ny * _runtime_grid_state.width + nx]
					if neighbor == null or neighbor.block_id.is_empty() or not neighbor.is_locked:
						continue
					if not FallingBlockTraitTags.cell_has_tag(neighbor, "linked", _get_variant_tags(neighbor.variant_id)):
						continue
					marked[key] = true
					extra_positions.append(Vector2i(nx, ny))
	if not extra_positions.is_empty():
		_grid_system.clear_cells_at(_runtime_grid_state, extra_positions)

func _is_negative_variant(variant_id: String) -> bool:
	for tag in _get_variant_tags(variant_id):
		if str(tag).to_lower() == "negative":
			return true
	return false

func _pick_random_variant_by_polarity(want_negative: bool) -> String:
	if not context:
		return ""
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return ""
	var variants := config_root.get_node("variants")
	if not variants.is_valid():
		return ""
	var pool: Array[String] = []
	for vid in variants.get_keys():
		var key := str(vid).to_lower()
		var is_neg := _is_negative_variant(key)
		if is_neg == want_negative:
			pool.append(key)
	if pool.is_empty():
		return ""
	return pool[_rng.randi_range(0, pool.size() - 1)]

func _variant_placement_discard_chance(variant_id: String) -> int:
	return _read_variant_int_property(variant_id, "placementDiscardChancePercent")

func _variant_placement_discard_drain_chance(variant_id: String) -> int:
	return _read_variant_int_property(variant_id, "placementDiscardDrainChancePercent")

func _read_variant_int_property(variant_id: String, prop: String) -> int:
	if not context or variant_id.is_empty():
		return 0
	var config_root := get_node("configuration", true)
	var variant := config_root.get_node("variants").get_node(variant_id.strip_edges().to_lower())
	if not variant.is_valid():
		return 0
	return FB.read_int(variant.get_node(prop), 0)

func _apply_synthetic_line_clear(rows: Array, player_id: String) -> int:
	if rows.is_empty() or _runtime_grid_state == null:
		return 0
	var line_ctx := _build_line_clear_context(rows)
	var cleared := _grid_system.clear_full_rows_and_collapse(_runtime_grid_state, rows)
	if cleared > 0:
		var player := _resolve_player(player_id)
		line_ctx["raw_lines"] = cleared
		_on_physical_lines_cleared(player, cleared, line_ctx)
	return cleared

func _process_grid_line_clears(player_id: String) -> int:
	var rows := _compute_clearable_rows()
	if rows.is_empty():
		return 0
	return _apply_synthetic_line_clear(rows, player_id)

func apply_equipped_boon_spawn_conversions_to_payload(payload: GnosisNode) -> void:
	if not FallingBlockGameFlags.is_include_boons(context) or payload == null or not payload.is_valid():
		return
	# Boon spawn conversions are primarily handled by Rule interceptors; this hook
	# exists for Deck parity when per-boon spawnConversions are added to catalog JSON.
	pass
