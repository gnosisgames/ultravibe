extends SceneTree

## Block boon should add +80 points for a match-4 axis line via match_component trigger.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Block Match Component Test ---")
	var ok := _run()
	print("--- Block Match Component Test %s ---" % ("Passed" if ok else "FAILED"))
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
	activate.set_key("boonId", "Block")
	boon.invoke_function("ActivateBoon", activate)
	if SupportScript.get_active_boon_inventory_slot_rows(match3).is_empty():
		print("[FAIL] Block not equipped")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "red")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 3, 0, "blue")
	_setup_tile(gameplay, 4, 0, "red")

	var results: Array = gameplay.process_move(Models.TileCoord.new(3, 0), Models.TileCoord.new(4, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	var move_points := 0
	var saw_block_step := false
	var saw_match4_topo := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_points = maxi(move_points, entry.move_points_so_far)
			for topo in entry.topology_components:
				if int(topo.get("maxHorizontalRun", 0)) >= 4 or int(topo.get("maxVerticalRun", 0)) >= 4:
					saw_match4_topo = true
			for step in entry.boon_resolve_steps:
				if str(step.get("boonId", "")).to_lower() == "block" and int(step.get("pointsDelta", 0)) >= 80:
					saw_block_step = true

	if not saw_match4_topo:
		print("[FAIL] expected match-4 topology component")
		return false

	var expected_total := 4 * Models.DEFAULT_ITEM_POINTS + 80
	if move_points < expected_total:
		print("[FAIL] Block points too low: got %d expected >= %d" % [move_points, expected_total])
		return false
	if not saw_block_step:
		print("[FAIL] missing Block boon_resolve_steps entry")
		return false

	print("[SUCCESS] Block added points total=%d" % move_points)
	return true


func _layout():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 5
	layout.height = 1
	return layout


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
	tile.point_for_item = Models.DEFAULT_ITEM_POINTS
	tile.multi_for_item = Models.DEFAULT_ITEM_MULTI
