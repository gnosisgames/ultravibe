extends RefCounted

## Headless test setup for opt-in mod loading (fixtures + per-mod enable).

const Bridge := preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_mod_loader_bridge.gd")

const FIXTURE_ROOT := "res://tests/fixtures/mods"
const DEMO_MOD_ID := "gnosis_demo"


static func prepare_enabled_demo_mod() -> void:
	ProjectSettings.set_setting("gnosis/mods/root_path", FIXTURE_ROOT)
	Bridge.set_gnosis_mod_enabled(DEMO_MOD_ID, true)
