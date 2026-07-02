class_name Match3GameSpeed
extends RefCounted

## Scales match3 presentation timings by Persistent.settings.gameSpeed (Unity parity).

const MIN_SPEED := 1
const MAX_SPEED := 4
const DEFAULT_SPEED := 1


static func read_clamped_speed(engine: GnosisEngine) -> int:
	if engine == null or engine.state == null or not engine.state.root.is_valid():
		return DEFAULT_SPEED
	var settings := engine.state.root.get_node("Persistent.settings")
	if not settings.is_valid():
		return DEFAULT_SPEED
	var node := settings.get_node("gameSpeed")
	if not node.is_valid() or node.value == null:
		return DEFAULT_SPEED
	return clampi(int(node.value), MIN_SPEED, MAX_SPEED)


static func scale_duration(
	engine: GnosisEngine,
	base_duration_seconds: float,
	min_duration_seconds: float = 0.0,
) -> float:
	var speed := read_clamped_speed(engine)
	var safe_base := maxf(0.0, base_duration_seconds)
	var scaled := safe_base / float(speed) if speed > MIN_SPEED else safe_base
	return maxf(maxf(0.0, min_duration_seconds), scaled)
