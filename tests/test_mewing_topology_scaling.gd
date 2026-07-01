extends SceneTree

## Mewing should bank match5+ topology on resolve_step and add scaling points at finalize.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Mewing Topology Scaling Test ---")
	var ok := _run()
	print("--- Mewing Topology Scaling Test %s ---" % ("Passed" if ok else "FAILED"))
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
	activate.set_key("boonId", "Mewing")
	boon.invoke_function("ActivateBoon", activate)

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Mewing not equipped")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for x in 6:
		_setup_tile(gameplay, x, 0, "red" if x != 4 else "blue")

	var score_before = gameplay.current_score
	var results: Array = gameplay.process_move(Models.TileCoord.new(4, 0), Models.TileCoord.new(5, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	var saw_topology5 := false
	var move_points := 0
	var saw_mewing_finalize := false
	for entry in results:
		if entry is Models.MatchResult:
			move_points = maxi(move_points, entry.move_points_so_far)
			if entry.matched_tiles.size() > 0:
				for topo in entry.topology_components:
					if int(topo.get("tileCount", 0)) >= 5:
						saw_topology5 = true
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "mewing"
					and str(step.get("calculationId", "")).to_lower() == "mewing_scaling_match5_points"
					and int(step.get("pointsDelta", 0)) >= 15
				):
					saw_mewing_finalize = true

	var counter := _read_mewing_counter(rows[0])
	var score_gain = gameplay.current_score - score_before
	var expected_score_gain = (5 * Models.DEFAULT_ITEM_POINTS + 15) * (5 * Models.DEFAULT_ITEM_MULTI)
	if not saw_topology5:
		print("[FAIL] expected match5+ topology component")
		return false
	if counter < 1:
		print("[FAIL] Mewing counter not incremented (got %d)" % counter)
		return false
	if score_gain < expected_score_gain:
		print(
			"[FAIL] expected score gain >= %d got %d (move_points=%d)"
			% [expected_score_gain, score_gain, move_points]
		)
		return false
	if not saw_mewing_finalize:
		print("[FAIL] missing Mewing finalize contribution step")
		return false

	print("[SUCCESS] Mewing scaled score_gain=%d counter=%d" % [score_gain, counter])
	return true


func _read_mewing_counter(slot_entry: GnosisNode) -> int:
	var scaling := slot_entry.get_node("properties").get_node("scaling")
	if not scaling.is_valid():
		return 0
	var counters := scaling.get_node("counters")
	if not counters.is_valid():
		return 0
	return SupportScript._node_int(counters, "match5PlusLifetime", 0)


func _layout():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 6
	layout.height = 1
	return layout


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
	tile.point_for_item = Models.DEFAULT_ITEM_POINTS
	tile.multi_for_item = Models.DEFAULT_ITEM_MULTI
