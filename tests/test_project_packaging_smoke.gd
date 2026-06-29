extends SceneTree

## Lightweight export-readiness guard for the Godot project settings/resources.
## It does not require platform export templates or export_presets.cfg.

const UltraInputActions = preload("res://game/input/ultra_input_actions.gd")

const REQUIRED_FILES := [
	"res://project.godot",
	"res://main.tscn",
	"res://addons/com.gnosisgames.gnosisengine/plugin.cfg",
	"res://data/configuration.json",
	"res://data/persistent.json",
	"res://data/asset_registry.json",
]

const REQUIRED_ACTIONS: Array[String] = UltraInputActions.ALL_ACTION_NAMES

func _initialize() -> void:
	print("--- Project Packaging Smoke Test ---")
	var ok := _run()
	print("--- Project Packaging Smoke Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _run() -> bool:
	var ok := true
	UltraInputActions.ensure_input_map()
	ok = _expect_project_setting("application/config/name", "Ultravibe") and ok
	ok = _expect_project_setting("application/run/main_scene", "res://main.tscn") and ok
	ok = _expect_file(ProjectSettings.get_setting("gui/theme/custom", "")) and ok

	for path in REQUIRED_FILES:
		ok = _expect_file(path) and ok

	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if ResourceLoader.load(main_scene_path) == null:
		print("[FAIL] main scene could not load: %s" % main_scene_path)
		ok = false
	else:
		print("[SUCCESS] main scene loads")

	for action_name in REQUIRED_ACTIONS:
		if not InputMap.has_action(action_name):
			print("[FAIL] missing InputMap action: %s" % action_name)
			ok = false
		elif InputMap.action_get_events(action_name).is_empty():
			print("[FAIL] InputMap action has no events: %s" % action_name)
			ok = false
	if ok:
		print("[SUCCESS] project settings and required resources are export-ready")
	return ok

func _expect_project_setting(key: String, expected: String) -> bool:
	var actual := str(ProjectSettings.get_setting(key, ""))
	if actual != expected:
		print("[FAIL] project setting %s expected %s, got %s" % [key, expected, actual])
		return false
	print("[SUCCESS] project setting %s = %s" % [key, expected])
	return true

func _expect_file(path_value) -> bool:
	var path := str(path_value)
	if path.strip_edges().is_empty():
		print("[FAIL] required path is empty")
		return false
	if not FileAccess.file_exists(path):
		print("[FAIL] missing required file: %s" % path)
		return false
	print("[SUCCESS] required file exists: %s" % path)
	return true
