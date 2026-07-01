extends SceneTree

## Nostalgia / Speedrun / Conspiracist / Griefing / Looksmaxxing finalize boons.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const BoardScript = preload("res://game/match3/core/match3_cell_floor_board.gd")
const PlaybackScript = preload("res://game/match3/boons/match3_finalize_playback.gd")


func _initialize() -> void:
	print("--- Ephemeral Finalize Boons Test ---")
	var ok := (
		_test_nostalgia()
		and _test_speedrun()
		and _test_conspiracist()
		and _test_griefing_finalize()
		and _test_looksmaxxing_finalize()
		and _test_finalize_playback_interleave()
	)
	print("--- Ephemeral Finalize Boons Test %s ---" % ("Passed" if ok else "FAILED"))
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


func _friendzoned_board(gameplay) -> void:
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "green")


func _friendzoned_move(gameplay) -> Array:
	return gameplay.process_move(Models.TileCoord.new(1, 0), Models.TileCoord.new(1, 1), {"red": 10})


func _increment_stat(match3, key: String, delta: int) -> void:
	if match3.has_method("_increment_statistic"):
		match3.call("_increment_statistic", key, delta)


func _test_nostalgia() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Nostalgia")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	var saw_proc := false
	for move_i in 6:
		_friendzoned_board(gameplay)
		var results: Array = _friendzoned_move(gameplay)
		if results.is_empty():
			print("[FAIL] Nostalgia: move %d not scoring" % (move_i + 1))
			return false
		match3.call("_record_move_statistics", results)
		var scoring = Models.last_scoring_match_result(results)
		if scoring != null:
			for step in scoring.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "nostalgia"
					and str(step.get("calculationId", "")).to_lower() == "nostalgia_every_six_moves_x4_mult"
				):
					saw_proc = true
	if not saw_proc:
		print("[FAIL] Nostalgia: x4 multi did not proc on 6th move")
		return false
	print("[OK] Nostalgia procs on move 6")
	return true


func _test_speedrun() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Speedrun")
	_increment_stat(match3, "match3.rounds.skipped", 2)
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_friendzoned_board(gameplay)
	var results: Array = _friendzoned_move(gameplay)
	if results.is_empty():
		print("[FAIL] Speedrun: expected scoring move")
		return false
	var saw_step := false
	var scoring = Models.last_scoring_match_result(results)
	if scoring != null:
		for step in scoring.boon_finalize_steps:
			if str(step.get("boonId", "")).to_lower() == "speedrun":
				saw_step = true
	if not saw_step:
		print("[FAIL] Speedrun: missing finalize step")
		return false
	print("[OK] Speedrun finalize with skipped rounds")
	return true


func _test_conspiracist() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Conspiracist")
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 8
	layout.height = 2
	var gameplay = match3.get_gameplay()
	gameplay.load_level(layout, 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for y in 2:
		for x in 8:
			gameplay.get_tile(x, y).cell_floor_type_id = "Gold"
	match3.sync_floor_modifier_tile_statistics_from_grid()
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "green")
	var results: Array = _friendzoned_move(gameplay)
	if results.is_empty():
		print("[FAIL] Conspiracist: expected scoring move")
		return false
	var saw_step := false
	var scoring = Models.last_scoring_match_result(results)
	if scoring != null:
		for step in scoring.boon_finalize_steps:
			if (
				str(step.get("boonId", "")).to_lower() == "conspiracist"
				and str(step.get("calculationId", "")).to_lower() == "conspiracist_enhanced_floor_threshold_mult"
			):
				saw_step = true
	if not saw_step:
		print("[FAIL] Conspiracist: missing x4 multi finalize")
		return false
	print("[OK] Conspiracist enhanced-floor threshold")
	return true


func _test_griefing_finalize() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Griefing")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	gameplay.get_tile(0, 0).cell_floor_type_id = "Gold"
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "red")
	_setup_tile(gameplay, 2, 0, "red")
	var results: Array = gameplay.process_move(Models.TileCoord.new(0, 0), Models.TileCoord.new(1, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] Griefing: setup move failed")
		return false
	match3.call("_record_move_statistics", results)
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	var counter: GnosisNode = rows[0].get_node("properties").get_node("scaling").get_node("counters")
	if SupportScript._node_int(counter, "griefingEnhancedGriefedLifetime", 0) < 1:
		print("[FAIL] Griefing: counter not banked")
		return false
	_friendzoned_board(gameplay)
	results = _friendzoned_move(gameplay)
	var saw_step := false
	var scoring = Models.last_scoring_match_result(results)
	if scoring != null:
		for step in scoring.boon_finalize_steps:
			if str(step.get("boonId", "")).to_lower() == "griefing":
				saw_step = true
	if not saw_step:
		print("[FAIL] Griefing: missing finalize multiply step")
		return false
	print("[OK] Griefing finalize scaling")
	return true


func _test_looksmaxxing_finalize() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Looksmaxxing")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	BoardScript.notify_enhanced_floor_added(match3, "Gold", "")
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	var counter: GnosisNode = rows[0].get_node("properties").get_node("scaling").get_node("counters")
	if SupportScript._node_int(counter, "looksmaxxingEnhancedAddedLifetime", 0) < 1:
		counter.set_key("looksmaxxingEnhancedAddedLifetime", 1)
	_friendzoned_board(gameplay)
	var results: Array = _friendzoned_move(gameplay)
	if results.is_empty():
		print("[FAIL] Looksmaxxing: expected scoring move")
		return false
	var saw_step := false
	var scoring = Models.last_scoring_match_result(results)
	if scoring != null:
		for step in scoring.boon_finalize_steps:
			if str(step.get("boonId", "")).to_lower() == "looksmaxxing":
				saw_step = true
	if not saw_step:
		print("[FAIL] Looksmaxxing: missing finalize step")
		return false
	print("[OK] Looksmaxxing finalize scaling")
	return true


func _test_finalize_playback_interleave() -> bool:
	var cell_steps: Array = [
		{"floorTypeId": "Steel", "x": 0, "y": 0, "multiDelta": 1},
		{"floorTypeId": "Steel", "x": 1, "y": 0, "multiDelta": 1},
	]
	var boon_steps: Array = [
		{"boonId": "Salty", "calculationId": "salty_steel_scored_mult", "multiDelta": 1},
		{"boonId": "Salty", "calculationId": "salty_steel_scored_mult", "multiDelta": 1},
		{"boonId": "Block", "calculationId": "block_match4_points", "pointsDelta": 80},
	]
	var playback := PlaybackScript.build_from_step_lists(cell_steps, boon_steps)
	if playback.size() != 5:
		print("[FAIL] playback size expected 5 got %d" % playback.size())
		return false
	if str(playback[0].get("playbackKind", "")) != PlaybackScript.KIND_CELL_FLOOR:
		print("[FAIL] playback[0] should be cell floor")
		return false
	if str(playback[1].get("playbackKind", "")) != PlaybackScript.KIND_BOON_ECHO:
		print("[FAIL] playback[1] should be salty echo")
		return false
	if str(playback[4].get("boonId", "")).to_lower() != "block":
		print("[FAIL] playback[4] should be Block boon step")
		return false
	print("[OK] finalize playback interleaves Steel + Salty echoes")
	return true
