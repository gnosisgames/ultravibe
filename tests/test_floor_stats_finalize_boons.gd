extends SceneTree

## DeepDive / Superhero finalize calcs read live floor-modifier tile statistics.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")


func _initialize() -> void:
	print("--- Floor Stats Finalize Boons Test ---")
	var ok := _test_deepdive() and _test_superhero()
	print("--- Floor Stats Finalize Boons Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _engine():
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
	return engine


func _activate(boon, store, boon_id: String) -> void:
	var req = store.create_object()
	req.set_key("boonId", boon_id)
	boon.invoke_function("ActivateBoon", req)


func _layout_3x2():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 2
	return layout


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"


func _friendzoned_move(gameplay) -> Array:
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "green")
	return gameplay.process_move(Models.TileCoord.new(1, 0), Models.TileCoord.new(1, 1), {"red": 10})


func _test_deepdive() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "DeepDive")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	gameplay.get_tile(0, 0).cell_floor_type_id = "BonusPoints"
	gameplay.get_tile(2, 0).cell_floor_type_id = "BonusPoints"
	match3.sync_floor_modifier_tile_statistics_from_grid()
	var score_before = gameplay.current_score
	var results: Array = _friendzoned_move(gameplay)
	if results.is_empty():
		print("[FAIL] DeepDive: expected scoring move")
		return false
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "deepdive"
					and int(step.get("pointsDelta", 0)) >= 40
				):
					saw_step = true
	var score_gain = gameplay.current_score - score_before
	if not saw_step and score_gain < 40:
		print("[FAIL] DeepDive: expected +40 finalize points, gain=%d" % score_gain)
		return false
	print("[OK] DeepDive score_gain=%d" % score_gain)
	return true


func _test_superhero() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Superhero")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	gameplay.get_tile(0, 0).cell_floor_type_id = "Steel"
	gameplay.get_tile(2, 0).cell_floor_type_id = "Steel"
	match3.sync_floor_modifier_tile_statistics_from_grid()
	var results: Array = _friendzoned_move(gameplay)
	if results.is_empty():
		print("[FAIL] Superhero: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	var superhero_multi_delta := 0
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_finalize_steps:
				if str(step.get("boonId", "")).to_lower() == "superhero":
					saw_step = true
					superhero_multi_delta = maxi(superhero_multi_delta, int(step.get("multiDelta", 0)))
	if not saw_step:
		print("[FAIL] Superhero: missing finalize step")
		return false
	if superhero_multi_delta <= 0 and move_multi < 6:
		print("[FAIL] Superhero: expected finalize multi boost (delta=%d move_multi=%d)" % [superhero_multi_delta, move_multi])
		return false
	print("[OK] Superhero multi_delta=%d move_multi=%d" % [superhero_multi_delta, move_multi])
	return true
