extends SceneTree

## Verifies color-gate boss debuffs mark tiles disabled (zero score) and stay matchable.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")


func _initialize() -> void:
	print("--- Disable Color Block Test ---")
	var ok := _test_disable_purple_block()
	print("--- Disable Color Block Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _engine() -> GnosisEngine:
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
	tile.point_for_item = 10
	tile.multi_for_item = 1


func _test_disable_purple_block() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var params: GnosisNode = engine.store.create_object()
	params.set_key("effectId", "disable_purple_block")
	var apply_result = match3.invoke_function("ApplyEffect", params)
	if apply_result is GnosisFunctionResult and not apply_result.is_ok:
		print("[FAIL] ApplyEffect disable_purple_block: %s" % apply_result.error)
		return false

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 6, {"purple": 10, "red": 10, "blue": 10})
	match3.call("_sync_spawn_disabled_rules_to_board")

	var saw_disabled := false
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or tile.is_empty():
				continue
			if str(tile.item_id).to_lower() == "purple":
				if str(tile.item_type_id).to_lower() != "disabled":
					print("[FAIL] purple tile at (%d,%d) type=%s expected disabled" % [x, y, tile.item_type_id])
					return false
				if tile.point_for_item != 0 or tile.multi_for_item != 0:
					print("[FAIL] disabled purple still scores pts=%d multi=%d" % [tile.point_for_item, tile.multi_for_item])
					return false
				saw_disabled = true

	if not saw_disabled:
		print("[FAIL] no purple tiles on board to validate")
		return false

	# Disabled purples still match but contribute zero score.
	_setup_tile(gameplay, 0, 0, "purple")
	_setup_tile(gameplay, 1, 0, "purple")
	_setup_tile(gameplay, 2, 0, "purple")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "blue")
	gameplay.set_tile_item_type(0, 0, "disabled", {"purple": 10, "red": 10, "blue": 10})
	gameplay.set_tile_item_type(1, 0, "disabled", {"purple": 10, "red": 10, "blue": 10})
	gameplay.set_tile_item_type(2, 0, "disabled", {"purple": 10, "red": 10, "blue": 10})

	var results: Array = gameplay.process_move(
		Models.TileCoord.new(0, 1),
		Models.TileCoord.new(1, 1),
		{"purple": 10, "red": 10, "blue": 10}
	)
	if results.is_empty():
		print("[FAIL] expected scoring move with disabled purple row")
		return false
	var scoring = Models.last_scoring_match_result(results)
	if scoring == null:
		print("[FAIL] missing scoring step")
		return false
	if scoring.move_points_so_far != 0:
		print("[FAIL] disabled purple match scored points=%d" % scoring.move_points_so_far)
		return false

	print("[OK] disable_purple_block marks purple disabled with zero score")
	return true
