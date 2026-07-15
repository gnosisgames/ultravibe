class_name Match3AnimationTuning
extends RefCounted

## Reads Ephemeral.match3.animation tuning (Unity Match3AnimationTuning parity).

const Match3GameSpeedScript = preload("res://game/match3/core/match3_game_speed.gd")

const POP_FALLBACK := 0.35
const POP_MIN := 0.06
const POP_MAX := 0.55
const REMOVE_GAP_FALLBACK := 0.4
const REMOVE_GAP_MIN := 0.05
const REMOVE_FALLBACK := 0.25
const REMOVE_MIN := 0.02
const ROUND_REWARD_STEP_PAUSE_FALLBACK := 0.45
const ROUND_REWARD_STEP_PAUSE_MIN := 0.05
const ROUND_REWARD_GLYPH_STAGGER_FALLBACK := 0.055
const ROUND_REWARD_GLYPH_STAGGER_MIN := 0.02
const FLOOR_TRIGGER_JUICE_FALLBACK := 0.39
const FLOOR_TRIGGER_JUICE_MIN := 0.08
const FLOOR_FLOAT_STAGGER_FALLBACK := 0.075
const FLOOR_FLOAT_STAGGER_MIN := 0.02
const INTER_STEP_DELAY_FALLBACK := 0.1
const INTER_STEP_DELAY_MIN := 0.02
const POST_SPAWN_DESTROY_DELAY_FALLBACK := 0.35
const POST_SPAWN_DESTROY_DELAY_MIN := 0.06
const FLOOR_POP_AFTER_DESTROY_DELAY_FALLBACK := 0.16
const FLOOR_POP_AFTER_DESTROY_DELAY_MIN := 0.03
const DESTROY_STEP_PAUSE_FALLBACK := 0.3
const DESTROY_STEP_PAUSE_MIN := 0.05
const CELL_FLOOR_FINALIZE_POP_FALLBACK := 0.68
const CELL_FLOOR_FINALIZE_HOLD_FALLBACK := 0.33
const CELL_FLOOR_FINALIZE_GAP_FALLBACK := 0.3


static func consumable_use_pop_duration(service) -> float:
	return _read_scaled_duration(service, "consumableUsePopDurationSeconds", POP_FALLBACK, POP_MIN)


static func consumable_use_remove_gap(service) -> float:
	return _read_scaled_duration(service, "consumableUseRemoveGapSeconds", REMOVE_GAP_FALLBACK, REMOVE_GAP_MIN)


static func consumable_use_remove_duration(service) -> float:
	return _read_scaled_duration(service, "consumableUseRemoveDurationSeconds", REMOVE_FALLBACK, REMOVE_MIN)


static func estimate_consumable_use_step_duration(service) -> float:
	return consumable_use_pop_duration(service) \
		+ consumable_use_remove_gap(service) \
		+ consumable_use_remove_duration(service)


static func destroy_animation_speed(service) -> float:
	return clampf(_read_float(service, "destroyAnimationSpeed", 1.0), 0.25, 4.0)


static func round_reward_step_pause_seconds(engine: GnosisEngine) -> float:
	return _scaled_for_engine(engine, ROUND_REWARD_STEP_PAUSE_FALLBACK, ROUND_REWARD_STEP_PAUSE_MIN)


static func round_reward_money_glyph_stagger_seconds(engine: GnosisEngine) -> float:
	return _scaled_for_engine(engine, ROUND_REWARD_GLYPH_STAGGER_FALLBACK, ROUND_REWARD_GLYPH_STAGGER_MIN)


static func floor_modifier_trigger_juice_duration(service) -> float:
	return _read_scaled_duration(
		service,
		"floorModifierTriggerJuiceDurationSeconds",
		FLOOR_TRIGGER_JUICE_FALLBACK,
		FLOOR_TRIGGER_JUICE_MIN
	)


static func floor_float_pop_stagger_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"floorFloatPopStaggerSeconds",
		FLOOR_FLOAT_STAGGER_FALLBACK,
		FLOOR_FLOAT_STAGGER_MIN
	)


static func inter_step_delay_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"interStepDelaySeconds",
		INTER_STEP_DELAY_FALLBACK,
		INTER_STEP_DELAY_MIN
	)


static func post_spawn_to_next_destroy_delay_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"postSpawnToNextDestroyDelaySeconds",
		POST_SPAWN_DESTROY_DELAY_FALLBACK,
		POST_SPAWN_DESTROY_DELAY_MIN
	)


static func floor_pop_after_destroy_delay_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"floorPopAfterDestroyDelaySeconds",
		FLOOR_POP_AFTER_DESTROY_DELAY_FALLBACK,
		FLOOR_POP_AFTER_DESTROY_DELAY_MIN
	)


static func destroy_step_pause_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"destroyStepPauseSeconds",
		DESTROY_STEP_PAUSE_FALLBACK,
		DESTROY_STEP_PAUSE_MIN
	)


static func cell_floor_finalize_pop_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"cellFloorFinalizePopDurationSeconds",
		CELL_FLOOR_FINALIZE_POP_FALLBACK,
		0.08
	)


static func cell_floor_finalize_hold_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"cellFloorFinalizeHoldDurationSeconds",
		CELL_FLOOR_FINALIZE_HOLD_FALLBACK,
		0.04
	)


static func cell_floor_finalize_gap_seconds(service) -> float:
	return _read_scaled_duration(
		service,
		"cellFloorFinalizeGapSeconds",
		CELL_FLOOR_FINALIZE_GAP_FALLBACK,
		0.02
	)


static func _read_scaled_duration(service, key: String, fallback: float, min_seconds: float) -> float:
	var base := maxf(0.0, _read_float(service, key, fallback))
	return Match3GameSpeedScript.scale_duration(_engine_from_service(service), base, min_seconds)


static func _scaled_for_engine(engine: GnosisEngine, base_seconds: float, min_seconds: float) -> float:
	return Match3GameSpeedScript.scale_duration(engine, maxf(0.0, base_seconds), min_seconds)


static func _engine_from_service(service) -> GnosisEngine:
	if service != null and service.context != null:
		return service.context.engine
	return null


static func _read_float(service, key: String, fallback: float) -> float:
	if service == null or not service.has_method("get_node"):
		return fallback
	var m3: GnosisNode = service.get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		return fallback
	var animation: GnosisNode = m3.get_node("animation")
	if not animation.is_valid() or animation.get_type() != GnosisValueType.OBJECT:
		return fallback
	var node: GnosisNode = animation.get_node(key)
	if not node.is_valid() or node.value == null:
		return fallback
	return float(node.value)
