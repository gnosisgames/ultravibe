extends SceneTree

## OffGrid publishes board cell count; Glitch random mult varies per move (Unity parity).

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const BoonScoreScript = preload("res://game/match3/boons/match3_boon_score.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Boon Glitch/OffGrid Test ---")
	var ok := _run()
	print("--- Boon Glitch/OffGrid Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	if not _check_board_cells_count_published():
		return false
	if not _check_offgrid_finalize_points():
		return false
	if not _check_glitch_mult_varies_by_move():
		return false
	print("[SUCCESS] Glitch + OffGrid boon score calculations")
	return true


func _check_board_cells_count_published() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var gameplay = match3.get_gameplay()
	gameplay.width = 6
	gameplay.height = 7
	if match3.has_method("_publish_ephemeral_state"):
		match3._publish_ephemeral_state()
	var m3 := engine.state.root.get_node("Ephemeral").get_node("match3")
	var count := SupportScript._node_int(m3, "boardCellsCount", -1)
	if count != 42:
		print("[FAIL] boardCellsCount expected 42 got %d" % count)
		return false
	print("[OK] boardCellsCount published")
	return true


func _check_offgrid_finalize_points() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Offgrid")
	boon.invoke_function("ActivateBoon", activate)
	if not SupportScript.is_boon_catalog_id_equipped(match3, "Offgrid"):
		print("[FAIL] Offgrid not equipped")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.width = 8
	gameplay.height = 8
	gameplay.moves_performed = 1
	match3._publish_ephemeral_state()

	var runtime = match3._boon_runtime
	var score: Match3BoonScore = runtime._score
	var results := _minimal_results()
	var out := score.apply_finalize_for_move(results, 10, 1)
	var points := int(out.get("points", 0))
	if points != 10 + 64:
		print("[FAIL] Offgrid finalize points expected 74 got %d" % points)
		return false
	print("[OK] Offgrid adds board cell count to points")
	return true


func _check_glitch_mult_varies_by_move() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Glitch")
	boon.invoke_function("ActivateBoon", activate)
	if not SupportScript.is_boon_catalog_id_equipped(match3, "Glitch"):
		print("[FAIL] Glitch not equipped")
		return false

	match3.configure_boon_score_rng(99)
	var gameplay = match3.get_gameplay()
	gameplay.width = 8
	gameplay.height = 8
	var runtime = match3._boon_runtime
	var score: Match3BoonScore = runtime._score
	var results := _minimal_results()

	gameplay.moves_performed = 1
	var out1 := score.apply_finalize_for_move(results, 0, 1)
	var multi1 := int(out1.get("multi", 1))

	gameplay.moves_performed = 2
	var out2 := score.apply_finalize_for_move(results, 0, multi1)
	var multi2 := int(out2.get("multi", 1))

	var delta1 := multi1 - 1
	var delta2 := multi2 - multi1
	if delta1 < 1 or delta1 > 23:
		print("[FAIL] Glitch move 1 mult delta out of range: +%d" % delta1)
		return false
	if delta2 < 1 or delta2 > 23:
		print("[FAIL] Glitch move 2 mult delta out of range: +%d" % delta2)
		return false
	if delta1 == delta2:
		print("[FAIL] Glitch gave same mult delta on consecutive moves: +%d" % delta1)
		return false
	print("[OK] Glitch random mult varies per move (%d then +%d)" % [delta1, delta2])
	return true


func _minimal_results() -> Array:
	var step := Models.MatchResult.new()
	step.matched_tiles = [Models.TileCoord.new(0, 0)]
	return [step]


func _boot_engine() -> GnosisEngine:
	var config := GnosisEngineConfig.new()
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.register_service("Configuration", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_configuration_service.gd"))
	config.register_service("Statistic", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_statistic_service.gd"))
	config.register_service("Seed", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_seed_service.gd"))
	config.register_service("Currency", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_currency_service.gd"))
	config.register_service("Boon", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_boon_service.gd"))
	config.register_service("Consumable", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_consumable_service.gd"))
	config.register_service("Match3", GnosisLifetime.TRANSIENT, func(): return Match3ServiceScript.new())

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()
	return engine
