class_name UltraAccessibilitySettings

## Persistent key for the accessibility toggle that controls bright gameplay
## flashes (line-clear white pop + hard-drop placement streak).
const LIGHT_FLASHES_ENABLED_KEY := "accessibility.lightFlashesEnabled"

static func light_flashes_enabled(engine: GnosisEngine, default_value: bool = true) -> bool:
	if engine == null or engine.state == null or not engine.state.is_valid():
		return default_value
	var node := engine.state.root.get_node("Persistent.%s" % LIGHT_FLASHES_ENABLED_KEY)
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return default_value
