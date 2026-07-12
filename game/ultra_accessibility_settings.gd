class_name UltraAccessibilitySettings

const GnosisAccessibilitySettings = preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/widgets/gnosis_accessibility_settings.gd")

const LIGHT_FLASHES_ENABLED_KEY := GnosisAccessibilitySettings.LIGHT_FLASHES_ENABLED_KEY
const SCREEN_SHAKE_ENABLED_KEY := GnosisAccessibilitySettings.SCREEN_SHAKE_ENABLED_KEY
const READABLE_FONT_ENABLED_KEY := GnosisAccessibilitySettings.READABLE_FONT_ENABLED_KEY

static func light_flashes_enabled(engine: GnosisEngine, default_value: bool = true) -> bool:
	return GnosisAccessibilitySettings.light_flashes_enabled(engine, default_value)

static func screen_shake_enabled(engine: GnosisEngine, default_value: bool = true) -> bool:
	return GnosisAccessibilitySettings.screen_shake_enabled(engine, default_value)

static func readable_font_enabled(engine: GnosisEngine, default_value: bool = false) -> bool:
	return GnosisAccessibilitySettings.readable_font_enabled(engine, default_value)

static func apply_readable_fonts(tree: SceneTree, engine: GnosisEngine) -> void:
	GnosisAccessibilitySettings.apply_ui_fonts(tree, engine)
