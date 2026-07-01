extends SceneTree

## DestroyRandomCellFloorOnBoard clears one enhanced floor and returns coordinates.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")


func _initialize() -> void:
	print("--- Destroy Random Cell Floor Test ---")
	var ok := _run()
	print("--- Destroy Random Cell Floor Test %s ---" % ("Passed" if ok else "FAILED"))
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
	if match3 == null:
		print("[FAIL] Match3 missing")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_tiny_layout(), 99999, 20, 3, {"red": 10})
	gameplay.get_tile(1, 0).cell_floor_type_id = "Gold"

	var params := store.create_object()
	var result = match3.invoke_function("DestroyRandomCellFloorOnBoard", params)
	if not (result is GnosisFunctionResult) or not result.is_ok:
		print("[FAIL] invoke failed")
		return false
	if not bool(result.payload.get_node("success").value):
		print("[FAIL] destroy reported failure")
		return false
	if not gameplay.get_tile(1, 0).cell_floor_type_id.strip_edges().is_empty():
		print("[FAIL] floor not cleared")
		return false

	print("[SUCCESS] DestroyRandomCellFloorOnBoard cleared enhanced floor")
	return true


func _tiny_layout():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 1
	return layout
