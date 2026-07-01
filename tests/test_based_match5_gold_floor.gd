extends SceneTree

## Based should place Gold floors on cells cleared by a straight horizontal match-5.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const TopologyScript = preload("res://game/match3/core/match3_match_topology.gd")


func _initialize() -> void:
	print("--- Based Match5 Gold Floor Test ---")
	var ok := _run()
	print("--- Based Match5 Gold Floor Test %s ---" % ("Passed" if ok else "FAILED"))
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

	var activate = store.create_object()
	activate.set_key("boonId", "Based")
	boon.invoke_function("ActivateBoon", activate)

	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 6
	layout.height = 1

	var gameplay = match3.get_gameplay()
	gameplay.load_level(layout, 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for x in 6:
		var tile = gameplay.get_tile(x, 0)
		tile.item_id = "red" if x != 4 else "blue"
		tile.item_kind = Models.KIND_NORMAL
		tile.item_type_id = "plain"

	var results: Array = gameplay.process_move(
		Models.TileCoord.new(4, 0),
		Models.TileCoord.new(5, 0),
		{"red": 10}
	)
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	var saw_match5 := false
	var saw_placements := false
	for entry in results:
		if not (entry is Models.MatchResult) or entry.matched_tiles.is_empty():
			continue
		for topo in entry.topology_components:
			if str(topo.get("shapeKind", "")) == TopologyScript.SHAPE_H5:
				saw_match5 = true
		if entry.floor_cells_placed.size() >= 5:
			saw_placements = true
			for placement in entry.floor_cells_placed:
				if str(placement.get("cellFloorTypeId", "")).to_lower() != "gold":
					print("[FAIL] unexpected floor type: %s" % str(placement.get("cellFloorTypeId", "")))
					return false

	var gold_count := 0
	for x in 6:
		var floor_id: String = gameplay.get_tile(x, 0).cell_floor_type_id.strip_edges()
		if floor_id.to_lower() == "gold":
			gold_count += 1

	if not saw_match5:
		print("[FAIL] missing horizontal match-5 topology")
		return false
	if gold_count < 5:
		print("[FAIL] expected 5 Gold floors on board, got %d" % gold_count)
		return false
	if not saw_placements:
		print("[FAIL] missing floor_cells_placed on match result")
		return false
	print("[OK] Based placed %d Gold floors" % gold_count)
	return true
