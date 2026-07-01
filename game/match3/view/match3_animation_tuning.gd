class_name Match3AnimationTuning
extends RefCounted

## Reads Ephemeral.match3.animation tuning (Unity Match3AnimationTuning parity).

const POP_FALLBACK := 0.35
const POP_MIN := 0.06
const POP_MAX := 0.55
const REMOVE_GAP_FALLBACK := 0.4
const REMOVE_GAP_MIN := 0.05
const REMOVE_FALLBACK := 0.25
const REMOVE_MIN := 0.02


static func consumable_use_pop_duration(service) -> float:
	return clampf(_read_float(service, "consumableUsePopDurationSeconds", POP_FALLBACK), POP_MIN, POP_MAX)


static func consumable_use_remove_gap(service) -> float:
	return maxf(REMOVE_GAP_MIN, _read_float(service, "consumableUseRemoveGapSeconds", REMOVE_GAP_FALLBACK))


static func consumable_use_remove_duration(service) -> float:
	return maxf(REMOVE_MIN, _read_float(service, "consumableUseRemoveDurationSeconds", REMOVE_FALLBACK))


static func estimate_consumable_use_step_duration(service) -> float:
	return consumable_use_pop_duration(service) \
		+ consumable_use_remove_gap(service) \
		+ consumable_use_remove_duration(service)


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
