extends SceneTree

## Griefing boon strips enhanced floors on scoring clear and banks scaling counter.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Griefing Floor Test ---")
	var ok := _run()
	print("--- Griefing Floor Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	var config := GnosisEngineConfig.new()
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.register_service("Configuration", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_configuration_service.gd"))
	config.register_service("Statistic", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_statistic_service.gd"))
	config.register_service("Seed", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_seed_service.gd"))
	config.register_service("Currency", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_currency_service.gd"))
	config.register_service("Boon", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_boon_service.gd"))
	config.register_service("Match3", GnosisLifetime.TRANSIENT, func(): return Match3ServiceScript.new())

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	if match3 == null or boon == null:
		print("[FAIL] services missing")
		return false

	var activate := store.create_object()
	activate.set_key("boonId", "Griefing")
	boon.invoke_function("ActivateBoon", activate)

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_tiny_layout(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	gameplay.get_tile(0, 0).cell_floor_type_id = "Gold"
	gameplay.get_tile(1, 0).item_id = "red"
	gameplay.get_tile(2, 0).item_id = "red"
	gameplay.get_tile(0, 0).item_id = "red"

	var results: Array = gameplay.process_move(Models.TileCoord.new(0, 0), Models.TileCoord.new(1, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	if not gameplay.get_tile(0, 0).cell_floor_type_id.strip_edges().is_empty():
		print("[FAIL] Griefing should clear enhanced floor on scoring cell")
		return false

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Griefing boon not equipped")
		return false
	var counter := SupportScript._node_int(
		rows[0].get_node("properties").get_node("scaling").get_node("counters"),
		"griefingEnhancedGriefedLifetime",
		0
	)
	if counter < 1:
		print("[FAIL] griefingEnhancedGriefedLifetime counter not incremented (%d)" % counter)
		return false

	print("[SUCCESS] Griefing cleared floor and banked counter=%d" % counter)
	return true


func _tiny_layout():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 1
	return layout
