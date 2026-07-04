class_name Match3Service
extends GnosisService

## UltraVibe match-3 run authority (initial Godot port of Match3GnosisService).

const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Match3GameplayScript = preload("res://game/match3/core/match3_gameplay.gd")
const Match3BoardLayoutScript = preload("res://game/match3/core/match3_board_layout.gd")
const Match3FloorModifierPoolScript = preload("res://game/match3/core/match3_floor_modifier_pool.gd")
const Match3BoonRuntimeScript = preload("res://game/match3/boons/match3_boon_runtime.gd")
const Match3Match3EffectsScript = preload("res://game/match3/effects/match3_match3_effects.gd")
const Match3CellFloorRuntimeScript = preload("res://game/match3/core/match3_cell_floor_runtime.gd")
const Match3CellFloorBoardScript = preload("res://game/match3/core/match3_cell_floor_board.gd")
const Match3BoonScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const Match3BoonMatchFloorConversionsScript = preload("res://game/match3/boons/match3_boon_match_floor_conversions.gd")
const Match3BoonJuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
const Match3GameSpeedScript = preload("res://game/match3/core/match3_game_speed.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ConsumableServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_consumable_service.gd")

const Events = Match3EventsScript
const Models = Match3ModelsScript

const BASE_MOVES_LIMIT := 10
const BASE_SCORE_TO_WIN := 1000
const BASE_COLOR_LIMIT := 6
const DEFAULT_BOARD_ID := "grid9x9_bm"
const BOARDS_INDEX_PATH := "res://data/Boards/index.json"
const DEFAULT_ROUNDS_PER_FLOOR := 3
const DEFAULT_SHUFFLES_PER_ROUND := 2
const DEFAULT_WINNING_ROUND := DEFAULT_ROUNDS_PER_FLOOR * 3
const DEFAULT_DOUBLE_DOWN_TARGET_MULTIPLIER := 10
const PENDING_ROUND_REWARD_KEY := "pendingRoundReward"
const PAYOUT_CURRENCY_ID := "money"

const ECHO_LAST_RUNE_OR_GRANT_CONSUMABLE_KEY := "echoLastRuneOrItemUpgradeGrantConsumableId"
const ECHOMANIA_CONSUMABLE_CATALOG_ID := "Echomania"
const CONSUMABLES_CONFIGURATION_ID := "consumables"
const MANIA_GAMEPLAY_TAG := "mania"
const ITEM_UPGRADE_GRANT_GAMEPLAY_TAG := "item_upgrade_grant"
const CLICKBAIT_BOON_CATALOG_ID := "Clickbait"
const SHOP_REROLL_LIFETIME_COUNTER_KEY := "shopRerollsLifetime"

const REWARD_REASON_ROUND := "match3__phrase__rewardRoundBoss"
const REWARD_REASON_UNUSED_MOVES := "match3__phrase__rewardUnusedMoves"
const REWARD_REASON_INTEREST := "match3__phrase__rewardInterest"
const REWARD_REASON_COOKIE_TIME := "match3__phrase__rewardCookieTime"
const REWARD_REASON_PASSIVE_INCOME := "match3__phrase__rewardPassiveIncome"
const REWARD_REASON_SLEEPER := "match3__phrase__rewardSleeper"
const REWARD_REASON_DOUBLE_DOWN := "match3__phrase__rewardDoubleDown"
const ROUND_ACTION_REWARD_GAMEPLAY_TAG := "roundAction"
const ROUND_ACTION_REWARD_LOCKS_KEY := "roundActionRewardLocks"
const BOON_EFFECT_APPLICATION_PER_INSTANCE := "perInstance"
const BOON_CATALOG_ID_PASSIVE_INCOME := "PassiveIncome"
const BOON_CATALOG_ID_COOKIE_TIME := "CookieTime"
const BOON_CATALOG_ID_DOUBLE_DOWN := "DoubleDown"
const BOON_CATALOG_ID_SLEEPER := "Sleeper"
const BOON_CATALOG_ID_SIMP := "Simp"
const BOON_CATALOG_ID_DARWIN := "Darwin"
const BOON_CATALOG_ID_BACKSTABBER := "Backstabber"
const EPHEMERAL_SELECTED_CONSUMABLE_SLOT := "selectedConsumableSlotIndex"
const CONSUMABLE_JUICE_DISPLAY_USE := "Use"
const CONSUMABLE_USE_DISPLAY_KEY := "match3__phrase__consumableUse"
const COLOR_LIMIT_PLAYABLE_SMALL := 42
const COLOR_LIMIT_PLAYABLE_MEDIUM := 63

var _gameplay = Match3GameplayScript.new()
var _item_points: Dictionary = {}
var _current_round := 1
var _active_board_id := ""
var _active_level_id := "normal"
var _current_floor := 1
var _round_in_floor := 1
var _active_stage_type := "normal"
var _manual_shuffles_remaining := 0
var _boss_profiles_loaded := false
var _boss_profile_ids: Array[String] = []
var _normal_profile_ids: Array[String] = []
var _advanced_profile_ids: Array[String] = []
var _floor_bundle_plans: Dictionary = {}
var _board_pools_loaded := false
var _last_step_points := 0
var _last_step_multi := 0
var _last_move_score := 0
var _normal_board_pool_ids: Array[String] = []
var _advanced_board_pool_ids: Array[String] = []
var _boss_board_pool_ids: Array[String] = []
var _board_difficulty_by_id: Dictionary = {}
var _round_action_reward_locks: Dictionary = {}
var _consumable_use_presentation_pending := false
var _boon_runtime: RefCounted = null
var _match3_effects: RefCounted = null
var _cell_floor_runtime: RefCounted = null

var _move_subscription: RefCounted = null
var _reset_subscription: RefCounted = null
var _begin_level_subscription: RefCounted = null
var _consumable_used_subscription: RefCounted = null

const DEFAULT_HEARTBEAT_CLIP_IDS: Array[String] = ["heartbeatSfx1", "heartbeatSfx2"]
var _cached_heartbeat_clip_ids: Array[String] = DEFAULT_HEARTBEAT_CLIP_IDS.duplicate()
var _cached_heartbeat_moves_at_or_below := 3
var _cached_heartbeat_cooldown_sec := 12.0
var _cached_heartbeat_delay_sec := 0.22
var _last_heartbeat_unscaled_time := -INF
var _heartbeat_clip_alternator := 0


func _init() -> void:
	super._init("Match3", GnosisLifetime.TRANSIENT)


func on_initialize() -> void:
	_refresh_item_catalog()
	_load_board_pools()
	_hydrate_runtime_from_store()
	_boon_runtime = Match3BoonRuntimeScript.new(self)
	_match3_effects = Match3Match3EffectsScript.new(self)
	_cell_floor_runtime = Match3CellFloorRuntimeScript.new(self)
	var m3 := get_node("match3", false)
	if m3.is_valid() and _match3_effects != null:
		_match3_effects.hydrate_from_store(m3)
	_sync_gameplay_effect_flags()
	_gameplay.set_boon_score_finalize_hook(Callable(_boon_runtime, "apply_finalize_for_move"))
	_gameplay.set_boon_first_match_hook(Callable(_boon_runtime, "try_apply_first_match_gem_level_chance"))
	_gameplay.set_boon_resolve_begin_hook(Callable(_boon_runtime, "begin_resolve_step"))
	_gameplay.set_boon_resolve_item_destroyed_hook(Callable(_boon_runtime, "apply_resolve_item_destroyed"))
	_gameplay.set_boon_resolve_step_cascade_hook(Callable(_boon_runtime, "apply_resolve_step_cascade"))
	_gameplay.set_cell_floor_scoring_hook(Callable(_cell_floor_runtime, "on_scoring_destroy"))
	_gameplay.set_cell_floor_finalize_hook(Callable(_cell_floor_runtime, "on_move_finalize"))
	_gameplay.set_cell_floor_griefing_hook(Callable(_cell_floor_runtime, "on_griefing_pre_score"))
	_gameplay.set_match_floor_conversion_hook(Callable(self, "_apply_match_floor_conversions_after_clear"))
	_gameplay.set_tile_score_resolver(Callable(self, "_resolve_item_score_profile"))
	_gameplay.set_spawn_item_type_resolver(Callable(self, "_resolve_spawn_item_type_id_for_block"))
	_gameplay.status = Models.STATUS_LEVEL_SELECT_PANEL
	_publish_ephemeral_state()
	if context and context.event_bus:
		_move_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_MOVE, _on_move_requested, 0)
		_reset_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_RESET, _on_reset_requested, 0)
		_begin_level_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_BEGIN_LEVEL, _on_begin_level_requested, 0)
		_consumable_used_subscription = context.event_bus.subscribe(
			ConsumableServiceScript.FACT_CONSUMABLE_USED, _on_consumable_used_for_echo_tracking, 0)
	_refresh_match3_audio_cache_from_ephemeral()
	_publish_fact(Events.FACT_MATCH3_EPHEMERAL_SERVICE_STARTED)


func on_shutdown() -> void:
	_publish_fact(Events.FACT_MATCH3_EPHEMERAL_SERVICE_STOPPED)
	_dispose_subscription(_move_subscription)
	_dispose_subscription(_reset_subscription)
	_dispose_subscription(_begin_level_subscription)
	_dispose_subscription(_consumable_used_subscription)
	_move_subscription = null
	_reset_subscription = null
	_begin_level_subscription = null
	_consumable_used_subscription = null


func get_functions() -> Array:
	return [
		"PlayLevel",
		"PlayLevelDoubleDown",
		"SkipLevel",
		"TryUseShuffle",
		"GrantNextRoundRewardStep",
		"TransitionToState",
		"AddFloorModifierPoolDelta",
		"DestroyRandomCellFloorOnBoard",
		"RollRandomBoon",
		"DuplicateRandomEquippedBoon",
		"PanicSwapAllEquippedBoons",
		"ApplyBoonSlotCapacityDelta",
		"ApplyConsumableSlotCapacityDelta",
		"AddItemLevelDelta",
		"ApplyEffect",
		"RemoveEffect",
		"GrantRandomRunUpgrade",
		"AddRoundMovesBonus",
		"GrantCurrencyFromStatisticCounter",
		"AddCoreShopFreeRerollCountDelta",
		"AddCoreShopRerollFlatDiscountDelta",
		"AddCoreShopSlotsDelta",
		"AddShopDiscountPercentDelta",
		"AddDefaultMovesPerRoundDelta",
		"AddDefaultShufflesPerRoundDelta",
		"DuplicateLastRuneOrItemUpgradeGrantConsumable",
		"ApplyShopRerollScalingAfterCoreShopReroll",
		"RerollUpcomingBossRound",
		"JuiceBoonMatch3RoundEffectOnActivate",
		"SyncEquippedBoonMatch3RoundEffects",
	]


func invoke_function(name: String, parameters: GnosisNode) -> Variant:
	if _boon_runtime != null and _boon_runtime.handles_invoke(name):
		return _boon_runtime.invoke(name, parameters)
	match name:
		"PlayLevel":
			var double_down := false
			if parameters != null and parameters.is_valid():
				double_down = _node_bool(parameters, Events.PAYLOAD_DOUBLE_DOWN, false)
			return _play_level_from_queue(double_down)
		"PlayLevelDoubleDown":
			return _play_level_from_queue(true)
		"SkipLevel":
			return _skip_level_from_queue()
		"TryUseShuffle":
			return _try_use_shuffle()
		"GrantNextRoundRewardStep":
			return _grant_next_round_reward_step()
		"TransitionToState":
			var raw_status := ""
			if parameters != null and parameters.is_valid():
				raw_status = _node_str(parameters, Events.PAYLOAD_GAME_STATUS)
			return _transition_to_state(raw_status)
		"AddFloorModifierPoolDelta":
			return _add_floor_modifier_pool_delta(parameters)
		"AddItemLevelDelta":
			return _add_item_level_delta(parameters)
		"ApplyEffect":
			return _apply_match3_effect(parameters)
		"RemoveEffect":
			return _remove_match3_effect(parameters)
		"GrantRandomRunUpgrade":
			return _grant_random_run_upgrade(parameters)
		"AddRoundMovesBonus":
			return _add_round_moves_bonus(parameters)
		"GrantCurrencyFromStatisticCounter":
			return _grant_currency_from_statistic_counter(parameters)
		"AddCoreShopFreeRerollCountDelta":
			return _add_core_shop_free_reroll_count_delta(parameters)
		"AddCoreShopRerollFlatDiscountDelta":
			return _add_core_shop_reroll_flat_discount_delta(parameters)
		"AddCoreShopSlotsDelta":
			return _add_core_shop_slots_delta(parameters)
		"AddShopDiscountPercentDelta":
			return _add_shop_discount_percent_delta(parameters)
		"AddDefaultMovesPerRoundDelta":
			return _add_default_moves_per_round_delta(parameters)
		"AddDefaultShufflesPerRoundDelta":
			return _add_default_shuffles_per_round_delta(parameters)
		"DuplicateLastRuneOrItemUpgradeGrantConsumable":
			return _duplicate_last_rune_or_item_upgrade_grant_consumable(parameters)
		"ApplyShopRerollScalingAfterCoreShopReroll":
			return _apply_shop_reroll_scaling_after_core_shop_reroll(parameters)
		"RerollUpcomingBossRound":
			return _reroll_upcoming_boss_round()
		"DestroyRandomCellFloorOnBoard":
			return _destroy_random_cell_floor_on_board(parameters)
	return GnosisFunctionResult.fail("Unknown Match3 function '%s'." % name)


func get_gameplay():
	return _gameplay


func are_cell_floor_modifiers_disabled() -> bool:
	return _match3_effects != null and _match3_effects.disable_all_cell_floor_modifiers


func add_manual_shuffles(delta: int) -> void:
	_manual_shuffles_remaining = maxi(0, _manual_shuffles_remaining + delta)


func add_current_moves(delta: int) -> void:
	_gameplay.current_moves = maxi(0, _gameplay.current_moves + delta)


func play_cell_floor_type_sfx(type_row: GnosisNode, key: String) -> void:
	if context == null or context.engine == null or type_row == null or not type_row.is_valid():
		return
	var clip_id := _node_str(type_row, key)
	if clip_id.is_empty():
		return
	var audio = context.engine.get_service("Audio")
	if audio == null or not audio.has_method("play_sound"):
		return
	var options := context.store.create_object()
	audio.play_sound(clip_id, 0, false, false, options)


func _apply_match_floor_conversions_after_clear(match_result: Models.MatchResult) -> void:
	Match3BoonMatchFloorConversionsScript.try_apply_after_match_clear(self, match_result)


func configure_boon_score_rng(seed_value: int) -> void:
	if _boon_runtime != null and _boon_runtime.has_method("configure_rng"):
		_boon_runtime.configure_rng(seed_value)


func play_boon_scaling_juice_now(slot_index: int, counter_key: String = "") -> void:
	Match3BoonJuiceScript.publish_scaling_juice(self, slot_index, counter_key)


func get_heartbeat_delay_after_move_complete_seconds() -> float:
	var delay := _cached_heartbeat_delay_sec
	if is_nan(delay) or is_inf(delay) or delay < 0.0:
		delay = 0.22
	delay = clampf(delay, 0.0, 3.0)
	return Match3GameSpeedScript.scale_duration(_engine_for_speed(), delay, 0.03)


func try_play_heartbeat_hint_after_move_if_needed() -> void:
	if context == null or context.store == null:
		return
	if _cached_heartbeat_moves_at_or_below <= 0:
		return
	var moves_remaining: int = _gameplay.current_moves if _gameplay != null else 0
	if moves_remaining <= 0 or moves_remaining > _cached_heartbeat_moves_at_or_below:
		return
	if _cached_heartbeat_clip_ids.is_empty():
		return
	var cooldown := maxf(2.0, _cached_heartbeat_cooldown_sec)
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_heartbeat_unscaled_time < cooldown:
		return
	var clip_id := _cached_heartbeat_clip_ids[_heartbeat_clip_alternator % _cached_heartbeat_clip_ids.size()].strip_edges()
	_heartbeat_clip_alternator += 1
	if clip_id.is_empty():
		return
	_play_match3_one_shot_sfx(clip_id)
	_last_heartbeat_unscaled_time = now


func _refresh_match3_audio_cache_from_ephemeral() -> void:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return
	var audio := m3.get_node("audio")
	if not audio.is_valid() or audio.get_type() != GnosisValueType.OBJECT:
		return
	_cached_heartbeat_clip_ids = _read_audio_clip_id_list(audio, "heartbeatSfxClipIds", DEFAULT_HEARTBEAT_CLIP_IDS)
	_cached_heartbeat_moves_at_or_below = _node_int(audio, "heartbeatMovesRemainingAtOrBelow", 3)
	_cached_heartbeat_delay_sec = _node_float(audio, "heartbeatDelayAfterMoveCompleteSeconds", 0.22)
	var cooldown := _node_float(audio, "heartbeatCooldownSeconds", 12.0)
	_cached_heartbeat_cooldown_sec = maxf(2.0, cooldown if not is_nan(cooldown) and not is_inf(cooldown) else 12.0)


func _reset_heartbeat_hint_for_new_round() -> void:
	_refresh_match3_audio_cache_from_ephemeral()
	_last_heartbeat_unscaled_time = -INF
	_heartbeat_clip_alternator = 0


func _read_audio_clip_id_list(audio: GnosisNode, key: String, defaults: Array[String]) -> Array[String]:
	var list_node := audio.get_node(key)
	if not list_node.is_valid() or list_node.get_type() != GnosisValueType.LIST or list_node.get_count() == 0:
		return defaults.duplicate()
	var out: Array[String] = []
	for i in range(list_node.get_count()):
		var id := str(_node_value(list_node.get_node(i))).strip_edges()
		if not id.is_empty():
			out.append(id)
	return out if not out.is_empty() else defaults.duplicate()


func _play_match3_one_shot_sfx(clip_id: String) -> void:
	if clip_id.is_empty() or context == null or context.engine == null:
		return
	var audio = context.engine.get_service("Audio")
	if audio == null or not audio.has_method("play_sound"):
		return
	var options := context.store.create_object()
	audio.play_sound(clip_id, 0, false, false, options)


func _node_float(node: GnosisNode, key: String, default_value: float = 0.0) -> float:
	if not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return float(child.value)


func apply_cell_floor_finalize_echo(floor_type_id: String, points: int, multi: int) -> Dictionary:
	if _boon_runtime != null and _boon_runtime.has_method("apply_cell_floor_finalize_echo"):
		return _boon_runtime.call("apply_cell_floor_finalize_echo", floor_type_id, points, multi)
	return {"points": points, "multi": multi}


func _destroy_random_cell_floor_on_board(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var gameplay_tag := _node_str(parameters, "gameplayTag", "enhanced")
	if gameplay_tag.is_empty():
		gameplay_tag = "enhanced"
	var result: Dictionary = Match3CellFloorBoardScript.destroy_random_cell_floor_on_board(self, gameplay_tag)
	var payload := context.store.create_object()
	payload.set_key("success", bool(result.get("success", false)))
	payload.set_key("gameplayTag", gameplay_tag)
	if bool(result.get("success", false)):
		payload.set_key("x", int(result.get("x", 0)))
		payload.set_key("y", int(result.get("y", 0)))
		payload.set_key("cellFloorTypeId", str(result.get("cellFloorTypeId", "")))
		_publish_board_reset()
		_publish_ephemeral_state()
	return GnosisFunctionResult.ok(payload)


func try_add_floor_modifier_pool_slots(floor_type_id: String, count: int) -> int:
	if context == null or context.store == null or count <= 0:
		return 0
	var type_id := floor_type_id.strip_edges()
	if type_id.is_empty():
		return 0
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return 0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s:pool_grant" % [_try_get_run_seed(), type_id])
	var result: Dictionary = Match3FloorModifierPoolScript.add_delta(
		m3,
		context.store,
		type_id,
		count,
		_cell_floor_catalog_type_ids(),
		rng
	)
	var applied := int(result.get("applied", 0))
	if applied <= 0:
		return 0
	if _is_board_grid_ready():
		Match3FloorModifierPoolScript.apply_layout_to_gameplay(
			_gameplay,
			m3.get_node(Match3FloorModifierPoolScript.POOL_KEY),
			rng
		)
		_notify_enhanced_floors_on_board(true)
		sync_floor_modifier_tile_statistics_from_grid()
		_publish_board_reset()
	else:
		_publish_ephemeral_state()
	return applied


func sync_floor_modifier_tile_statistics_from_grid() -> void:
	if context == null or context.store == null or _gameplay == null:
		return
	_ensure_statistics_root()
	var stats := get_node("statistics", false)
	if not stats.is_valid():
		return
	var match3_stats := stats.get_node("match3")
	if not match3_stats.is_valid() or match3_stats.get_type() != GnosisValueType.OBJECT:
		match3_stats = context.store.create_object()
		stats.set_node("match3", match3_stats)
	var tiles := context.store.create_object()
	if not _is_board_grid_ready():
		tiles.set_key("capacity", 0)
		tiles.set_key("plain", 0)
		tiles.set_key("total", 0)
		tiles.set_key("enhanced", 0)
	else:
		var counts: Dictionary = {}
		var enhanced_by_type: Dictionary = {}
		var capacity_count := 0
		var plain_count := 0
		var total_non_empty := 0
		var enhanced_count := 0
		for y in _gameplay.height:
			for x in _gameplay.width:
				var tile = _gameplay.get_tile(x, y)
				if tile == null or not tile.can_hold_item():
					continue
				capacity_count += 1
				var tid: String = tile.cell_floor_type_id.strip_edges()
				if tid.is_empty():
					plain_count += 1
					continue
				total_non_empty += 1
				var stat_key: String = tid.to_lower()
				counts[stat_key] = int(counts.get(stat_key, 0)) + 1
				if Match3CellFloorBoardScript.cell_floor_type_has_gameplay_tag(self, tid, "enhanced"):
					enhanced_count += 1
					enhanced_by_type[stat_key] = int(enhanced_by_type.get(stat_key, 0)) + 1
		tiles.set_key("capacity", capacity_count)
		tiles.set_key("plain", plain_count)
		tiles.set_key("total", total_non_empty)
		tiles.set_key("enhanced", enhanced_count)
		for key in counts.keys():
			tiles.set_key(str(key), int(counts[key]))
		for key in enhanced_by_type.keys():
			tiles.set_key("%s_enhanced" % str(key), int(enhanced_by_type[key]))
	var floor_mods := context.store.create_object()
	floor_mods.set_node("tiles", tiles)
	match3_stats.set_node("floorModifiers", floor_mods)


func _notify_enhanced_floors_on_board(prefer_immediate_juice: bool) -> void:
	if not _is_board_grid_ready():
		return
	for y in _gameplay.height:
		for x in _gameplay.width:
			var tile = _gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			var tid: String = tile.cell_floor_type_id.strip_edges()
			if tid.is_empty():
				continue
			Match3CellFloorBoardScript.notify_enhanced_floor_added(self, tid, "", prefer_immediate_juice)


func _apply_round_end_floor_boon_hooks() -> void:
	if _boon_runtime != null and _boon_runtime.has_method("apply_round_end_scaling_increments"):
		_boon_runtime.apply_round_end_scaling_increments()
	if _boon_runtime != null and _boon_runtime.has_method("apply_round_end_self_destructs"):
		_boon_runtime.apply_round_end_self_destructs(_active_stage_type == "boss")
	if _boon_runtime != null and _boon_runtime.has_method("apply_perishable_flavors_on_round_end"):
		_boon_runtime.apply_perishable_flavors_on_round_end()
	Match3CellFloorBoardScript.apply_red_flag_round_end_for_all_equipped(self, _gameplay)
	Match3CellFloorBoardScript.apply_boomer_round_end_pool_grants(self)
	_publish_ephemeral_state()


## Positive counts per enhanced floor type in the run pool (HUD left-rail tile panel).
func get_enhanced_floor_tile_counts() -> Dictionary:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return {}
	var pool := m3.get_node(Match3FloorModifierPoolScript.POOL_KEY)
	return Match3FloorModifierPoolScript.enhanced_counts_from_pool(
		pool,
		_enhanced_cell_floor_type_ids()
	)


func _add_floor_modifier_pool_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var floor_type_id := _node_str(parameters, "floorTypeId")
	if floor_type_id.is_empty():
		return GnosisFunctionResult.fail("floor_pool_invalid_type")
	var requested := _node_int(parameters, "count", 0)
	if requested <= 0:
		requested = _node_int(parameters, "amount", 3)
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3_missing")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [_try_get_run_seed(), floor_type_id])
	var result: Dictionary = Match3FloorModifierPoolScript.add_delta(
		m3,
		context.store,
		floor_type_id,
		requested,
		_cell_floor_catalog_type_ids(),
		rng
	)
	if int(result.get("applied", 0)) <= 0:
		return GnosisFunctionResult.fail(str(result.get("error", "floor_pool_no_slots_applied")))
	if _is_board_grid_ready():
		Match3FloorModifierPoolScript.apply_layout_to_gameplay(
			_gameplay,
			m3.get_node(Match3FloorModifierPoolScript.POOL_KEY),
			rng
		)
		_notify_enhanced_floors_on_board(true)
		sync_floor_modifier_tile_statistics_from_grid()
		_publish_board_reset()
	_publish_ephemeral_state()
	var ok := context.store.create_object()
	ok.set_key("success", true)
	ok.set_key("floorTypeId", floor_type_id)
	ok.set_key("poolSlotsMoved", int(result.get("applied", 0)))
	return GnosisFunctionResult.ok(ok)


func _add_item_level_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var item_id := _node_str(parameters, "itemId").strip_edges()
	if item_id.is_empty():
		return GnosisFunctionResult.fail("AddItemLevelDelta requires non-empty 'itemId'.")
	var delta := _node_int(parameters, "delta", 1)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddItemLevelDelta requires positive 'delta'.")

	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3_missing")

	var item_levels := m3.get_node("itemLevels")
	if not item_levels.is_valid() or item_levels.get_type() != GnosisValueType.OBJECT:
		item_levels = context.store.create_object()
		m3.set_key("itemLevels", item_levels)

	var previous := _resolve_item_level(item_id)
	var next := previous + delta
	item_levels.set_key(item_id, next)
	_increment_statistic("match3.itemLevelUpgradesApplied", delta)
	_try_juice_equipped_boons_after_item_level_upgrade(delta)
	_publish_ephemeral_state()

	var payload := context.store.create_object()
	payload.set_key("itemId", item_id)
	payload.set_key("previousLevel", previous)
	payload.set_key("level", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _try_juice_equipped_boons_after_item_level_upgrade(delta: int) -> void:
	if delta <= 0:
		return
	var darwin_slot := SupportScript.index_of_active_boon_slot_by_catalog_id(self, BOON_CATALOG_ID_DARWIN)
	if darwin_slot >= 0:
		play_boon_scaling_juice_now(darwin_slot)


func _cell_floor_catalog_type_ids() -> Array[String]:
	var out: Array[String] = []
	var catalog := _cell_floor_types_catalog()
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return out
	for type_id in catalog.get_keys():
		var id := str(type_id).strip_edges()
		if id.is_empty():
			continue
		out.append(id)
	out.sort()
	return out


func _enhanced_cell_floor_type_ids() -> Array[String]:
	var out: Array[String] = []
	var catalog := _cell_floor_types_catalog()
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return out
	for type_id in catalog.get_keys():
		var id := str(type_id).strip_edges()
		if id.is_empty():
			continue
		var row := catalog.get_node(id)
		if not row.is_valid() or row.get_type() != GnosisValueType.OBJECT:
			continue
		var props := row.get_node("properties")
		if not props.is_valid():
			continue
		var tags := props.get_node("gameplayTags")
		if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
			continue
		for i in tags.get_count():
			var tag_node := tags.get_node(i)
			if tag_node.is_valid() and str(tag_node.value).strip_edges().to_lower() == "enhanced":
				out.append(id)
				break
	out.sort()
	return out


func _cell_floor_types_catalog() -> GnosisNode:
	var config := get_node("configuration", true)
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node("match3CellFloorTypes")


func _ensure_floor_modifier_pool_published(m3: GnosisNode) -> void:
	if context == null or context.store == null or not m3.is_valid():
		return
	Match3FloorModifierPoolScript.ensure_pool(m3, context.store)
	m3.set_key("floorModifierPoolSize", Match3FloorModifierPoolScript.POOL_SIZE)


func _is_board_grid_ready() -> bool:
	return Match3FloorModifierPoolScript.is_board_grid_ready(_gameplay)


func get_current_status() -> int:
	return _gameplay.status


func get_current_round() -> int:
	return _current_round


## True once the run has advanced past the opening level select (i.e. the player
## has completed at least one round and entered the reward/shop loop). The shop is
## not part of the very first level select, so the swap button stays hidden there.
func is_shop_available() -> bool:
	var m3 := get_node("match3", false)
	return _node_int(m3, "nextLevel", 1) > 1


func get_current_floor() -> int:
	return _current_floor


func get_round_in_floor() -> int:
	return _round_in_floor


func get_rounds_per_floor() -> int:
	return DEFAULT_ROUNDS_PER_FLOOR


func get_shuffles_remaining() -> int:
	return _manual_shuffles_remaining


func is_boss_round() -> bool:
	return _active_stage_type == "boss"


## Run currency from Ephemeral.currencies.money (Unity parity).
func get_money() -> int:
	if context == null or context.engine == null or context.store == null:
		return 0
	var currency = context.engine.get_service("Currency")
	if currency == null or not currency.has_method("invoke_function"):
		return 0
	var params := context.store.create_object()
	params.set_key("currencyId", PAYOUT_CURRENCY_ID)
	var result = currency.invoke_function("GetBalance", params)
	var node := _coerce_result_node(result)
	if node != null and node.is_valid():
		return _node_int(node, "balance", 0)
	return 0


func get_consumable_use_display_text() -> String:
	if context == null or context.engine == null:
		return CONSUMABLE_JUICE_DISPLAY_USE
	var localization = context.engine.get_service("Localization")
	if localization == null or not localization.has_method("get_string_value"):
		return CONSUMABLE_JUICE_DISPLAY_USE
	return localization.get_string_value(CONSUMABLE_USE_DISPLAY_KEY, CONSUMABLE_JUICE_DISPLAY_USE)


func select_consumable_slot(index: int) -> void:
	var count := _consumable_list_count()
	if count <= 0:
		return
	set_node(EPHEMERAL_SELECTED_CONSUMABLE_SLOT, clampi(index, 0, count - 1), false)
	if context and context.engine:
		var changed_paths: Array[String] = ["Ephemeral.%s" % EPHEMERAL_SELECTED_CONSUMABLE_SLOT]
		context.engine.commit("match3", changed_paths)


func get_selected_consumable_slot() -> int:
	var count := _consumable_list_count()
	if count <= 0:
		return 0
	var slot := get_node(EPHEMERAL_SELECTED_CONSUMABLE_SLOT, false)
	var idx := int(slot.value) if slot.is_valid() and slot.value != null else 0
	return clampi(idx, 0, count - 1)


func request_use_selected_consumable() -> void:
	try_consume_selected_consumable_presentation()


func is_consumable_use_presentation_active() -> bool:
	return _consumable_use_presentation_pending


## Consumes the selected consumable and holds the presentation session open until
## the HUD calls complete_consumable_use_presentation_hud_step() after juice.
func try_consume_selected_consumable_presentation() -> bool:
	return try_consume_consumable_at_slot_presentation(get_selected_consumable_slot())


## Unity parity: pointer / controller row uses the consumable at index immediately.
func try_consume_consumable_at_slot_presentation(index: int) -> bool:
	if _consumable_use_presentation_pending:
		return false
	if context == null or context.store == null:
		return false
	var count := _consumable_list_count()
	if count <= 0:
		return false
	index = clampi(index, 0, count - 1)
	set_node(EPHEMERAL_SELECTED_CONSUMABLE_SLOT, index, false)
	var consumable_id := _read_consumable_id_at_index(index)
	if consumable_id.is_empty():
		return false
	_begin_consumable_use_presentation_session()
	var params := context.store.create_object()
	params.set_key("consumableId", consumable_id)
	params.set_key("bucketId", "default")
	var result = call_service("Consumable", "ConsumeConsumable", params)
	if _coerce_consumable_consume_result(result):
		_commit_currency_snapshot()
		_publish_ephemeral_state()
		return true
	_end_consumable_use_presentation_session_immediate()
	return false


func complete_consumable_use_presentation_hud_step() -> void:
	if not _consumable_use_presentation_pending:
		return
	_commit_currency_snapshot()
	_end_consumable_use_presentation_session_immediate()


func _begin_consumable_use_presentation_session() -> void:
	_consumable_use_presentation_pending = true
	_publish_consumable_use_presentation_active(true)


func _end_consumable_use_presentation_session_immediate() -> void:
	if not _consumable_use_presentation_pending:
		return
	_consumable_use_presentation_pending = false
	_publish_consumable_use_presentation_active(false)


func _publish_consumable_use_presentation_active(active: bool) -> void:
	if context == null or context.store == null:
		return
	var payload := context.store.create_object()
	payload.set_key(Events.PAYLOAD_CONSUMABLE_USE_PRESENTATION_ACTIVE, active)
	_publish_fact(Events.FACT_MATCH3_CONSUMABLE_USE_PRESENTATION_ACTIVE, payload)


## Currency/Match3 service invokes return either a GnosisFunctionResult (Match3,
## Shop) or the bare payload GnosisNode (Currency). Normalize to a GnosisNode.
func _coerce_result_node(result) -> GnosisNode:
	if result is GnosisFunctionResult:
		return result.payload if result.is_ok else null
	if result is GnosisNode:
		return result
	return null


func _coerce_consumable_consume_result(result) -> bool:
	var node := _coerce_result_node(result)
	if node == null or not node.is_valid():
		return false
	if node.get_type() == GnosisValueType.OBJECT and node.get_node("applied").is_valid():
		return _node_bool(node, "applied", false)
	return true


## Unity NotifyHudSnapshotChanged / FACT_GNOSIS_STATE_COMMITTED parity for money.
func _commit_currency_snapshot() -> void:
	if context == null or context.engine == null:
		return
	var changed_paths: Array[String] = ["Ephemeral.currencies"]
	context.engine.commit("match3", changed_paths)


func is_run_won() -> bool:
	var m3 := get_node("match3", false)
	return m3.is_valid() and _node_bool(m3, "isRunWon", false)


func is_run_complete() -> bool:
	var m3 := get_node("match3", false)
	return m3.is_valid() and _node_bool(m3, "isRunComplete", false)


## Last resolved move scoring (points x multi lane on the HUD).
func get_step_points() -> int:
	return _last_step_points


func get_step_multi() -> int:
	return _last_step_multi


func get_match3_animation_seconds(key: String, fallback: float = 0.0) -> float:
	return get_match3_scaled_animation_seconds(key, fallback, 0.0)


func get_match3_scaled_animation_seconds(
	key: String,
	fallback: float = 0.0,
	min_seconds: float = 0.0,
) -> float:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return Match3GameSpeedScript.scale_duration(_engine_for_speed(), fallback, min_seconds)
	_ensure_match3_animation_defaults(m3)
	var animation := m3.get_node("animation")
	if not animation.is_valid():
		return Match3GameSpeedScript.scale_duration(_engine_for_speed(), fallback, min_seconds)
	var node := animation.get_node(key.strip_edges())
	var base := fallback
	if node.is_valid() and node.value != null:
		base = maxf(0.0, float(node.value))
	return Match3GameSpeedScript.scale_duration(_engine_for_speed(), base, min_seconds)


func _engine_for_speed() -> GnosisEngine:
	if context != null and context.engine != null:
		return context.engine
	return null


## Points x multi product for the most recently resolved move.
func on_boon_activated(boon_catalog_id: String) -> void:
	if _match3_effects == null:
		return
	_match3_effects.try_juice_boon_on_activate(boon_catalog_id)
	_match3_effects.sync_equipped_boon_round_effects()
	_publish_ephemeral_state()


func sync_equipped_boon_match3_round_effects() -> void:
	if _match3_effects == null:
		return
	_match3_effects.sync_equipped_boon_round_effects()
	_publish_ephemeral_state()


func get_match3_effects_active_count() -> int:
	if _match3_effects == null:
		return 0
	return _match3_effects.active_effect_count()


func get_last_move_score() -> int:
	return _last_move_score


func get_statistic_int(path: String, fallback: int = 0) -> int:
	if context == null or context.engine == null:
		return fallback
	var key := path.strip_edges()
	if key.is_empty():
		return fallback
	var statistic = context.engine.get_service("Statistic")
	if statistic != null and statistic.has_method("get_value"):
		var event_data = statistic.get_value(false, key)
		if event_data != null and event_data.is_valid():
			var value_node: GnosisNode = event_data.get_node("value")
			if value_node.is_valid() and value_node.value != null:
				return int(value_node.value)
	_ensure_statistics_root()
	var stats := get_node("statistics", false)
	if not stats.is_valid():
		return fallback
	var node := stats.get_node(key)
	if node.is_valid() and node.value != null:
		return int(node.value)
	return fallback


## Resolves the display metadata for the current round's level/boss profile from
## the `levels` catalog (name, description, token letter, accent colors, reward).
func get_active_level_meta() -> Dictionary:
	var result := {
		"id": _active_level_id,
		"nameKey": "",
		"descriptionKey": "",
		"startingLetter": "",
		"backgroundColor": "",
		"textColor": "",
		"rewardAmount": 0,
		"isBoss": _active_stage_type == "boss",
	}
	var config := get_node("configuration", true)
	if not config.is_valid():
		return result
	var levels := config.get_node("levels")
	if not levels.is_valid():
		return result
	var entry := levels.get_node(_active_level_id)
	if not entry.is_valid():
		return result
	var meta := entry.get_node("metadata")
	var props := entry.get_node("properties")
	result["nameKey"] = _node_str(meta, "nameKey")
	result["descriptionKey"] = _node_str(meta, "descriptionKey")
	result["startingLetter"] = _node_str(meta, "startingLetter")
	result["backgroundColor"] = _node_str(meta, "backgroundColor")
	result["textColor"] = _node_str(meta, "textColor")
	result["rewardAmount"] = _node_int(props, "rewardAmount", 0)
	return result


func is_board_input_allowed() -> bool:
	return _gameplay.status == Models.STATUS_PLAYING


func handle_run_started() -> void:
	_floor_bundle_plans.clear()
	_ensure_run_ephemeral_defaults()
	var m3 := get_node("match3", false)
	var next_level := maxi(1, _node_int(m3, "nextLevel", 1))
	_prepare_queued_round_preview(next_level)
	_gameplay.status = Models.STATUS_LEVEL_SELECT_PANEL
	refresh_planned_floor_preview()
	_publish_ephemeral_state()
	_publish_status_changed()


func _on_begin_level_requested(event: GnosisEvent) -> void:
	var level := 1
	if event != null and event.data.is_valid():
		level = maxi(1, _node_int(event.data, Events.PAYLOAD_LEVEL_NUMBER, 1))
	_begin_level(level)


func _on_reset_requested(_event: GnosisEvent) -> void:
	_begin_level(_current_round)


func _on_move_requested(event: GnosisEvent) -> void:
	if not is_board_input_allowed() or context == null:
		return
	var x1 := -1
	var y1 := -1
	var x2 := -1
	var y2 := -1
	if event != null and event.data.is_valid():
		x1 = _node_int(event.data, "x1", -1)
		y1 = _node_int(event.data, "y1", -1)
		x2 = _node_int(event.data, "x2", -1)
		y2 = _node_int(event.data, "y2", -1)
	if x1 < 0 or y1 < 0 or x2 < 0 or y2 < 0:
		return
	var a = Models.TileCoord.new(x1, y1)
	var b = Models.TileCoord.new(x2, y2)
	if _boon_runtime != null and _boon_runtime.has_method("begin_move_hooks"):
		_boon_runtime.begin_move_hooks()
	var results := _gameplay.process_move(a, b, _item_points)
	if not results.is_empty():
		_apply_post_move_boon_hooks()
		results = _apply_post_move_boss_effects(results)
	_publish_ephemeral_state()
	var success := not results.is_empty()
	if success:
		_record_move_statistics(results)
		var last = results[results.size() - 1]
		_last_step_points = last.move_points_so_far
		_last_step_multi = last.move_multi_so_far
		_last_move_score = last.final_score_for_move
	# The board view animates the swap + cascade from this step sequence, so we no
	# longer snap the final board instantly. Published before any win/loss status
	# change so the view marks itself busy and the adapter defers the result panel.
	_publish_move_resolved(a, b, success, results)
	if _gameplay.status == Models.STATUS_WIN:
		_handle_round_won()
	elif _gameplay.status == Models.STATUS_LOSS:
		_record_round_end_unused_budget_statistics()
		_apply_round_end_floor_boon_hooks()
		_update_run_completion_state(false)
		_gameplay.status = Models.STATUS_LOSE_PANEL
		_publish_ephemeral_state()
		_publish_status_changed()
	elif _gameplay.status != Models.STATUS_PLAYING:
		_publish_status_changed()


func _begin_level(level_number: int) -> void:
	_finalize_pending_round_rewards_silent()
	var previous_round := _current_round
	var target_round := maxi(1, level_number)
	if previous_round >= 1 and previous_round != target_round:
		_apply_boss_round_end_for_completed_round(previous_round)
	_apply_round_setup(target_round)
	_publish_round_changed_fact_if_needed(previous_round)
	if _boon_runtime != null:
		_boon_runtime.on_round_boundary(previous_round, _current_round)
	if _match3_effects != null:
		_match3_effects.tick_round_lifetimes()
		var skip_boss_start := SupportScript.is_boon_catalog_id_equipped(self, BOON_CATALOG_ID_BACKSTABBER)
		_match3_effects.apply_boss_round_start_for_profile(_active_level_id, skip_boss_start)
	var setup := _resolve_round_setup(_current_round)
	var layout = _load_board_layout(_active_board_id)
	if layout == null:
		layout = Match3BoardLayoutScript.new()
		layout.id = "fallback"
		layout.width = 8
		layout.height = 8
	var base_moves := int(setup.get("moves", BASE_MOVES_LIMIT))
	var base_shuffles := int(setup.get("shuffles", DEFAULT_SHUFFLES_PER_ROUND))
	var budget := {"moves": base_moves, "shuffles": base_shuffles}
	if _match3_effects != null:
		budget = _match3_effects.apply_round_budget(base_moves, base_shuffles)
		_match3_effects.sync_equipped_boon_round_effects()
		budget = _match3_effects.apply_round_budget(base_moves, base_shuffles)
	if SupportScript.is_boon_catalog_id_equipped(self, BOON_CATALOG_ID_SIMP):
		budget["moves"] = maxi(1, int(budget.get("moves", base_moves)) + 5)
		budget["shuffles"] = 0
	var pending_moves := _read_pending_round_moves_add()
	if pending_moves > 0:
		budget["moves"] = maxi(1, int(budget.get("moves", base_moves)) + pending_moves)
		_clear_pending_round_moves_add()
	_manual_shuffles_remaining = int(budget.get("shuffles", base_shuffles))
	_gameplay.load_level(
		layout,
		int(setup.get("target_score", BASE_SCORE_TO_WIN)),
		int(budget.get("moves", base_moves)),
		int(setup.get("color_limit", BASE_COLOR_LIMIT)),
		_item_points
	)
	_apply_floor_modifier_pool_to_board()
	_sync_gameplay_effect_flags()
	_publish_ephemeral_state()
	_publish_board_reset()


func _apply_boss_round_end_for_completed_round(completed_round: int) -> void:
	if _match3_effects == null or completed_round < 1:
		return
	var setup := _resolve_round_setup(completed_round)
	var profile_id := str(setup.get("level_id", ""))
	_match3_effects.apply_boss_round_end_for_profile(profile_id)


func _sync_gameplay_effect_flags() -> void:
	if _match3_effects == null:
		return
	_match3_effects.rebuild_derived_state()
	_gameplay.configure_scoring_effects(
		_match3_effects.restrict_score_to_exact_three_line_matches,
		_match3_effects.restrict_score_to_exact_four_or_five_line_matches,
		_match3_effects.tile_points_contribution_scale,
		_match3_effects.tile_multi_contribution_scale,
		_match3_effects.reduce_first_destroyed_item_level_each_move
	)
	_sync_spawn_disabled_rules_to_board()


func _sync_spawn_disabled_rules_to_board() -> void:
	if _match3_effects == null:
		return
	_match3_effects.sync_spawn_disabled_rules_to_board(_gameplay, _item_points)


func _resolve_spawn_item_type_id_for_block(item_id: String, fallback_item_type_id: String) -> String:
	if _match3_effects == null:
		return fallback_item_type_id if not fallback_item_type_id.is_empty() else "plain"
	return _match3_effects.resolve_spawn_item_type_id_for_block(
		item_id,
		fallback_item_type_id,
		_gameplay.get_spawn_rng() if _gameplay != null else null
	)


func _apply_post_move_boon_hooks() -> void:
	if _boon_runtime != null and _boon_runtime.has_method("apply_move_end_hooks"):
		_boon_runtime.apply_move_end_hooks()


func _apply_post_move_boss_effects(results: Array) -> Array:
	if results.is_empty() or _match3_effects == null:
		return results
	if _match3_effects.reduce_first_destroyed_item_level_each_move:
		var item_id := _gameplay.consume_first_scoring_destroyed_item_id()
		if not item_id.is_empty():
			_decrement_item_level_min_one(item_id)
	if _match3_effects.shuffle_board_after_each_move:
		var last: Models.MatchResult = results[results.size() - 1]
		var shuffle_result := _gameplay.shuffle_board(_item_points)
		if not shuffle_result.new_spawns.is_empty():
			shuffle_result.points_added = last.points_added
			shuffle_result.multi_added = last.multi_added
			shuffle_result.move_points_so_far = last.move_points_so_far
			shuffle_result.move_multi_so_far = last.move_multi_so_far
			shuffle_result.final_score_for_move = last.final_score_for_move
			results.append(shuffle_result)
	return results


func _apply_match3_effect(parameters: GnosisNode) -> GnosisFunctionResult:
	if _match3_effects == null or context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var result: Dictionary = _match3_effects.invoke_apply_effect(parameters)
	if not bool(result.get("ok", false)):
		return GnosisFunctionResult.fail(str(result.get("error", "ApplyEffect failed.")))
	_sync_gameplay_effect_flags()
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("effectId", str(result.get("effectId", "")))
	payload.set_key("alreadyActive", bool(result.get("alreadyActive", false)))
	payload.set_key("roundsRemaining", int(result.get("roundsRemaining", -1)))
	payload.set_key("activeCount", int(result.get("activeCount", 0)))
	return GnosisFunctionResult.ok(payload)


func _remove_match3_effect(parameters: GnosisNode) -> GnosisFunctionResult:
	if _match3_effects == null or context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var result: Dictionary = _match3_effects.invoke_remove_effect(parameters)
	if not bool(result.get("ok", false)):
		return GnosisFunctionResult.fail(str(result.get("error", "RemoveEffect failed.")))
	_sync_gameplay_effect_flags()
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("effectId", str(result.get("effectId", "")))
	payload.set_key("removed", bool(result.get("removed", false)))
	payload.set_key("activeCount", int(result.get("activeCount", 0)))
	return GnosisFunctionResult.ok(payload)


func _decrement_item_level_min_one(item_id: String) -> void:
	if context == null or context.store == null:
		return
	var trimmed := item_id.strip_edges()
	if trimmed.is_empty():
		return
	var previous := _resolve_item_level(trimmed)
	var next := maxi(1, previous - 1)
	if next >= previous:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return
	var item_levels := m3.get_node("itemLevels")
	if not item_levels.is_valid() or item_levels.get_type() != GnosisValueType.OBJECT:
		item_levels = context.store.create_object()
		m3.set_key("itemLevels", item_levels)
	item_levels.set_key(trimmed, next)
	_publish_ephemeral_state()


func _grant_random_run_upgrade(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var category_id := _node_str(parameters, "categoryId", "run").strip_edges()
	if category_id.is_empty():
		category_id = "run"
	var pool := _build_eligible_run_upgrade_ids(category_id)
	var payload := context.store.create_object()
	if pool.is_empty():
		payload.set_key("success", true)
		payload.set_key("granted", false)
		payload.set_key("reason", "no_eligible_run_upgrade")
		payload.set_key("upgradeId", "")
		return GnosisFunctionResult.ok(payload)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:run_upgrade:%s" % [_try_get_run_seed(), category_id])
	var upgrade_id := pool[rng.randi_range(0, pool.size() - 1)]
	if upgrade_id.strip_edges().is_empty():
		payload.set_key("success", true)
		payload.set_key("granted", false)
		payload.set_key("reason", "no_eligible_run_upgrade")
		payload.set_key("upgradeId", "")
		return GnosisFunctionResult.ok(payload)
	var add_params := context.store.create_object()
	add_params.set_key("categoryId", category_id)
	add_params.set_key("upgradeId", upgrade_id.strip_edges())
	var add_result = call_service("Upgrade", "AddUpgrade", add_params)
	if add_result == null or not (add_result is GnosisFunctionResult) or not add_result.is_ok:
		return GnosisFunctionResult.fail(add_result.error if add_result is GnosisFunctionResult else "add_upgrade_failed")
	_publish_ephemeral_state()
	payload.set_key("success", true)
	payload.set_key("granted", true)
	payload.set_key("upgradeId", upgrade_id.strip_edges())
	payload.set_key("categoryId", category_id)
	return GnosisFunctionResult.ok(payload)


func _build_eligible_run_upgrade_ids(category_id: String) -> Array[String]:
	var out: Array[String] = []
	var catalog := _build_run_upgrade_catalog_ids()
	if catalog.is_empty():
		return out
	var args := context.store.create_object()
	args.set_key("categoryId", category_id)
	var result = call_service("Upgrade", "GetEligibleUpgradeIds", args)
	if result == null or not (result is GnosisFunctionResult) or not result.is_ok:
		return catalog
	var fn_result: GnosisFunctionResult = result
	var data: GnosisNode = fn_result.payload
	if data == null or not data.is_valid() or data.get_type() != GnosisValueType.OBJECT:
		return catalog
	var list_node: GnosisNode = data.get_node("upgradeIds")
	if not list_node.is_valid() or list_node.get_type() != GnosisValueType.LIST:
		return catalog
	var eligible: Dictionary = {}
	for i in range(list_node.get_count()):
		var entry: GnosisNode = list_node.get_node(i)
		var upgrade_id := ""
		if entry.is_valid() and entry.get_type() == GnosisValueType.STRING:
			upgrade_id = str(entry.value).strip_edges()
		else:
			upgrade_id = _node_str(entry, "upgradeId").strip_edges()
		if not upgrade_id.is_empty():
			eligible[upgrade_id.to_lower()] = true
	for id in catalog:
		if eligible.has(id.to_lower()):
			out.append(id)
	return out


func _build_run_upgrade_catalog_ids() -> Array[String]:
	var out: Array[String] = []
	var config := get_node("configuration", true)
	if not config.is_valid():
		return out
	var upgrades := config.get_node("runUpgrades")
	if not upgrades.is_valid() or upgrades.get_type() != GnosisValueType.OBJECT:
		return out
	for key in upgrades.get_keys():
		var id := str(key).strip_edges()
		if not id.is_empty():
			out.append(id)
	out.sort()
	return out


func _add_round_moves_bonus(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var delta := _node_int(parameters, "delta", 3)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddRoundMovesBonus requires positive 'delta'.")
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3_unavailable")
	var apply_now: bool = _gameplay.status == Models.STATUS_PLAYING
	var previous_pending := _read_pending_round_moves_add()
	var previous_current := maxi(0, _gameplay.current_moves)
	if apply_now:
		_gameplay.current_moves = maxi(0, _gameplay.current_moves + delta)
		m3.set_key("currentMoves", _gameplay.current_moves)
	else:
		m3.set_key("pendingRoundMovesAdd", previous_pending + delta)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("delta", delta)
	payload.set_key("appliedToCurrentRound", apply_now)
	payload.set_key("currentMoves", _gameplay.current_moves if apply_now else previous_current)
	payload.set_key(
		"pendingRoundMovesAdd",
		previous_pending if apply_now else _read_pending_round_moves_add()
	)
	return GnosisFunctionResult.ok(payload)


func _grant_currency_from_statistic_counter(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var statistic_path := _node_str(parameters, "statisticPath").strip_edges()
	if statistic_path.is_empty():
		return GnosisFunctionResult.fail("statistic_path_required")
	var currency_id := _node_str(parameters, "currencyId", "money").strip_edges()
	if currency_id.is_empty():
		currency_id = "money"
	var amount_per_unit := maxi(0, _node_int(parameters, "amountPerUnit", 1))
	var counter := maxi(0, get_statistic_int(statistic_path, 0))
	var amount := amount_per_unit * counter
	var payload := context.store.create_object()
	if amount <= 0:
		payload.set_key("success", true)
		payload.set_key("grantedAmount", 0)
		payload.set_key("statisticPath", statistic_path)
		payload.set_key("counter", counter)
		return GnosisFunctionResult.ok(payload)
	var args := context.store.create_object()
	args.set_key("currencyId", currency_id)
	args.set_key("amount", amount)
	var add_result = call_service("Currency", "AddCurrency", args)
	if add_result == null or not (add_result is GnosisFunctionResult) or not add_result.is_ok:
		return GnosisFunctionResult.fail(add_result.error if add_result is GnosisFunctionResult else "add_currency_failed")
	payload.set_key("success", true)
	payload.set_key("grantedAmount", amount)
	payload.set_key("statisticPath", statistic_path)
	payload.set_key("counter", counter)
	payload.set_key("amountPerUnit", amount_per_unit)
	payload.set_key("currencyId", currency_id)
	return GnosisFunctionResult.ok(payload)


func _match3_shop_core() -> GnosisNode:
	var shop := get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		return GnosisNode.new(null, null)
	return shop.get_node("core")


func _add_core_shop_free_reroll_count_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _node_int(parameters, "delta", 1)
	if delta == 0:
		return GnosisFunctionResult.fail("AddCoreShopFreeRerollCountDelta requires non-zero 'delta'.")
	var core := _match3_shop_core()
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("AddCoreShopFreeRerollCountDelta requires Ephemeral.match3Shop.core object.")
	var previous := maxi(0, _node_int(core, "freeRerollCount", 0))
	var next := maxi(0, previous + delta)
	core.set_key("freeRerollCount", next)
	core.set_key("nextRerollIsFree", next > 0)
	if next > 0:
		core.set_key("currentRerollPrice", 0)
	elif core.get_node("paidRerollPrice").is_valid():
		core.set_key("currentRerollPrice", int(core.get_node("paidRerollPrice").value))
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousFreeRerollCount", previous)
	payload.set_key("freeRerollCount", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _add_core_shop_reroll_flat_discount_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _node_int(parameters, "delta", 2)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddCoreShopRerollFlatDiscountDelta requires positive 'delta'.")
	var core := _match3_shop_core()
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("AddCoreShopRerollFlatDiscountDelta requires Ephemeral.match3Shop.core object.")
	var previous := maxi(0, _node_int(core, "rerollFlatDiscount", 0))
	var next := previous + delta
	core.set_key("rerollFlatDiscount", next)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousRerollFlatDiscount", previous)
	payload.set_key("rerollFlatDiscount", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _add_core_shop_slots_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _node_int(parameters, "delta", 2)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddCoreShopSlotsDelta requires positive 'delta'.")
	var core := _match3_shop_core()
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("AddCoreShopSlotsDelta requires Ephemeral.match3Shop.core object.")
	const DEFAULT_CORE_SLOTS := 6
	var previous := maxi(0, _node_int(core, "slots", DEFAULT_CORE_SLOTS))
	var next := previous + delta
	core.set_key("slots", next)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousCoreShopSlots", previous)
	payload.set_key("coreShopSlots", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _add_shop_discount_percent_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _read_node_float(parameters, "delta", 0.0)
	if delta <= 0.0:
		return GnosisFunctionResult.fail("AddShopDiscountPercentDelta requires positive 'delta'.")
	var shop := get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3Shop_missing")
	var previous := clampf(_read_node_float(shop, "shopDiscountPercent", 0.0), 0.0, 0.5)
	var next := clampf(previous + delta, 0.0, 0.5)
	shop.set_key("shopDiscountPercent", next)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousShopDiscountPercent", previous)
	payload.set_key("shopDiscountPercent", next)
	payload.set_key("delta", delta)
	payload.set_key("maxShopDiscountPercent", 0.5)
	return GnosisFunctionResult.ok(payload)


func _add_default_moves_per_round_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _node_int(parameters, "delta", 0)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddDefaultMovesPerRoundDelta requires positive 'delta'.")
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3_missing")
	var previous := maxi(1, _node_int(m3, "defaultMovesPerRound", BASE_MOVES_LIMIT))
	var next := maxi(1, previous + delta)
	m3.set_key("defaultMovesPerRound", next)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousDefaultMovesPerRound", previous)
	payload.set_key("defaultMovesPerRound", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _add_default_shuffles_per_round_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta := _node_int(parameters, "delta", 0)
	if delta <= 0:
		return GnosisFunctionResult.fail("AddDefaultShufflesPerRoundDelta requires positive 'delta'.")
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return GnosisFunctionResult.fail("match3_missing")
	var previous := maxi(0, _node_int(m3, "defaultShufflesPerRound", DEFAULT_SHUFFLES_PER_ROUND))
	var next := maxi(0, previous + delta)
	m3.set_key("defaultShufflesPerRound", next)
	_publish_ephemeral_state()
	var payload := context.store.create_object()
	payload.set_key("previousDefaultShufflesPerRound", previous)
	payload.set_key("defaultShufflesPerRound", next)
	payload.set_key("delta", delta)
	return GnosisFunctionResult.ok(payload)


func _duplicate_last_rune_or_item_upgrade_grant_consumable(parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var bucket_id := _node_str(parameters, "bucketId", "default").strip_edges()
	if bucket_id.is_empty():
		bucket_id = "default"
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return GnosisFunctionResult.fail("match3_unavailable")
	var target := _node_str(m3, "echoLastRuneOrItemUpgradeGrantConsumableId").strip_edges()
	if target.is_empty():
		return GnosisFunctionResult.fail("no_echo_target")
	var args := context.store.create_object()
	args.set_key("bucketId", bucket_id)
	args.set_key("consumableId", target)
	var result = call_service("Consumable", "AddConsumable", args)
	if result == null or not (result is GnosisNode) or not result.is_valid():
		return GnosisFunctionResult.fail("add_consumable_failed")
	return GnosisFunctionResult.ok(result)


func _apply_shop_reroll_scaling_after_core_shop_reroll(_parameters: GnosisNode) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var bumped := _increment_clickbait_shop_reroll_counter_if_equipped()
	var payload := context.store.create_object()
	payload.set_key("delta", bumped)
	payload.set_key("incremented", bumped > 0)
	_publish_ephemeral_state()
	return GnosisFunctionResult.ok(payload)


func _increment_clickbait_shop_reroll_counter_if_equipped() -> int:
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(self)
	var bumped := 0
	for i in range(slot_rows.size()):
		var slot_entry: GnosisNode = slot_rows[i]
		var catalog_id := SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry).strip_edges()
		if catalog_id.to_lower() != CLICKBAIT_BOON_CATALOG_ID.to_lower():
			continue
		if Match3BoonScalingScript.try_bank_boon_slot_scaling_counter(
			self, i, slot_entry, SHOP_REROLL_LIFETIME_COUNTER_KEY, 1, true
		):
			bumped += 1
	return bumped


func _reroll_upcoming_boss_round() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return GnosisFunctionResult.fail("match3_unavailable")
	var anchor_round := maxi(1, _node_int(m3, "nextLevel", 1))
	var boss_lookup := _try_find_next_unplayed_boss_round(anchor_round)
	if not bool(boss_lookup.get("found", false)):
		return GnosisFunctionResult.fail("no_upcoming_boss_round")
	var boss_round := int(boss_lookup.get("boss_round", 0))
	var floor_number := int(boss_lookup.get("floor_number", 0))
	var bundle: Dictionary = boss_lookup.get("bundle", {})
	var boss_plan: Dictionary = bundle.get("boss", {})
	if _gameplay.status == Models.STATUS_PLAYING and _current_round == boss_round:
		if str(boss_plan.get("stage_type", "")) == "boss":
			return GnosisFunctionResult.fail("boss_round_in_progress")
	var previous_profile_id := str(boss_plan.get("level_id", ""))
	var new_profile_id := _try_pick_alternate_boss_profile_id_for_round(boss_round, previous_profile_id)
	if new_profile_id.is_empty():
		return GnosisFunctionResult.fail("no_alternate_boss")
	_load_board_pools()
	var used_board_ids: Array[String] = []
	var normal_plan: Dictionary = bundle.get("normal", {})
	var advanced_plan: Dictionary = bundle.get("advanced", {})
	var normal_board := str(normal_plan.get("board_id", "")).strip_edges()
	var advanced_board := str(advanced_plan.get("board_id", "")).strip_edges()
	if not normal_board.is_empty():
		used_board_ids.append(normal_board)
	if not advanced_board.is_empty():
		used_board_ids.append(advanced_board)
	var all_board_ids := _get_all_board_ids()
	var new_board_id := _pick_boss_board_for_profile(new_profile_id, floor_number, used_board_ids, all_board_ids)
	if new_board_id.is_empty():
		return GnosisFunctionResult.fail("boss_board_pick_failed")
	var new_boss := (boss_plan as Dictionary).duplicate(true)
	new_boss["level_id"] = new_profile_id
	new_boss["board_id"] = new_board_id
	bundle["boss"] = new_boss
	_floor_bundle_plans[floor_number] = bundle
	refresh_planned_floor_preview()
	_publish_ephemeral_state()
	var ok := context.store.create_object()
	ok.set_key("success", true)
	ok.set_key("floorNumber", floor_number)
	ok.set_key("bossRound", boss_round)
	ok.set_key("previousBossProfileId", previous_profile_id)
	ok.set_key("bossProfileId", new_profile_id)
	ok.set_key("boardId", new_board_id)
	return GnosisFunctionResult.ok(ok)


func _try_find_next_unplayed_boss_round(anchor_round: int) -> Dictionary:
	var anchor := maxi(1, anchor_round)
	var m3 := get_node("match3", false)
	var rounds_per_floor := DEFAULT_ROUNDS_PER_FLOOR
	var start_floor := int((anchor - 1) / rounds_per_floor) + 1
	var endless_enabled := _node_bool(m3, "endlessModeEnabled", false)
	var floor_count := maxi(1, _node_int(m3, "floorCount", 8))
	var end_floor := start_floor + maxi(8, floor_count) if endless_enabled else floor_count
	end_floor = maxi(end_floor, start_floor)
	for floor in range(start_floor, end_floor + 1):
		var bundle := _ensure_floor_bundle(floor)
		var boss_plan: Dictionary = bundle.get("boss", {})
		var boss_round := int(boss_plan.get("round", 0))
		if boss_round < anchor:
			continue
		return {
			"found": true,
			"boss_round": boss_round,
			"floor_number": floor,
			"bundle": bundle,
		}
	return {"found": false}


func _try_pick_alternate_boss_profile_id_for_round(boss_round_number: int, exclude_profile_id: String) -> String:
	var tier_pool := _filter_boss_profiles_to_peak_tier(_build_eligible_boss_profile_ids(boss_round_number))
	var exclude := exclude_profile_id.strip_edges()
	var pool: Array[String] = []
	for id in tier_pool:
		if not id.is_empty() and id.to_lower() != exclude.to_lower():
			pool.append(id)
	if pool.is_empty():
		for id in _build_eligible_boss_profile_ids(boss_round_number):
			if not id.is_empty() and id.to_lower() != exclude.to_lower():
				pool.append(id)
	if pool.is_empty():
		pool = tier_pool.duplicate()
	if pool.is_empty():
		return ""
	if pool.size() == 1 and pool[0].to_lower() == exclude.to_lower():
		return ""
	var index := _seed_range_int(0, pool.size(), 0)
	return pool[clampi(index, 0, pool.size() - 1)]


func _seed_range_int(min_inclusive: int, max_exclusive: int, fallback: int) -> int:
	if max_exclusive <= min_inclusive or context == null or context.store == null:
		return fallback
	var args := context.store.create_object()
	args.set_key("min", min_inclusive)
	args.set_key("max", max_exclusive)
	var result = call_service("Seed", "RangeInt", args)
	if result is GnosisFunctionResult and result.is_ok and result.payload != null and result.payload.is_valid():
		return _node_int(result.payload, "value", fallback)
	if result is GnosisNode and result.is_valid():
		var value: GnosisNode = result.get_node("value")
		if value.is_valid():
			return int(value.value)
	return fallback


func _on_consumable_used_for_echo_tracking(event: GnosisEvent) -> void:
	if context == null or context.store == null or event == null:
		return
	var data := event.data if event.data != null else GnosisNode.new(null)
	if not data.is_valid() or data.get_type() != GnosisValueType.OBJECT:
		return
	var catalog_id := _resolve_consumable_catalog_id_from_used_fact(data).strip_edges()
	if catalog_id.is_empty():
		return
	if catalog_id.to_lower() == ECHOMANIA_CONSUMABLE_CATALOG_ID.to_lower():
		return
	if not _is_echo_tracked_consumable_catalog_id(catalog_id):
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return
	m3.set_key(ECHO_LAST_RUNE_OR_GRANT_CONSUMABLE_KEY, catalog_id)
	_publish_ephemeral_state()


func _resolve_consumable_catalog_id_from_used_fact(data: GnosisNode) -> String:
	for key in ["consumableId", "catalogConsumableId", "consumableCatalogId", "itemId"]:
		var direct := _node_str(data, key).strip_edges()
		if not direct.is_empty():
			return direct
	for nested_key in ["data", "payload"]:
		var nested := data.get_node(nested_key)
		if not nested.is_valid() or nested.get_type() != GnosisValueType.OBJECT:
			continue
		for key in ["consumableId", "catalogConsumableId"]:
			var inner := _node_str(nested, key).strip_edges()
			if not inner.is_empty():
				return inner
	return ""


func _is_echo_tracked_consumable_catalog_id(catalog_id: String) -> bool:
	if catalog_id.is_empty():
		return false
	var configuration := get_node("configuration", true)
	if not configuration.is_valid() or configuration.get_type() != GnosisValueType.OBJECT:
		return false
	var consumables_root := configuration.get_node(CONSUMABLES_CONFIGURATION_ID)
	if not consumables_root.is_valid() or consumables_root.get_type() != GnosisValueType.OBJECT:
		return false
	var entry := consumables_root.get_node(catalog_id.strip_edges())
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return false
	var properties := entry.get_node("properties")
	if not properties.is_valid() or properties.get_type() != GnosisValueType.OBJECT:
		return false
	var tags_node := properties.get_node("gameplayTags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		tags_node = properties.get_node("gameplyTags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return false
	var has_mania := false
	var has_grant := false
	for i in range(tags_node.get_count()):
		var tag := str(_node_value(tags_node.get_node(i))).strip_edges()
		if tag.to_lower() == MANIA_GAMEPLAY_TAG:
			has_mania = true
		if tag.to_lower() == ITEM_UPGRADE_GRANT_GAMEPLAY_TAG:
			has_grant = true
	return has_mania or has_grant


func _apply_floor_modifier_pool_to_board() -> void:
	if not _is_board_grid_ready():
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return
	_ensure_floor_modifier_pool_published(m3)
	var pool := m3.get_node(Match3FloorModifierPoolScript.POOL_KEY)
	if not pool.is_valid():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:floor_layout" % [_try_get_run_seed(), _current_round])
	Match3FloorModifierPoolScript.apply_layout_to_gameplay(_gameplay, pool, rng)
	_notify_enhanced_floors_on_board(true)
	sync_floor_modifier_tile_statistics_from_grid()


## Fills HUD / ephemeral metadata for the queued round without loading the board.
## Used at run start so the level-select subscreen is shown first (Unity parity).
func _prepare_queued_round_preview(level_number: int) -> void:
	_apply_round_setup(maxi(1, level_number))
	_gameplay.current_score = 0
	_last_step_points = 0
	_last_step_multi = 0
	_last_move_score = 0


func _publish_round_changed_fact_if_needed(previous_round: int) -> void:
	if previous_round == _current_round:
		return
	if context == null or context.store == null:
		return
	var payload := context.store.create_object()
	payload.set_key("previousRound", maxi(0, previous_round))
	payload.set_key("currentRound", maxi(1, _current_round))
	payload.set_key("currentFloor", maxi(1, _current_floor))
	payload.set_key("roundInFloor", maxi(1, _round_in_floor))
	_publish_fact(Events.FACT_MATCH3_ROUND_CHANGED, payload)


func _apply_round_setup(level_number: int) -> void:
	_current_round = maxi(1, level_number)
	var seed_svc = context.engine.get_service("Seed") if context and context.engine else null
	if seed_svc and seed_svc.has_method("get_run_seed"):
		var run_seed := int(seed_svc.get_run_seed())
		_gameplay.configure_rng(run_seed)
		if _boon_runtime != null and _boon_runtime.has_method("configure_rng"):
			_boon_runtime.configure_rng(run_seed)
	var setup := _resolve_round_setup(_current_round)
	var layout = _load_board_layout(str(setup.get("board_id", DEFAULT_BOARD_ID)))
	if layout == null:
		push_warning("Match3Service: board '%s' missing; using empty 8x8." % DEFAULT_BOARD_ID)
		layout = Match3BoardLayoutScript.new()
		layout.id = "fallback"
		layout.width = 8
		layout.height = 8
	_active_board_id = str(setup.get("board_id", layout.id))
	_active_level_id = str(setup.get("level_id", "normal"))
	_current_floor = int(setup.get("floor", 1))
	_round_in_floor = int(setup.get("round_in_floor", 1))
	_active_stage_type = str(setup.get("stage_type", "normal"))
	_manual_shuffles_remaining = int(setup.get("shuffles", DEFAULT_SHUFFLES_PER_ROUND))
	_gameplay.target_score = int(setup.get("target_score", BASE_SCORE_TO_WIN))
	_gameplay.current_moves = int(setup.get("moves", BASE_MOVES_LIMIT))
	_gameplay.width = maxi(1, layout.width)
	_gameplay.height = maxi(1, layout.height)
	_gameplay.grid.clear()
	_reset_heartbeat_hint_for_new_round()


func _load_board_layout(board_id: String):
	var config := get_node("configuration", true)
	if not config.is_valid():
		return null
	var boards := config.get_node("match3Boards")
	if not boards.is_valid():
		return null
	var entry := boards.get_node(board_id)
	if not entry.is_valid():
		return null
	var data: Variant = entry.value
	if data is Dictionary:
		var layout = Match3BoardLayoutScript.from_json(data)
		if layout.id.is_empty():
			layout.id = board_id
		return layout
	return null


func _resolve_round_setup(round_number: int) -> Dictionary:
	_load_board_pools()
	var round := maxi(1, round_number)
	var rounds_per_floor := DEFAULT_ROUNDS_PER_FLOOR
	var floor := int((round - 1) / rounds_per_floor) + 1
	var round_in_floor := int((round - 1) % rounds_per_floor) + 1
	var bundle := _ensure_floor_bundle(floor)
	match round_in_floor:
		2:
			return (bundle.get("advanced", {}) as Dictionary).duplicate(true)
		DEFAULT_ROUNDS_PER_FLOOR:
			return (bundle.get("boss", {}) as Dictionary).duplicate(true)
		_:
			return (bundle.get("normal", {}) as Dictionary).duplicate(true)


func _ensure_floor_bundle(floor: int) -> Dictionary:
	var safe_floor := maxi(1, floor)
	if _floor_bundle_plans.has(safe_floor):
		return _floor_bundle_plans[safe_floor]
	_ensure_boss_profiles_loaded()
	_load_board_pools()
	var all_board_ids := _get_all_board_ids()
	var used_ids: Array[String] = []
	var first_round := (safe_floor - 1) * DEFAULT_ROUNDS_PER_FLOOR + 1
	var boss_round_number := first_round + DEFAULT_ROUNDS_PER_FLOOR - 1
	var normal_board := _pick_board_id_for_stage("normal", safe_floor, used_ids, all_board_ids)
	var advanced_board := _pick_board_id_for_stage("advanced", safe_floor, used_ids, all_board_ids)
	var boss_profile_id := _pick_boss_profile_id_for_round(safe_floor, boss_round_number)
	var boss_board := _pick_boss_board_for_profile(boss_profile_id, safe_floor, used_ids, all_board_ids)
	var bundle := {
		"normal": _build_stage_plan(
			first_round, safe_floor, 1, "normal", normal_board,
			_pick_profile_id_for_stage("normal", safe_floor)
		),
		"advanced": _build_stage_plan(
			first_round + 1, safe_floor, 2, "advanced", advanced_board,
			_pick_profile_id_for_stage("advanced", safe_floor)
		),
		"boss": _build_stage_plan(
			boss_round_number, safe_floor, DEFAULT_ROUNDS_PER_FLOOR, "boss", boss_board,
			boss_profile_id
		),
	}
	_floor_bundle_plans[safe_floor] = bundle
	return bundle


func _build_stage_plan(
	round_num: int,
	floor: int,
	round_in_floor: int,
	stage_type: String,
	board_id: String,
	level_id: String
) -> Dictionary:
	var layout = _load_board_layout(board_id)
	if layout == null:
		layout = _load_board_layout(DEFAULT_BOARD_ID)
		board_id = DEFAULT_BOARD_ID
	return {
		"round": round_num,
		"floor": floor,
		"round_in_floor": round_in_floor,
		"stage_type": stage_type,
		"board_id": board_id,
		"level_id": level_id,
		"target_score": _resolve_target_score_for_round(round_num, _resolve_target_score(round_num, stage_type)),
		"moves": _resolve_moves_limit(round_num, stage_type),
		"shuffles": _read_default_shuffles_per_round(),
		"color_limit": _resolve_adaptive_color_limit(layout),
	}


func _get_all_board_ids() -> Array[String]:
	var ids: Array[String] = []
	var config := get_node("configuration", true)
	if not config.is_valid():
		return ids
	var boards := config.get_node("match3Boards")
	if not boards.is_valid() or boards.get_type() != GnosisValueType.OBJECT:
		return ids
	for board_id in boards.get_keys():
		var key := str(board_id).strip_edges()
		if not key.is_empty():
			ids.append(key)
	ids.sort()
	return ids


func _ensure_boss_profiles_loaded() -> void:
	if _boss_profiles_loaded:
		return
	_boss_profiles_loaded = true
	_boss_profile_ids.clear()
	_normal_profile_ids.clear()
	_advanced_profile_ids.clear()
	var config := get_node("configuration", true)
	if not config.is_valid():
		return
	var levels := config.get_node("levels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		return
	for level_id in levels.get_keys():
		var entry := levels.get_node(level_id)
		if not entry.is_valid():
			continue
		var id := str(level_id).strip_edges()
		if id.is_empty():
			continue
		var meta := entry.get_node("metadata")
		if _level_has_tag(meta, "boss"):
			_add_unique(_boss_profile_ids, id)
		if _level_has_tag(meta, "normal") or id == "normal":
			_add_unique(_normal_profile_ids, id)
		if _level_has_tag(meta, "advanced") or id == "advanced":
			_add_unique(_advanced_profile_ids, id)
	_boss_profile_ids.sort()
	_normal_profile_ids.sort()
	_advanced_profile_ids.sort()


func _pick_profile_id_for_stage(stage_type: String, floor: int) -> String:
	_ensure_boss_profiles_loaded()
	var pool: Array[String] = _normal_profile_ids
	var offset := 0
	if stage_type == "advanced":
		pool = _advanced_profile_ids
		offset = 1
	if pool.is_empty():
		return stage_type
	var index := _compute_deterministic_seeded_index(pool.size(), floor, stage_type, "profile", offset)
	return pool[index]


func _read_boss_minimum_round(profile_id: String) -> int:
	var profile := _get_level_profile(profile_id)
	if profile == null or not profile.is_valid():
		return 1
	var props := profile.get_node("properties")
	var min_round := _node_int(props, "minimumRound", 0)
	return 1 if min_round <= 0 else min_round


func _build_eligible_boss_profile_ids(boss_round_number: int) -> Array[String]:
	_ensure_boss_profiles_loaded()
	var round := maxi(1, boss_round_number)
	var eligible: Array[String] = []
	for id in _boss_profile_ids:
		if round >= _read_boss_minimum_round(id):
			eligible.append(id)
	if eligible.is_empty():
		eligible = _boss_profile_ids.duplicate()
	eligible.sort()
	return eligible


func _filter_boss_profiles_to_peak_tier(eligible: Array[String]) -> Array[String]:
	if eligible.is_empty():
		return []
	var peak_tier := 0
	for id in eligible:
		peak_tier = maxi(peak_tier, _read_boss_minimum_round(id))
	if peak_tier <= 0:
		return eligible.duplicate()
	var preferred: Array[String] = []
	for id in eligible:
		if _read_boss_minimum_round(id) == peak_tier:
			preferred.append(id)
	if preferred.is_empty():
		return eligible.duplicate()
	preferred.sort()
	return preferred


func _pick_boss_profile_id_for_round(floor: int, boss_round_number: int) -> String:
	var pool := _filter_boss_profiles_to_peak_tier(_build_eligible_boss_profile_ids(boss_round_number))
	if pool.is_empty():
		return "normal"
	var index := _compute_deterministic_seeded_index(pool.size(), floor, "boss", "profile", 2)
	return pool[index]


func _pick_boss_board_for_profile(
	boss_profile_id: String,
	floor: int,
	used_ids: Array[String],
	fallback_all_ids: Array[String]
) -> String:
	var profile := _get_level_profile(boss_profile_id)
	if profile != null and profile.is_valid():
		var props := profile.get_node("properties")
		var allowed := props.get_node("allowedBoards")
		if allowed.is_valid() and allowed.get_type() == GnosisValueType.LIST and allowed.get_count() > 0:
			var allow_set: Dictionary = {}
			for i in range(allowed.get_count()):
				var bid := str(_node_value(allowed.get_node(i))).strip_edges()
				if not bid.is_empty():
					allow_set[bid] = true
			if not allow_set.is_empty():
				var narrowed: Array[String] = []
				for board_id in _boss_board_pool_ids:
					if allow_set.has(board_id):
						narrowed.append(board_id)
				if narrowed.is_empty():
					for board_id in fallback_all_ids:
						if allow_set.has(board_id):
							narrowed.append(board_id)
				if not narrowed.is_empty():
					var picked := _pick_random_boss_board_from_candidates(narrowed, used_ids, floor, boss_profile_id)
					if not picked.is_empty():
						return picked
	return _pick_board_id_for_stage("boss", floor, used_ids, fallback_all_ids)


func _pick_random_boss_board_from_candidates(
	candidate_ids: Array[String],
	used_ids: Array[String],
	floor: int,
	boss_profile_id: String
) -> String:
	if candidate_ids.is_empty():
		return ""
	var usable: Array[String] = []
	for board_id in candidate_ids:
		if board_id.is_empty() or used_ids.has(board_id):
			continue
		usable.append(board_id)
	if usable.is_empty():
		usable = candidate_ids.duplicate()
	if usable.is_empty():
		return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s:bossboard" % [_try_get_run_seed(), floor, boss_profile_id])
	var selected := usable[rng.randi_range(0, usable.size() - 1)]
	_add_unique(used_ids, selected)
	return selected


func _get_level_profile(profile_id: String) -> GnosisNode:
	if profile_id.strip_edges().is_empty():
		return null
	var config := get_node("configuration", true)
	if not config.is_valid():
		return null
	var levels := config.get_node("levels")
	if not levels.is_valid():
		return null
	var entry := levels.get_node(profile_id.strip_edges())
	if entry.is_valid():
		return entry
	return null


func _pick_board_id_for_stage(
	stage_type: String,
	floor: int,
	used_ids: Array[String],
	fallback_all_ids: Array[String]
) -> String:
	var pool: Array[String] = _normal_board_pool_ids
	if stage_type == "advanced":
		pool = _advanced_board_pool_ids
	elif stage_type == "boss":
		pool = _boss_board_pool_ids
	var picked := _pick_from_pool(pool, floor, stage_type, used_ids)
	if not picked.is_empty():
		return picked
	return _pick_from_pool(fallback_all_ids, floor, stage_type, used_ids)


func _pick_from_pool(
	pool: Array[String],
	floor: int,
	stage_type: String,
	used_ids: Array[String]
) -> String:
	if pool.is_empty():
		return ""
	var candidates: Array[String] = []
	for board_id in pool:
		if board_id.is_empty() or used_ids.has(board_id):
			continue
		candidates.append(board_id)
	if candidates.is_empty():
		candidates = pool.duplicate()
	if candidates.is_empty():
		return ""
	var offset := 0
	if stage_type == "advanced":
		offset = 1
	elif stage_type == "boss":
		offset = 2
	var index := _compute_deterministic_seeded_index(candidates.size(), floor, stage_type, "board", offset)
	var selected := candidates[index]
	_add_unique(used_ids, selected)
	return selected


func _compute_deterministic_seeded_index(
	count: int,
	floor: int,
	stage_type: String,
	kind: String,
	offset: int
) -> int:
	if count <= 1:
		return 0
	var run_seed := _try_get_run_seed()
	var normalized_floor := maxi(1, floor)
	var stage_hash := _stable_string_hash(stage_type)
	var kind_hash := _stable_string_hash(kind)
	var hash_val: int = 2166136261
	hash_val = int((hash_val ^ run_seed) * 16777619) & 0xFFFFFFFF
	hash_val = int((hash_val ^ normalized_floor) * 16777619) & 0xFFFFFFFF
	hash_val = int((hash_val ^ offset) * 16777619) & 0xFFFFFFFF
	hash_val = int((hash_val ^ stage_hash) * 16777619) & 0xFFFFFFFF
	hash_val = int((hash_val ^ kind_hash) * 16777619) & 0xFFFFFFFF
	return int(hash_val % count)


func _node_value(node: GnosisNode) -> Variant:
	if node == null or not node.is_valid():
		return null
	return node.value


func _level_has_tag(meta: GnosisNode, tag: String) -> bool:
	if meta == null or not meta.is_valid():
		return false
	var tags := meta.get_node("tags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	for i in range(tags.get_count()):
		var t := tags.get_node(i)
		if t.is_valid() and str(t.value) == tag:
			return true
	return false


func _load_board_pools() -> void:
	if _board_pools_loaded:
		return
	_board_pools_loaded = true
	_normal_board_pool_ids.clear()
	_advanced_board_pool_ids.clear()
	_boss_board_pool_ids.clear()
	_board_difficulty_by_id.clear()
	if not FileAccess.file_exists(BOARDS_INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOARDS_INDEX_PATH))
	if not (parsed is Dictionary):
		return
	var entries: Variant = parsed.get("match3Boards", [])
	if not (entries is Array):
		return
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var board_id := str(entry.get("id", "")).strip_edges()
		if board_id.is_empty():
			continue
		var difficulty := _infer_board_difficulty(entry)
		_board_difficulty_by_id[board_id] = difficulty
		match difficulty:
			"easy":
				_add_unique(_normal_board_pool_ids, board_id)
			"normal":
				_add_unique(_normal_board_pool_ids, board_id)
				_add_unique(_advanced_board_pool_ids, board_id)
			"advanced":
				_add_unique(_advanced_board_pool_ids, board_id)
			"hard", "extreme", "boss":
				_add_unique(_boss_board_pool_ids, board_id)
	_normal_board_pool_ids.sort()
	_advanced_board_pool_ids.sort()
	_boss_board_pool_ids.sort()


func _infer_board_difficulty(entry: Dictionary) -> String:
	var difficulty := str(entry.get("difficulty", "")).strip_edges().to_lower()
	if not difficulty.is_empty():
		return difficulty
	var path := str(entry.get("path", "")).strip_edges().to_lower()
	if path.begins_with("easy/"):
		return "easy"
	if path.begins_with("normal/"):
		return "normal"
	if path.begins_with("hard/"):
		return "hard"
	if path.begins_with("extreme/"):
		return "extreme"
	return ""


func _resolve_target_score(round_number: int, stage_type: String) -> int:
	var target := BASE_SCORE_TO_WIN + (maxi(1, round_number) - 1) * 350
	if stage_type == "advanced":
		target = int(roundf(float(target) * 1.2))
	elif stage_type == "boss":
		target = int(roundf(float(target) * 1.5))
	return maxi(1, target)


func _resolve_moves_limit(round: int, stage_type: String) -> int:
	var moves := _read_default_moves_per_round() + int((maxi(1, round) - 1) / 3)
	if stage_type == "boss":
		moves += 2
	return maxi(1, moves)


func _read_default_moves_per_round() -> int:
	var m3 := get_node("match3", false)
	if m3.is_valid():
		return maxi(1, _node_int(m3, "defaultMovesPerRound", BASE_MOVES_LIMIT))
	return BASE_MOVES_LIMIT


func _read_default_shuffles_per_round() -> int:
	var m3 := get_node("match3", false)
	if m3.is_valid():
		return maxi(0, _node_int(m3, "defaultShufflesPerRound", DEFAULT_SHUFFLES_PER_ROUND))
	return DEFAULT_SHUFFLES_PER_ROUND


func _read_pending_round_moves_add() -> int:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return 0
	return maxi(0, _node_int(m3, "pendingRoundMovesAdd", 0))


func _clear_pending_round_moves_add() -> void:
	var m3 := get_node("match3", false)
	if m3.is_valid():
		m3.set_key("pendingRoundMovesAdd", 0)


func _resolve_adaptive_color_limit(layout) -> int:
	var playable := _count_playable_board_squares(layout)
	var target := 6
	if playable <= COLOR_LIMIT_PLAYABLE_SMALL:
		target = 4
	elif playable <= COLOR_LIMIT_PLAYABLE_MEDIUM:
		target = 5
	return mini(target, _item_points.size()) if not _item_points.is_empty() else target


func _count_playable_board_squares(layout) -> int:
	if layout == null:
		return 0
	var count := 0
	for sq in layout.squares:
		if sq.slot_type != Models.SLOT_NONE:
			count += 1
	return count


func _add_unique(ids: Array[String], board_id: String) -> void:
	if board_id.is_empty() or ids.has(board_id):
		return
	ids.append(board_id)


func _refresh_item_catalog() -> void:
	_item_points.clear()
	var config := get_node("configuration", true)
	if not config.is_valid():
		return
	var items := config.get_node("items")
	if not items.is_valid() or items.get_type() != GnosisValueType.OBJECT:
		return
	for item_id in items.get_keys():
		var entry := items.get_node(item_id)
		if not entry.is_valid():
			continue
		var props := entry.get_node("properties")
		var points = Models.DEFAULT_ITEM_POINTS
		if props.is_valid():
			points = _node_int(props, "basePoints", Models.DEFAULT_ITEM_POINTS)
		_item_points[str(item_id)] = points


## Unity ResolveItemScoreProfile: item level + item type scoring modifiers.
func _resolve_item_score_profile(item_id: String, item_type_id: String) -> Dictionary:
	var fallback_points := int(_item_points.get(item_id, Models.DEFAULT_ITEM_POINTS))
	var fallback_multi := Models.DEFAULT_ITEM_MULTI
	var level := _resolve_item_level(item_id)
	var points := fallback_points
	var multi := fallback_multi

	var config := get_node("configuration", true)
	if config.is_valid():
		var items := config.get_node("items")
		if items.is_valid() and items.get_type() == GnosisValueType.OBJECT:
			var entry := items.get_node(item_id.strip_edges())
			if entry.is_valid():
				var props := entry.get_node("properties")
				if props.is_valid():
					var base_points := _node_int(props, "basePoints", fallback_points)
					var base_multi := _node_int(props, "baseMulti", fallback_multi)
					var level_offset := maxi(0, level - 1)
					points = maxi(0, base_points + _node_int(props, "pointsPerLevel", 0) * level_offset)
					multi = maxi(0, base_multi + _node_int(props, "multiPerLevel", 0) * level_offset)

	return _apply_item_type_scoring(item_type_id, points, multi)


func _resolve_item_level(item_id: String) -> int:
	var trimmed := item_id.strip_edges()
	if trimmed.is_empty():
		return 1
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return 1
	var levels := m3.get_node("itemLevels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		return 1
	var level_node := levels.get_node(trimmed)
	if not level_node.is_valid():
		return 1
	if level_node.value != null:
		return maxi(1, int(level_node.value))
	return maxi(1, _node_int(level_node, "value", 1))


func _apply_item_type_scoring(item_type_id: String, base_points: int, base_multi: int) -> Dictionary:
	var points := maxi(0, base_points)
	var multi := maxi(0, base_multi)
	var type_id := item_type_id.strip_edges()
	if type_id.is_empty():
		return {"points": points, "multi": multi}

	var config := get_node("configuration", true)
	if not config.is_valid():
		return {"points": points, "multi": multi}
	var types := config.get_node("itemTypes")
	if not types.is_valid() or types.get_type() != GnosisValueType.OBJECT:
		return {"points": points, "multi": multi}
	var row := types.get_node(type_id)
	if not row.is_valid():
		return {"points": points, "multi": multi}
	var props := row.get_node("properties")
	if not props.is_valid():
		return {"points": points, "multi": multi}

	var mode := _node_str(props, "scoringMode", "additive").to_lower()
	var row_points := _node_int(props, "points", 0)
	var row_multi := _node_int(props, "multi", 0)
	var point_multiplier := _read_node_float(props, "pointMultiplier", 1.0)
	var multi_multiplier := _read_node_float(props, "multiMultiplier", 1.0)

	match mode:
		"override":
			points = row_points
			multi = row_multi
		"multiplicative":
			points = int(round(float(points) * point_multiplier)) + row_points
			multi = int(round(float(multi) * multi_multiplier)) + row_multi
		_:
			points += row_points
			multi += row_multi
			points = int(round(float(points) * point_multiplier))
			multi = int(round(float(multi) * multi_multiplier))

	return {"points": maxi(0, points), "multi": maxi(0, multi)}


func _read_node_float(node: GnosisNode, key: String, default_value: float) -> float:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return float(child.value)


func _hydrate_runtime_from_store() -> void:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return
	_gameplay.current_score = _node_int(m3, "currentScore", 0)
	_gameplay.target_score = _node_int(m3, "targetScore", BASE_SCORE_TO_WIN)
	_gameplay.current_moves = _node_int(m3, "currentMoves", BASE_MOVES_LIMIT)
	_current_round = _node_int(m3, "currentRound", 1)
	_gameplay.status = _node_int(m3, "gameStatus", Models.STATUS_LEVEL_SELECT_PANEL)
	_hydrate_round_action_reward_locks_from_ephemeral()


func _publish_ephemeral_state() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	m3.set_key("currentScore", _gameplay.current_score)
	m3.set_key("targetScore", _gameplay.target_score)
	m3.set_key("currentMoves", _gameplay.current_moves)
	m3.set_key("currentRound", _current_round)
	m3.set_key("currentFloor", _current_floor)
	m3.set_key("roundInFloor", _round_in_floor)
	m3.set_key("stageType", _active_stage_type)
	m3.set_key("gameStatus", _gameplay.status)
	m3.set_key("boardId", _active_board_id)
	m3.set_key("levelId", _active_level_id)
	m3.set_key("width", _gameplay.width)
	m3.set_key("height", _gameplay.height)
	m3.set_key("colorLimit", _gameplay.palette.size())
	m3.set_key("currentShuffles", _manual_shuffles_remaining)
	m3.set_key("roundStartShuffles", _manual_shuffles_remaining)
	if _match3_effects != null:
		_match3_effects.persist_to_store(m3)
	_ensure_floor_modifier_pool_published(m3)
	if not m3.get_node("nextLevel").is_valid():
		m3.set_key("nextLevel", _current_round)
	if not m3.get_node("winningRound").is_valid():
		m3.set_key("winningRound", DEFAULT_WINNING_ROUND)
	if context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3"]
		context.engine.commit("match3", changed_paths)


func _publish_board_reset() -> void:
	_publish_fact(Events.FACT_MATCH3_BOARD_RESET, _build_board_payload())


func _publish_board_changed() -> void:
	_publish_fact(Events.FACT_MATCH3_BOARD_CHANGED, _build_board_payload())


## Serializes the resolved move (optimistic swap + per-step cascade) so the board
## view can animate it. Each step entry carries at most one of matched/movements/
## spawns, matching how the gameplay core emits them.
func _publish_move_resolved(a, b, success: bool, results: Array) -> void:
	if context == null or context.store == null:
		return
	const PlaybackScript = preload("res://game/match3/boons/match3_finalize_playback.gd")
	const HudMetricsScript = preload("res://game/match3/view/match3_hud_metrics.gd")
	var payload := context.store.create_object()
	payload.set_key("success", success)
	payload.set_key("stepCount", results.size())
	payload.set_key("finalScoreGain", _gameplay.current_score)
	var swap := context.store.create_object()
	swap.set_key("x1", a.x)
	swap.set_key("y1", a.y)
	swap.set_key("x2", b.x)
	swap.set_key("y2", b.y)
	payload.set_node("swap", swap)
	var steps := context.store.create_list()
	for entry in results:
		if entry == null:
			continue
		var step := context.store.create_object()
		var matched := context.store.create_list()
		for coord in entry.matched_tiles:
			var c := context.store.create_object()
			c.set_key("x", coord.x)
			c.set_key("y", coord.y)
			matched.add(c)
		step.set_node("matched", matched)
		var contributions := context.store.create_list()
		for contrib in entry.contributions:
			if contrib is Dictionary:
				var c := context.store.create_object()
				var at: Dictionary = contrib.get("at", {})
				c.set_key("x", int(at.get("x", 0)))
				c.set_key("y", int(at.get("y", 0)))
				c.set_key("itemId", str(contrib.get("itemId", "")))
				c.set_key("itemTypeId", str(contrib.get("itemTypeId", "plain")))
				c.set_key("pointsAdded", int(contrib.get("pointsAdded", 0)))
				c.set_key("multiAdded", int(contrib.get("multiAdded", 0)))
				contributions.add(c)
		step.set_node("contributions", contributions)
		var moves := context.store.create_list()
		for mv in entry.movements:
			var m := context.store.create_object()
			m.set_key("fromX", mv.from_coord.x)
			m.set_key("fromY", mv.from_coord.y)
			m.set_key("toX", mv.to_coord.x)
			m.set_key("toY", mv.to_coord.y)
			m.set_key("itemId", mv.item_id)
			moves.add(m)
		step.set_node("movements", moves)
		var spawns := context.store.create_list()
		for sp in entry.new_spawns:
			var s := context.store.create_object()
			s.set_key("x", sp.at.x)
			s.set_key("y", sp.at.y)
			s.set_key("itemId", sp.item_id)
			s.set_key("itemTypeId", sp.item_type_id)
			spawns.add(s)
		step.set_node("spawns", spawns)
		if entry is Models.MatchResult:
			step.set_key("movePointsSoFar", entry.move_points_so_far)
			step.set_key("moveMultiSoFar", maxi(1, entry.move_multi_so_far))
			step.set_key("pointsAdded", entry.points_added)
			step.set_key("multiAdded", entry.multi_added)
			var floor_pops := context.store.create_list()
			for pop in entry.floor_float_pops:
				if not (pop is Dictionary):
					continue
				var pop_node := context.store.create_object()
				pop_node.set_key("x", int(pop.get("x", 0)))
				pop_node.set_key("y", int(pop.get("y", 0)))
				pop_node.set_key("pointsDelta", int(pop.get("pointsDelta", 0)))
				pop_node.set_key("multiDelta", int(pop.get("multiDelta", 0)))
				pop_node.set_key("moneyDelta", int(pop.get("moneyDelta", 0)))
				floor_pops.add(pop_node)
			if floor_pops.get_count() > 0:
				step.set_node("floorFloatPops", floor_pops)
			var floor_cleared := context.store.create_list()
			for cleared in entry.floor_cells_cleared:
				if not (cleared is Dictionary):
					continue
				var cleared_node := context.store.create_object()
				cleared_node.set_key("x", int(cleared.get("x", 0)))
				cleared_node.set_key("y", int(cleared.get("y", 0)))
				floor_cleared.add(cleared_node)
			if floor_cleared.get_count() > 0:
				step.set_node("floorCellsCleared", floor_cleared)
			var floor_placed := context.store.create_list()
			for placed in entry.floor_cells_placed:
				if not (placed is Dictionary):
					continue
				var placed_node := context.store.create_object()
				placed_node.set_key("x", int(placed.get("x", 0)))
				placed_node.set_key("y", int(placed.get("y", 0)))
				placed_node.set_key("cellFloorTypeId", str(placed.get("cellFloorTypeId", "")))
				placed_node.set_key("spriteId", str(placed.get("spriteId", "")))
				placed_node.set_key("sortingOrderBase", int(placed.get("sortingOrderBase", 55)))
				floor_placed.add(placed_node)
			if floor_placed.get_count() > 0:
				step.set_node("floorCellsPlaced", floor_placed)
			var finalize_steps := context.store.create_list()
			for fin_step in entry.cell_floor_finalize_steps:
				if not (fin_step is Dictionary):
					continue
				var fin_node := context.store.create_object()
				fin_node.set_key("floorTypeId", str(fin_step.get("floorTypeId", "")))
				fin_node.set_key("x", int(fin_step.get("x", 0)))
				fin_node.set_key("y", int(fin_step.get("y", 0)))
				fin_node.set_key("multiDelta", int(fin_step.get("multiDelta", 0)))
				fin_node.set_key("multiDisplayText", str(fin_step.get("multiDisplayText", "")))
				fin_node.set_key("multiDisplayOp", str(fin_step.get("multiDisplayOp", "")))
				fin_node.set_key("multiDisplayFactor", float(fin_step.get("multiDisplayFactor", 0.0)))
				finalize_steps.add(fin_node)
			if finalize_steps.get_count() > 0:
				step.set_node("cellFloorFinalizeSteps", finalize_steps)
			var boon_resolve_steps: Array = entry.boon_resolve_steps.duplicate()
			HudMetricsScript.annotate_boon_score_steps(
				boon_resolve_steps,
				entry.move_points_so_far,
				maxi(1, entry.move_multi_so_far)
			)
			var boon_resolve := context.store.create_list()
			for resolve_step in boon_resolve_steps:
				if not (resolve_step is Dictionary):
					continue
				var resolve_node := context.store.create_object()
				resolve_node.set_key("boonId", str(resolve_step.get("boonId", "")))
				resolve_node.set_key("slotIndex", int(resolve_step.get("slotIndex", 0)))
				resolve_node.set_key("calculationId", str(resolve_step.get("calculationId", "")))
				resolve_node.set_key("pointsDelta", int(resolve_step.get("pointsDelta", 0)))
				resolve_node.set_key("multiDelta", int(resolve_step.get("multiDelta", 0)))
				resolve_node.set_key("pointsDisplayText", str(resolve_step.get("pointsDisplayText", "")))
				resolve_node.set_key("multiDisplayText", str(resolve_step.get("multiDisplayText", "")))
				resolve_node.set_key("stepPoints", int(resolve_step.get("stepPoints", 0)))
				resolve_node.set_key("stepMulti", int(resolve_step.get("stepMulti", 1)))
				boon_resolve.add(resolve_node)
			if boon_resolve.get_count() > 0:
				step.set_node("boonResolveSteps", boon_resolve)
		steps.add(step)
	var cell_floor_finalize := context.store.create_list()
	var scoring_entry := Models.last_scoring_match_result(results)
	if scoring_entry != null:
		for fin_step in scoring_entry.cell_floor_finalize_steps:
			if not (fin_step is Dictionary):
				continue
			var fin_node := context.store.create_object()
			fin_node.set_key("floorTypeId", str(fin_step.get("floorTypeId", "")))
			fin_node.set_key("x", int(fin_step.get("x", 0)))
			fin_node.set_key("y", int(fin_step.get("y", 0)))
			fin_node.set_key("multiDelta", int(fin_step.get("multiDelta", 0)))
			fin_node.set_key("multiDisplayText", str(fin_step.get("multiDisplayText", "")))
			fin_node.set_key("multiDisplayOp", str(fin_step.get("multiDisplayOp", "")))
			fin_node.set_key("multiDisplayFactor", float(fin_step.get("multiDisplayFactor", 0.0)))
			cell_floor_finalize.add(fin_node)
	if cell_floor_finalize.get_count() > 0:
		payload.set_node("cellFloorFinalizeSteps", cell_floor_finalize)
	var boon_finalize := context.store.create_list()
	if scoring_entry != null:
		var boon_finalize_steps: Array = scoring_entry.boon_finalize_steps.duplicate()
		HudMetricsScript.annotate_boon_score_steps(
			boon_finalize_steps,
			scoring_entry.move_points_so_far,
			maxi(1, scoring_entry.move_multi_so_far)
		)
		for fin_step in boon_finalize_steps:
			if not (fin_step is Dictionary):
				continue
			var fin_node := context.store.create_object()
			fin_node.set_key("boonId", str(fin_step.get("boonId", "")))
			fin_node.set_key("slotIndex", int(fin_step.get("slotIndex", 0)))
			fin_node.set_key("calculationId", str(fin_step.get("calculationId", "")))
			fin_node.set_key("pointsDelta", int(fin_step.get("pointsDelta", 0)))
			fin_node.set_key("multiDelta", int(fin_step.get("multiDelta", 0)))
			fin_node.set_key("pointsDisplayText", str(fin_step.get("pointsDisplayText", "")))
			fin_node.set_key("multiDisplayText", str(fin_step.get("multiDisplayText", "")))
			fin_node.set_key("stepPoints", int(fin_step.get("stepPoints", 0)))
			fin_node.set_key("stepMulti", int(fin_step.get("stepMulti", 1)))
			boon_finalize.add(fin_node)
	if boon_finalize.get_count() > 0:
		payload.set_node("boonFinalizeSteps", boon_finalize)
	var playback_steps := context.store.create_list()
	var playback_source: Array = []
	if scoring_entry != null and "finalize_playback_steps" in scoring_entry:
		playback_source = scoring_entry.finalize_playback_steps.duplicate(true)
	if playback_source.is_empty() and scoring_entry != null:
		for tagged in PlaybackScript.build_from_match_result(scoring_entry):
			playback_source.append(tagged)
	if not playback_source.is_empty() and scoring_entry != null:
		HudMetricsScript.annotate_finalize_playback_steps(
			playback_source,
			scoring_entry.move_points_so_far,
			maxi(1, scoring_entry.move_multi_so_far)
		)
	for pb_step in playback_source:
		if not (pb_step is Dictionary):
			continue
		var pb_node := context.store.create_object()
		for key in pb_step.keys():
			pb_node.set_key(str(key), pb_step[key])
		playback_steps.add(pb_node)
	if playback_steps.get_count() > 0:
		payload.set_node("finalizePlaybackSteps", playback_steps)
	payload.set_key("currentScore", _gameplay.current_score)
	payload.set_key("lastMoveScoreGain", _last_move_score)
	payload.set_key("targetScore", _gameplay.target_score)
	payload.set_node("steps", steps)
	_publish_fact(Events.FACT_MATCH3_MOVE_RESOLVED, payload)


func _publish_status_changed() -> void:
	if context == null or context.store == null:
		return
	var payload := context.store.create_object()
	payload.set_key(Events.PAYLOAD_GAME_STATUS, _gameplay.status)
	_publish_fact(Events.FACT_MATCH3_STATUS_CHANGED, payload)


func _build_board_payload() -> GnosisNode:
	var payload := context.store.create_object()
	var grid_ready := _is_board_grid_ready()
	payload.set_key(Events.PAYLOAD_WIDTH, _gameplay.width if grid_ready else 0)
	payload.set_key(Events.PAYLOAD_HEIGHT, _gameplay.height if grid_ready else 0)
	payload.set_key(Events.PAYLOAD_SCORE, _gameplay.current_score)
	payload.set_key(Events.PAYLOAD_SCORE_TO_WIN, _gameplay.target_score)
	payload.set_key(Events.PAYLOAD_CURRENT_MOVES, _gameplay.current_moves)
	var tiles := context.store.create_list()
	if grid_ready:
		for y in _gameplay.height:
			for x in _gameplay.width:
				var tile = _gameplay.get_tile(x, y)
				var tile_node = context.store.create_object()
				tile_node.set_key("x", x)
				tile_node.set_key("y", y)
				tile_node.set_key("itemId", tile.item_id if tile else "")
				tile_node.set_key("itemTypeId", tile.item_type_id if tile else "plain")
				tile_node.set_key("slotType", tile.slot_type if tile else Models.SLOT_NONE)
				tile_node.set_key("cellFloorTypeId", tile.cell_floor_type_id if tile else "")
				tiles.add(tile_node)
	payload.set_node(Events.PAYLOAD_TILES, tiles)
	return payload


func _publish_fact(event_id: String, payload: GnosisNode = null) -> void:
	if context == null or context.event_bus == null:
		return
	if payload == null and context.store:
		payload = context.store.create_object()
	context.event_bus.publish(GnosisEvent.new(event_id, payload, false))


func _ensure_run_ephemeral_defaults() -> void:
	if context == null or context.engine == null or context.store == null:
		return
	var currency = context.engine.get_service("Currency")
	if currency and currency.has_method("invoke_function"):
		var params := context.store.create_object()
		params.set_key("currencyId", PAYOUT_CURRENCY_ID)
		currency.invoke_function("GetBalance", params)
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	if not m3.get_node("winningRound").is_valid():
		m3.set_key("winningRound", DEFAULT_WINNING_ROUND)
	if not m3.get_node("nextLevel").is_valid():
		m3.set_key("nextLevel", 1)
	_ensure_floor_modifier_pool_published(m3)
	_ensure_match3_animation_defaults(m3)
	_ensure_statistics_root()
	var consumable = context.engine.get_service("Consumable")
	if consumable and consumable.has_method("invoke_function"):
		var bag_params := context.store.create_object()
		bag_params.set_key("bucketId", "default")
		consumable.invoke_function("GetCount", bag_params)


func _ensure_statistics_root() -> void:
	var stats := get_node("statistics", false)
	if stats.is_valid() and stats.get_type() == GnosisValueType.OBJECT:
		return
	if context == null or context.store == null:
		return
	set_node("statistics", context.store.create_object(), false)


func _ensure_match3_animation_defaults(m3: GnosisNode) -> void:
	if context == null or context.store == null:
		return
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return
	var animation := m3.get_node("animation")
	if not animation.is_valid() or animation.get_type() != GnosisValueType.OBJECT:
		animation = context.store.create_object()
		m3.set_node("animation", animation)
	_set_animation_default(animation, "consumableUsePopDurationSeconds", 0.35)
	_set_animation_default(animation, "consumableUseRemoveGapSeconds", 0.4)
	_set_animation_default(animation, "consumableUseRemoveDurationSeconds", 0.25)
	_set_animation_default(animation, "scoreStepCountDurationSeconds", 0.22)
	_set_animation_default(animation, "scoreTransferDelaySeconds", 0.35)
	_set_animation_default(animation, "scoreTransferDurationSeconds", 0.55)
	_set_animation_default(animation, "scorePostFinalizeHoldSeconds", 0.12)
	_set_animation_default(animation, "boonFinalizePopDurationSeconds", 0.45)
	_set_animation_default(animation, "boonFinalizeHoldDurationSeconds", 0.22)
	_set_animation_default(animation, "boonFinalizeGapSeconds", 0.2)


func _set_animation_default(animation: GnosisNode, key: String, value: float) -> void:
	if not animation.is_valid():
		return
	var node := animation.get_node(key)
	if node.is_valid() and node.value != null:
		return
	animation.set_key(key, value)


func _increment_statistic(key: String, delta: int = 1) -> void:
	if delta == 0 or key.strip_edges().is_empty():
		return
	if context == null or context.engine == null or context.store == null:
		return
	var statistic = context.engine.get_service("Statistic")
	if statistic == null or not statistic.has_method("invoke_function"):
		return
	var payload := context.store.create_object()
	payload.set_key("persistent", false)
	payload.set_key("key", key.strip_edges())
	payload.set_key("delta", delta)
	statistic.invoke_function("IncrementCounter", payload)


func _record_move_statistics(results: Array) -> void:
	if results.is_empty():
		return
	_increment_statistic("match3.moves.used", 1)
	var match_steps := 0
	var destroyed := 0
	for entry in results:
		if entry == null:
			continue
		if entry.matched_tiles.size() > 0:
			match_steps += 1
		destroyed += int(entry.cleared_tile_count_this_step)
	if match_steps > 0:
		_increment_statistic("match3.matches.total", match_steps)
	if destroyed > 0:
		_increment_statistic("match3.items.destroyed.total", destroyed)


func _record_round_end_unused_budget_statistics() -> void:
	var unused_moves := maxi(0, _gameplay.current_moves)
	if unused_moves > 0:
		_increment_statistic("match3.moves.unused", unused_moves)
	var unused_shuffles := maxi(0, _manual_shuffles_remaining)
	if unused_shuffles > 0:
		_increment_statistic("match3.shuffles.unused", unused_shuffles)


func _play_level_from_queue(double_down: bool) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var m3 := get_node("match3", false)
	var round := maxi(1, _node_int(m3, "nextLevel", _current_round + 1))
	var payload := context.store.create_object()
	if double_down:
		if _read_consumable_bag_empty_slot_count() < 1:
			payload.set_key("success", false)
			payload.set_key("reason", "inventory_full")
			payload.set_key("nextLevel", round)
			return GnosisFunctionResult.ok(payload)
		if _get_authoritative_round_action_reward_consumable_id(round).is_empty():
			payload.set_key("success", false)
			payload.set_key("reason", "no_round_action_reward_catalog")
			payload.set_key("nextLevel", round)
			return GnosisFunctionResult.ok(payload)
		if not _try_grant_round_action_consumable_reward(round):
			payload.set_key("success", false)
			payload.set_key("reason", "grant_failed")
			payload.set_key("nextLevel", round)
			return GnosisFunctionResult.ok(payload)
		_set_double_down_for_round(round)
	else:
		_clear_double_down_state()
	_increment_statistic("match3.rounds.played", 1)
	_increment_statistic("match3.rounds.total", 1)
	if double_down:
		_increment_statistic("match3.rounds.doubleDown", 1)
	_begin_level(round)
	_gameplay.status = Models.STATUS_PLAYING
	_last_step_points = 0
	_last_step_multi = 0
	_last_move_score = 0
	if m3.is_valid():
		m3.set_key("nextLevel", round + 1)
	refresh_planned_floor_preview()
	_publish_ephemeral_state()
	_publish_board_reset()
	_publish_status_changed()
	payload.set_key("success", true)
	payload.set_key("reason", "ok")
	payload.set_key("nextLevel", round + 1)
	payload.set_key("levelNumber", round)
	payload.set_key(Events.PAYLOAD_DOUBLE_DOWN, double_down)
	return GnosisFunctionResult.ok(payload)


func _skip_level_from_queue() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var m3 := get_node("match3", false)
	var round := maxi(1, _node_int(m3, "nextLevel", _current_round + 1))
	var payload := context.store.create_object()
	if not _is_round_skippable(round):
		payload.set_key("success", false)
		payload.set_key("reason", "not_skippable")
		payload.set_key("nextLevel", round)
		return GnosisFunctionResult.ok(payload)
	if _read_consumable_bag_empty_slot_count() < 1:
		payload.set_key("success", false)
		payload.set_key("reason", "inventory_full")
		payload.set_key("nextLevel", round)
		return GnosisFunctionResult.ok(payload)
	if _get_authoritative_round_action_reward_consumable_id(round).is_empty():
		payload.set_key("success", false)
		payload.set_key("reason", "no_round_action_reward_catalog")
		payload.set_key("nextLevel", round)
		return GnosisFunctionResult.ok(payload)
	if not _try_grant_round_action_consumable_reward(round):
		payload.set_key("success", false)
		payload.set_key("reason", "grant_failed")
		payload.set_key("nextLevel", round)
		return GnosisFunctionResult.ok(payload)
	_clear_double_down_state()
	var next_level := round + 1
	if m3.is_valid():
		m3.set_key("nextLevel", next_level)
	_increment_statistic("match3.rounds.skipped", 1)
	_increment_statistic("match3.rounds.total", 1)
	if _boon_runtime != null:
		_boon_runtime.on_round_skipped()
	refresh_planned_floor_preview()
	_publish_ephemeral_state()
	payload.set_key("success", true)
	payload.set_key("reason", "ok")
	payload.set_key("nextLevel", next_level)
	payload.set_key("currentRound", _current_round)
	return GnosisFunctionResult.ok(payload)


func _is_round_skippable(round_number: int) -> bool:
	var setup := _resolve_round_setup(maxi(1, round_number))
	return str(setup.get("stage_type", "normal")) != "boss"


## Double-down ephemeral state (Unity Match3GnosisService.DoubleDown.partial).
func _read_double_down_target_score_multiplier() -> int:
	var m3 := get_node("match3", false)
	return maxi(1, _node_int(m3, "doubleDownTargetScoreMultiplier", DEFAULT_DOUBLE_DOWN_TARGET_MULTIPLIER))


func _apply_double_down_target_score(base_objective: int) -> int:
	var mult := _read_double_down_target_score_multiplier()
	var scaled := int(maxi(1, base_objective)) * mult
	return maxi(1, scaled)


func _is_double_down_active_for_round(round_number: int) -> bool:
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return false
	return _node_bool(m3, "doubleDownActive", false) \
		and _node_int(m3, "doubleDownRound", 0) == maxi(1, round_number)


func _set_double_down_for_round(round_number: int) -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	m3.set_key("doubleDownActive", true)
	m3.set_key("doubleDownRound", maxi(1, round_number))
	m3.set_key("isDoubleDown", true)


func _clear_double_down_state() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return
	m3.set_key("doubleDownActive", false)
	m3.set_key("doubleDownRound", 0)
	m3.set_key("isDoubleDown", false)


func _resolve_target_score_for_round(round_number: int, base_objective: int) -> int:
	var target := maxi(1, base_objective)
	return _apply_double_down_target_score(target) if _is_double_down_active_for_round(round_number) else target


func _try_use_shuffle() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	_hydrate_runtime_from_store()
	var payload := context.store.create_object()
	if _gameplay.status != Models.STATUS_PLAYING:
		payload.set_key("success", false)
		payload.set_key("reason", "not_playing")
		payload.set_key(Events.PAYLOAD_SHUFFLES_REMAINING, _manual_shuffles_remaining)
		return GnosisFunctionResult.ok(payload)
	if _manual_shuffles_remaining < 1:
		payload.set_key("success", false)
		payload.set_key("reason", "no_shuffles_remaining")
		payload.set_key(Events.PAYLOAD_SHUFFLES_REMAINING, _manual_shuffles_remaining)
		return GnosisFunctionResult.ok(payload)
	_manual_shuffles_remaining -= 1
	_increment_statistic("match3.shuffles.used", 1)
	if _boon_runtime != null and _boon_runtime.has_method("record_manual_shuffle_usage"):
		_boon_runtime.record_manual_shuffle_usage()
	var shuffle_result := _gameplay.shuffle_board(_item_points)
	_publish_ephemeral_state()
	_publish_fact(Events.FACT_MATCH3_SHUFFLE_USED, _build_shuffle_payload(shuffle_result))
	payload.set_key("success", true)
	payload.set_key("reason", "ok")
	payload.set_key(Events.PAYLOAD_SHUFFLES_REMAINING, _manual_shuffles_remaining)
	payload.set_key("currentMoves", _gameplay.current_moves)
	payload.set_key("currentRound", _current_round)
	return GnosisFunctionResult.ok(payload)


func _build_shuffle_payload(shuffle_result = null) -> GnosisNode:
	var payload := context.store.create_object()
	payload.set_key(Events.PAYLOAD_SHUFFLES_REMAINING, _manual_shuffles_remaining)
	payload.set_key("currentMoves", _gameplay.current_moves)
	if shuffle_result == null or shuffle_result.new_spawns.is_empty():
		return payload
	var matched := context.store.create_list()
	var spawns := context.store.create_list()
	for sp in shuffle_result.new_spawns:
		var coord := context.store.create_object()
		coord.set_key("x", sp.at.x)
		coord.set_key("y", sp.at.y)
		matched.add(coord)
		var spawn := context.store.create_object()
		spawn.set_key("x", sp.at.x)
		spawn.set_key("y", sp.at.y)
		spawn.set_key("itemId", sp.item_id)
		spawns.add(spawn)
	payload.set_node("matched", matched)
	payload.set_node("spawns", spawns)
	return payload


func refresh_planned_floor_preview() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	var queued_round := maxi(1, _node_int(m3, "nextLevel", _current_round + 1))
	var floor := int((queued_round - 1) / DEFAULT_ROUNDS_PER_FLOOR) + 1
	var round_in_floor := int((queued_round - 1) % DEFAULT_ROUNDS_PER_FLOOR) + 1
	var preview := context.store.create_object()
	preview.set_key("floorNumber", floor)
	preview.set_key("currentRound", queued_round)
	preview.set_key("currentRoundInFloor", round_in_floor)
	var rounds := context.store.create_list()
	var base_round := (floor - 1) * DEFAULT_ROUNDS_PER_FLOOR + 1
	for i in range(DEFAULT_ROUNDS_PER_FLOOR):
		var round_num := base_round + i
		var setup := _resolve_round_setup(round_num)
		var stage_type := str(setup.get("stage_type", "normal"))
		var level_id := str(setup.get("level_id", "normal"))
		var objective_target := int(setup.get("target_score", BASE_SCORE_TO_WIN))
		var meta := _level_meta_for_setup(setup)
		var row := context.store.create_object()
		row.set_key("stageType", stage_type)
		row.set_key("round", round_num)
		row.set_key("isCurrent", round_num == queued_round)
		row.set_key("isSkippable", stage_type != "boss")
		row.set_key("isBossRound", stage_type == "boss")
		row.set_key("objectiveTarget", objective_target)
		row.set_key("objectiveTargetDoubleDown", _apply_double_down_target_score(objective_target))
		row.set_key("doubleDownTargetScoreMultiplier", _read_double_down_target_score_multiplier())
		row.set_key("roundActionRewardConsumableId", _get_or_lock_round_action_reward_consumable_id(round_num))
		row.set_key("rewardAmount", _reward_amount_for_setup(setup))
		row.set_key("levelId", level_id)
		row.set_key("difficultySkulls", _difficulty_skulls_for_stage(stage_type))
		row.set_key("nameKey", _name_key_for_setup(stage_type, meta))
		row.set_key("descriptionKey", _description_key_for_setup(stage_type, meta))
		row.set_key("startingLetter", str(meta.get("startingLetter", "")))
		row.set_key("backgroundColor", str(meta.get("backgroundColor", "")))
		row.set_key("textColor", str(meta.get("textColor", "")))
		rounds.add(row)
	preview.set_node("rounds", rounds)
	m3.set_node("plannedFloor", preview)
	if context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3"]
		context.engine.commit("match3", changed_paths)


func _level_meta_for_setup(setup: Dictionary) -> Dictionary:
	var saved_level := _active_level_id
	var saved_stage := _active_stage_type
	_active_level_id = str(setup.get("level_id", "normal"))
	_active_stage_type = str(setup.get("stage_type", "normal"))
	var meta := get_active_level_meta()
	_active_level_id = saved_level
	_active_stage_type = saved_stage
	return meta


func _difficulty_skulls_for_stage(stage_type: String) -> int:
	match stage_type:
		"boss":
			return 3
		"advanced":
			return 2
		_:
			return 1


func _name_key_for_setup(stage_type: String, meta: Dictionary) -> String:
	var key := str(meta.get("nameKey", ""))
	if not key.is_empty():
		return key
	match stage_type:
		"boss":
			return "bossLevelName"
		"advanced":
			return "advancedLevelName"
		_:
			return "normalLevelName"


func _description_key_for_setup(stage_type: String, meta: Dictionary) -> String:
	var key := str(meta.get("descriptionKey", ""))
	if not key.is_empty():
		return key
	match stage_type:
		"boss":
			return "bossLevelDescription"
		"advanced":
			return "advancedLevelDescription"
		_:
			return "normalLevelDescription"


func _reward_amount_for_setup(setup: Dictionary) -> int:
	var stage_type := str(setup.get("stage_type", "normal"))
	var level_id := str(setup.get("level_id", "normal"))
	var saved_level := _active_level_id
	var saved_stage := _active_stage_type
	_active_level_id = level_id
	_active_stage_type = stage_type
	var amount := _resolve_stage_reward_amount()
	_active_level_id = saved_level
	_active_stage_type = saved_stage
	return amount


func _handle_round_won() -> void:
	_record_round_end_unused_budget_statistics()
	_apply_round_end_floor_boon_hooks()
	if _active_stage_type == "boss":
		_increment_statistic("match3.rounds.bossesDefeated", 1)
	_update_run_completion_state(true)
	var run_won := is_run_won()
	_prepare_pending_round_reward_after_win()
	if run_won:
		_finalize_pending_round_rewards_silent()
		_gameplay.status = Models.STATUS_LOSE_PANEL
	else:
		_queue_next_level_after_win()
		refresh_planned_floor_preview()
		_gameplay.status = Models.STATUS_REWARD_PANEL
	_publish_ephemeral_state()
	_publish_status_changed()


func _queue_next_level_after_win() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	var next_level := maxi(_current_round + 1, _node_int(m3, "nextLevel", _current_round + 1))
	m3.set_key("nextLevel", next_level)


func _update_run_completion_state(won_round: bool) -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	var winning_round := _node_int(m3, "winningRound", DEFAULT_WINNING_ROUND)
	var endless_enabled := _node_bool(m3, "endlessModeEnabled", false)
	var run_won := not endless_enabled and won_round and _current_round >= winning_round
	var run_lost := not won_round
	var run_complete := run_won or run_lost
	m3.set_key("winningRound", winning_round)
	m3.set_key("isRunComplete", run_complete)
	m3.set_key("isRunWon", run_won)
	m3.set_key("runResult", "win" if run_won else ("loss" if run_lost else ""))


func _prepare_pending_round_reward_after_win() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	var payout := context.store.create_object()
	payout.set_key("payoutId", "%d-%d" % [maxi(1, _current_round), Time.get_ticks_usec()])
	payout.set_key("currencyId", PAYOUT_CURRENCY_ID)
	payout.set_key("nextStepIndex", 0)
	payout.set_key("isComplete", false)
	var steps := context.store.create_list()
	var round_reward := _resolve_stage_reward_amount()
	if round_reward > 0:
		_append_reward_step(steps, REWARD_REASON_ROUND, round_reward)
	var unused_moves := maxi(0, _gameplay.current_moves)
	if unused_moves > 0:
		var unused_reward := int(ceil(float(unused_moves) / 2.0))
		if unused_reward > 0:
			_append_reward_step(steps, REWARD_REASON_UNUSED_MOVES, unused_reward)
	var interest_preview := _try_get_round_reward_interest_preview()
	if interest_preview > 0:
		_append_reward_step(steps, REWARD_REASON_INTEREST, interest_preview)
	_append_dynamic_round_reward_steps(steps)
	payout.set_node("steps", steps)
	if steps.get_count() == 0:
		payout.set_key("isComplete", true)
		payout.set_key("nextStepIndex", 0)
	m3.set_node(PENDING_ROUND_REWARD_KEY, payout)
	if context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3"]
		context.engine.commit("match3", changed_paths)


func _resolve_stage_reward_amount() -> int:
	var meta := get_active_level_meta()
	var amount := int(meta.get("rewardAmount", 0))
	if amount > 0:
		return amount
	match _active_stage_type:
		"advanced":
			return 4
		"boss":
			return 5
		_:
			return 3


func _append_reward_step(steps: GnosisNode, reason_key: String, amount: int) -> void:
	if context == null or context.store == null:
		return
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST:
		return
	if amount <= 0 or reason_key.strip_edges().is_empty():
		return
	var step := context.store.create_object()
	step.set_key("reasonKey", reason_key.strip_edges())
	step.set_key("amount", amount)
	step.set_key("granted", false)
	steps.add(step)


func _try_get_round_reward_interest_preview() -> int:
	if context == null or context.engine == null or context.store == null:
		return 0
	var currency = context.engine.get_service("Currency")
	if currency == null or not currency.has_method("invoke_function"):
		return 0
	var params := context.store.create_object()
	params.set_key("currencyId", PAYOUT_CURRENCY_ID)
	var result = currency.invoke_function("CalculateInterestAmount", params)
	var node := _coerce_result_node(result)
	if node != null and node.is_valid():
		return maxi(0, _node_int(node, "interestAmount", 0))
	return 0


func _finalize_pending_round_rewards_silent() -> void:
	while _try_grant_next_round_reward_step_core():
		pass


func _grant_next_round_reward_step() -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	_hydrate_runtime_from_store()
	var outcome := _grant_next_round_reward_step_outcome()
	var payload := context.store.create_object()
	payload.set_key("success", outcome.get("error", "").is_empty())
	payload.set_key("granted", outcome.get("granted", false))
	payload.set_key("amount", int(outcome.get("amount", 0)))
	payload.set_key("reasonKey", str(outcome.get("reasonKey", "")))
	payload.set_key("complete", outcome.get("complete", false))
	var error_text := str(outcome.get("error", ""))
	if not error_text.is_empty():
		payload.set_key("error", error_text)
	_publish_ephemeral_state()
	if context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3"]
		context.engine.commit("match3", changed_paths)
	return GnosisFunctionResult.ok(payload)


func _try_grant_next_round_reward_step_core() -> bool:
	var outcome := _grant_next_round_reward_step_outcome()
	return bool(outcome.get("granted", false)) and str(outcome.get("error", "")).is_empty()


func _grant_next_round_reward_step_outcome() -> Dictionary:
	var outcome := {
		"granted": false,
		"amount": 0,
		"reasonKey": "",
		"complete": false,
		"error": "",
	}
	if context == null or context.store == null:
		outcome["error"] = "store_unavailable"
		return outcome
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		outcome["error"] = "match3_missing"
		return outcome
	var payout := m3.get_node(PENDING_ROUND_REWARD_KEY)
	if not payout.is_valid() or payout.get_type() != GnosisValueType.OBJECT:
		outcome["complete"] = true
		return outcome
	if _node_bool(payout, "isComplete", false):
		outcome["complete"] = true
		return outcome
	var steps := payout.get_node("steps")
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST or steps.get_count() == 0:
		_mark_round_reward_payout_complete(m3, payout)
		outcome["complete"] = true
		return outcome
	var next_idx := maxi(0, _node_int(payout, "nextStepIndex", 0))
	if next_idx < 0 or next_idx >= steps.get_count():
		_mark_round_reward_payout_complete(m3, payout)
		outcome["complete"] = true
		return outcome
	var step_node := steps.get_node(next_idx)
	if not step_node.is_valid() or step_node.get_type() != GnosisValueType.OBJECT:
		outcome["error"] = "invalid_step"
		return outcome
	if _node_bool(step_node, "granted", false):
		payout.set_key("nextStepIndex", next_idx + 1)
		var done_skipping := next_idx + 1 >= steps.get_count()
		if done_skipping:
			_mark_round_reward_payout_complete(m3, payout)
		outcome["complete"] = done_skipping
		return outcome
	var reason_key := _node_str(step_node, "reasonKey")
	var amount := _node_int(step_node, "amount", 0)
	if amount <= 0:
		step_node.set_key("granted", true)
		payout.set_key("nextStepIndex", next_idx + 1)
		if next_idx + 1 >= steps.get_count():
			_mark_round_reward_payout_complete(m3, payout)
		outcome["complete"] = next_idx + 1 >= steps.get_count()
		outcome["reasonKey"] = reason_key
		outcome["granted"] = true
		return outcome
	var currency_id := _node_str(payout, "currencyId", PAYOUT_CURRENCY_ID)
	if not _try_add_ephemeral_currency(currency_id, amount, outcome):
		return outcome
	_increment_statistic("currency.%s.earned" % currency_id.strip_edges(), amount)
	if reason_key == REWARD_REASON_INTEREST:
		_increment_statistic("currency.%s.interest" % currency_id.strip_edges(), amount)
	step_node.set_key("granted", true)
	var new_idx := next_idx + 1
	payout.set_key("nextStepIndex", new_idx)
	outcome["granted"] = true
	outcome["amount"] = amount
	outcome["reasonKey"] = reason_key
	outcome["complete"] = new_idx >= steps.get_count()
	if outcome["complete"]:
		_mark_round_reward_payout_complete(m3, payout)
	return outcome


func _mark_round_reward_payout_complete(m3: GnosisNode, payout: GnosisNode) -> void:
	if not payout.is_valid() or payout.get_type() != GnosisValueType.OBJECT:
		return
	payout.set_key("isComplete", true)
	if m3.is_valid() and m3.get_type() == GnosisValueType.OBJECT:
		m3.set_node(PENDING_ROUND_REWARD_KEY, payout)


func _try_add_ephemeral_currency(currency_id: String, delta: int, outcome: Dictionary) -> bool:
	if delta <= 0:
		return true
	if currency_id.strip_edges().is_empty():
		outcome["error"] = "currency_id_missing"
		return false
	if context == null or context.engine == null or context.store == null:
		outcome["error"] = "engine_missing"
		return false
	var currency = context.engine.get_service("Currency")
	if currency == null or not currency.has_method("invoke_function"):
		outcome["error"] = "currency_service_missing"
		return false
	var params := context.store.create_object()
	params.set_key("currencyId", currency_id.strip_edges())
	params.set_key("amount", delta)
	var result = currency.invoke_function("AddCurrency", params)
	var node := _coerce_result_node(result)
	if node != null and node.is_valid():
		return true
	outcome["error"] = "currency_grant_failed"
	return false


func _transition_to_state(raw_target: String) -> GnosisFunctionResult:
	if context == null or context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var previous_status: int = _gameplay.status
	var target_status := _parse_status(raw_target)
	if target_status < 0:
		return GnosisFunctionResult.fail("Unsupported gameStatus '%s'." % raw_target)
	if target_status == previous_status:
		var ignored := context.store.create_object()
		ignored.set_key("success", true)
		ignored.set_key("reason", "ignored_same_status")
		ignored.set_key("gameStatus", _status_to_key(previous_status))
		ignored.set_key("gameStatusCode", previous_status)
		return GnosisFunctionResult.ok(ignored)
	_gameplay.status = target_status
	_publish_ephemeral_state()
	_publish_status_changed()
	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("previousGameStatus", _status_to_key(previous_status))
	payload.set_key("gameStatus", _status_to_key(target_status))
	payload.set_key("gameStatusCode", target_status)
	return GnosisFunctionResult.ok(payload)


func _status_to_key(status: int) -> String:
	match status:
		Models.STATUS_PLAYING:
			return "playing"
		Models.STATUS_WIN:
			return "win"
		Models.STATUS_LOSS:
			return "loss"
		Models.STATUS_LEVEL_SELECT_PANEL:
			return "levelSelectPanel"
		Models.STATUS_REWARD_PANEL:
			return "rewardPanel"
		Models.STATUS_SHOP_PANEL:
			return "shopPanel"
		Models.STATUS_LOSE_PANEL:
			return "losePanel"
		_:
			return "levelSelectPanel"


func _parse_status(raw: String) -> int:
	var key := raw.strip_edges().to_lower()
	match key:
		"playing", "0":
			return Models.STATUS_PLAYING
		"win", "1":
			return Models.STATUS_WIN
		"loss", "2":
			return Models.STATUS_LOSS
		"levelselectpanel", "5":
			return Models.STATUS_LEVEL_SELECT_PANEL
		"rewardpanel", "statepanel", "6":
			return Models.STATUS_REWARD_PANEL
		"shoppanel", "7":
			return Models.STATUS_SHOP_PANEL
		"losepanel", "8":
			return Models.STATUS_LOSE_PANEL
		_:
			return -1


# --- Round-action consumable rewards (Unity RoundActionRewards.partial) ---

func _hydrate_round_action_reward_locks_from_ephemeral() -> void:
	_round_action_reward_locks.clear()
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return
	var locks := m3.get_node(ROUND_ACTION_REWARD_LOCKS_KEY)
	if not locks.is_valid() or locks.get_type() != GnosisValueType.OBJECT:
		return
	for key in locks.get_keys():
		var round := int(str(key))
		if round < 1:
			continue
		var child := locks.get_node(str(key))
		var id := str(child.value) if child.is_valid() and child.value != null else ""
		if not id.is_empty():
			_round_action_reward_locks[round] = id


func _write_round_action_reward_lock_to_ephemeral(round_number: int, consumable_id: String) -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	var locks := m3.get_node(ROUND_ACTION_REWARD_LOCKS_KEY)
	if not locks.is_valid() or locks.get_type() != GnosisValueType.OBJECT:
		locks = context.store.create_object()
		m3.set_node(ROUND_ACTION_REWARD_LOCKS_KEY, locks)
	locks.set_key(str(maxi(1, round_number)), consumable_id)


func _get_authoritative_round_action_reward_consumable_id(round_number: int) -> String:
	return _get_or_lock_round_action_reward_consumable_id(round_number)


func _get_or_lock_round_action_reward_consumable_id(round_number: int) -> String:
	var round := maxi(1, round_number)
	if _round_action_reward_locks.has(round):
		return str(_round_action_reward_locks[round])
	var resolved := _resolve_round_action_reward_consumable_id(round)
	if resolved.is_empty():
		return ""
	_round_action_reward_locks[round] = resolved
	_write_round_action_reward_lock_to_ephemeral(round, resolved)
	return resolved


func _resolve_round_action_reward_consumable_id(round_number: int) -> String:
	var run_seed := _try_get_run_seed()
	if run_seed == 0:
		return ""
	var pool := _build_consumable_catalog_ids_with_gameplay_tag(ROUND_ACTION_REWARD_GAMEPLAY_TAG)
	if pool.is_empty():
		return ""
	pool.sort()
	var index := _compute_deterministic_seeded_round_reward_index(
		pool.size(), round_number, ROUND_ACTION_REWARD_GAMEPLAY_TAG, run_seed
	)
	return pool[index]


func _try_grant_round_action_consumable_reward(round_number: int) -> bool:
	if context == null or context.store == null:
		return false
	var round := maxi(1, round_number)
	var consumable_id := _get_authoritative_round_action_reward_consumable_id(round)
	if consumable_id.is_empty():
		return false
	if _read_consumable_bag_empty_slot_count() < 1:
		return false
	var params := context.store.create_object()
	params.set_key("bucketId", "default")
	params.set_key("consumableId", consumable_id)
	var result = call_service("Consumable", "AddConsumable", params)
	if not _service_invoke_succeeded(result):
		return false
	var m3 := get_node("match3", false)
	if m3.is_valid() and m3.get_type() == GnosisValueType.OBJECT:
		var last_reward := context.store.create_object()
		last_reward.set_key("round", round)
		last_reward.set_key("consumableId", consumable_id)
		m3.set_node("lastRoundActionReward", last_reward)
	return true


func _read_consumable_bag_empty_slot_count(bucket_id: String = "default") -> int:
	if context == null or context.store == null:
		return 0
	var consumables := get_node("consumables", false)
	if not consumables.is_valid() or consumables.get_type() != GnosisValueType.OBJECT:
		return 0
	var bag := consumables.get_node(bucket_id)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		bag = consumables.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return 0
	var list := bag.get_node("list")
	var list_count := list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var max_size := maxi(list_count, _node_int(bag, "maxSize", list_count))
	return maxi(0, max_size - list_count)


func _consumable_list_count(bucket_id: String = "default") -> int:
	if context == null or context.store == null:
		return 0
	var consumables := get_node("consumables", false)
	if not consumables.is_valid() or consumables.get_type() != GnosisValueType.OBJECT:
		return 0
	var bag := consumables.get_node(bucket_id)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		bag = consumables.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return 0
	var list := bag.get_node("list")
	if list.is_valid() and list.get_type() == GnosisValueType.LIST:
		return list.get_count()
	return 0


func _read_consumable_id_at_index(index: int, bucket_id: String = "default") -> String:
	if context == null or context.store == null:
		return ""
	var consumables := get_node("consumables", false)
	if not consumables.is_valid() or consumables.get_type() != GnosisValueType.OBJECT:
		return ""
	var bag := consumables.get_node(bucket_id)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		bag = consumables.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return ""
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST or list.get_count() == 0:
		return ""
	var idx := clampi(index, 0, list.get_count() - 1)
	var entry := list.get_node(idx)
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return ""
	for key in ["id", "consumableId"]:
		var id_node := entry.get_node(key)
		if id_node.is_valid() and id_node.get_type() == GnosisValueType.STRING:
			return str(id_node.value).strip_edges()
	return ""


func _build_consumable_catalog_ids_with_gameplay_tag(gameplay_tag: String) -> Array[String]:
	var result: Array[String] = []
	var tag := gameplay_tag.strip_edges()
	if tag.is_empty():
		return result
	var config := get_node("configuration", true)
	if not config.is_valid():
		return result
	var catalog := config.get_node("consumables")
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return result
	for item_id in catalog.get_keys():
		var id := str(item_id).strip_edges()
		if id.is_empty():
			continue
		if _consumable_catalog_has_gameplay_tag(id, tag):
			result.append(id)
	return result


func _consumable_catalog_has_gameplay_tag(consumable_id: String, gameplay_tag: String) -> bool:
	var config := get_node("configuration", true)
	if not config.is_valid():
		return false
	var entry := config.get_node("consumables.%s" % consumable_id.strip_edges())
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return false
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	var tags := props.get_node("gameplayTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		tags = props.get_node("gameplyTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	var want := gameplay_tag.strip_edges().to_lower()
	for i in range(tags.get_count()):
		var tag_node := tags.get_node(i)
		var value := ""
		if tag_node.is_valid():
			if tag_node.get_type() == GnosisValueType.STRING:
				value = str(tag_node.value)
			elif tag_node.get_type() == GnosisValueType.OBJECT:
				value = _node_str(tag_node, "id")
		if value.strip_edges().to_lower() == want:
			return true
	return false


func _try_get_run_seed() -> int:
	if context == null or context.engine == null:
		return 0
	var seed_svc = context.engine.get_service("Seed")
	if seed_svc == null or not seed_svc.has_method("invoke_function"):
		return 0
	var result = seed_svc.invoke_function("GetSeed", context.store.create_object())
	var node := _coerce_result_node(result)
	if node == null or not node.is_valid():
		return 0
	return _node_int(node, "seed", 0)


func _compute_deterministic_seeded_round_reward_index(
	count: int,
	round_number: int,
	reward_kind: String,
	run_seed: int,
) -> int:
	if count <= 1:
		return 0
	var round := maxi(1, round_number)
	var kind_hash := _stable_string_hash(reward_kind)
	var hash := 2166136261
	hash = int((hash ^ run_seed) * 16777619) & 0xFFFFFFFF
	hash = int((hash ^ round) * 16777619) & 0xFFFFFFFF
	hash = int((hash ^ kind_hash) * 16777619) & 0xFFFFFFFF
	return int(hash % count)


func _stable_string_hash(value: String) -> int:
	return value.hash()


func _service_invoke_succeeded(result) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode:
		return result.is_valid()
	return result != null


# --- Boon dynamic round rewards (Unity RoundReward.partial) ---

func _append_dynamic_round_reward_steps(steps: GnosisNode) -> void:
	if context == null or context.store == null:
		return
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST:
		return
	var boss_defeats := get_statistic_int("match3.rounds.bossesDefeated")
	var cookie_payout := maxi(0, 1 + (2 * maxi(0, boss_defeats)))
	_for_each_equipped_boon_slot_with_effect_application(
		BOON_CATALOG_ID_COOKIE_TIME,
		func(_slot, slot_index: int) -> void:
			_append_boon_round_reward_step(steps, REWARD_REASON_COOKIE_TIME, cookie_payout, BOON_CATALOG_ID_COOKIE_TIME, slot_index),
	)
	var passive_rng := RandomNumberGenerator.new()
	passive_rng.seed = hash("%d:%d" % [_try_get_run_seed(), _current_round])
	_for_each_equipped_boon_slot_with_effect_application(
		BOON_CATALOG_ID_PASSIVE_INCOME,
		func(_slot, slot_index: int) -> void:
			_append_boon_round_reward_step(
				steps,
				REWARD_REASON_PASSIVE_INCOME,
				passive_rng.randi_range(1, 9),
				BOON_CATALOG_ID_PASSIVE_INCOME,
				slot_index,
			),
	)
	_for_each_equipped_boon_slot_with_effect_application(
		BOON_CATALOG_ID_DOUBLE_DOWN,
		func(_slot, slot_index: int) -> void:
			_append_boon_round_reward_step(steps, REWARD_REASON_DOUBLE_DOWN, 10, BOON_CATALOG_ID_DOUBLE_DOWN, slot_index),
	)
	var m3 := get_node("match3", false)
	var round_start_shuffles := maxi(0, _node_int(m3, "roundStartShuffles", 0))
	var current_shuffles := maxi(0, _node_int(m3, "currentShuffles", _manual_shuffles_remaining))
	if round_start_shuffles > 0 and current_shuffles == round_start_shuffles:
		var sleeper_payout := 2 * round_start_shuffles
		_for_each_equipped_boon_slot_with_effect_application(
			BOON_CATALOG_ID_SLEEPER,
			func(_slot, slot_index: int) -> void:
				_append_boon_round_reward_step(steps, REWARD_REASON_SLEEPER, sleeper_payout, BOON_CATALOG_ID_SLEEPER, slot_index),
		)


func _append_boon_round_reward_step(
	steps: GnosisNode,
	reason_key: String,
	amount: int,
	boon_catalog_id: String,
	boon_slot_index: int,
) -> void:
	_append_reward_step(steps, reason_key, amount)
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST or steps.get_count() == 0:
		return
	var step_node := steps.get_node(steps.get_count() - 1)
	if not step_node.is_valid() or step_node.get_type() != GnosisValueType.OBJECT:
		return
	if not boon_catalog_id.strip_edges().is_empty():
		step_node.set_key("boonCatalogId", boon_catalog_id.strip_edges())
	if boon_slot_index >= 0:
		step_node.set_key("boonSlotIndex", boon_slot_index)


func _for_each_equipped_boon_slot_with_effect_application(
	catalog_id: String,
	action: Callable,
) -> int:
	var want := catalog_id.strip_edges()
	if want.is_empty():
		return 0
	var slot_rows := _get_active_boon_inventory_slot_rows()
	var matches: Array[Dictionary] = []
	for i in range(slot_rows.size()):
		var row: GnosisNode = slot_rows[i]
		if _read_boon_catalog_id_from_inventory_entry(row).to_lower() == want.to_lower():
			matches.append({"slot": row, "index": i})
	if matches.is_empty():
		return 0
	var per_instance := _read_boon_effect_application_is_per_instance(matches[0]["slot"])
	if per_instance:
		for entry in matches:
			action.call(entry["slot"], int(entry["index"]))
		return matches.size()
	action.call(matches[0]["slot"], int(matches[0]["index"]))
	return 1


func _get_active_boon_inventory_slot_rows() -> Array:
	var rows: Array = []
	var boons := get_node("boons", false)
	if not boons.is_valid() or boons.get_type() != GnosisValueType.OBJECT:
		return rows
	var bag := boons.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return rows
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return rows
	for i in range(list.get_count()):
		var row := list.get_node(i)
		if row.is_valid() and row.get_type() == GnosisValueType.OBJECT:
			rows.append(row)
	return rows


func _read_boon_catalog_id_from_inventory_entry(entry: GnosisNode) -> String:
	if entry == null or not entry.is_valid():
		return ""
	var boon_id := _node_str(entry, "boonId")
	if not boon_id.is_empty():
		return boon_id
	return _node_str(entry, "id")


func _read_boon_effect_application_is_per_instance(entry: GnosisNode) -> bool:
	if entry == null or not entry.is_valid():
		return false
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	var mode := _node_str(props, "effectApplication", "catalogOnce")
	return mode.strip_edges().to_lower() == BOON_EFFECT_APPLICATION_PER_INSTANCE


func _dispose_subscription(sub: RefCounted) -> void:
	if sub and sub.has_method("dispose"):
		sub.dispose()


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)


func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)


func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)
