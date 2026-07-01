extends SceneTree

## Copypasta / EchoChamber / Opa should proc when two axis match-3 components clear on one move.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Double Match3 Finalize Boons Test ---")
	var ok := (
		_test_copypasta()
		and _test_echo_chamber()
		and _test_opa()
	)
	print("--- Double Match3 Finalize Boons Test %s ---" % ("Passed" if ok else "FAILED"))
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


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"


func _setup_double_match3_board(gameplay) -> void:
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 5
	layout.height = 5
	gameplay.load_level(layout, 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	var cells := [
		[0,0,"green"],[1,0,"blue"],[2,0,"green"],[3,0,"blue"],[4,0,"blue"],
		[0,1,"red"],[1,1,"blue"],[2,1,"blue"],[3,1,"red"],[4,1,"red"],
		[0,2,"green"],[1,2,"red"],[2,2,"blue"],[3,2,"red"],[4,2,"blue"],
		[0,3,"blue"],[1,3,"blue"],[2,3,"red"],[3,3,"red"],[4,3,"green"],
		[0,4,"red"],[1,4,"blue"],[2,4,"green"],[3,4,"green"],[4,4,"green"],
	]
	for cell in cells:
		_setup_tile(gameplay, int(cell[0]), int(cell[1]), str(cell[2]))


func _run_double_match3_move(gameplay) -> Array:
	return gameplay.process_move(
		Models.TileCoord.new(3, 0),
		Models.TileCoord.new(3, 1),
		{"red": 10, "blue": 10, "green": 10}
	)


func _count_axis_match3_components(results: Array) -> int:
	var count := 0
	for entry in results:
		if not (entry is Models.MatchResult) or entry.matched_tiles.is_empty():
			continue
		for topo in entry.topology_components:
			var kind := str(topo.get("shapeKind", ""))
			if kind.ends_with("_three"):
				count += 1
	return count


func _test_copypasta() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Copypasta")
	var gameplay = match3.get_gameplay()
	_setup_double_match3_board(gameplay)
	var score_before = gameplay.current_score
	var results: Array = _run_double_match3_move(gameplay)
	if results.is_empty():
		print("[FAIL] Copypasta: expected scoring move")
		return false
	if _count_axis_match3_components(results) < 2:
		print("[FAIL] Copypasta: expected two axis match-3 components")
		return false
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "copypasta"
					and str(step.get("calculationId", "")).to_lower() == "copypasta_two_match3_bonus_multi"
					and int(step.get("multiDelta", 0)) >= 12
				):
					saw_step = true
	var score_gain = gameplay.current_score - score_before
	if not saw_step and score_gain < 12:
		print("[FAIL] Copypasta: missing +12 multi finalize (gain=%d)" % score_gain)
		return false
	print("[OK] Copypasta score_gain=%d" % score_gain)
	return true


func _test_echo_chamber() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "EchoChamber")
	var gameplay = match3.get_gameplay()
	_setup_double_match3_board(gameplay)
	var score_before = gameplay.current_score
	var results: Array = _run_double_match3_move(gameplay)
	if results.is_empty():
		print("[FAIL] EchoChamber: expected scoring move")
		return false
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "echochamber"
					and str(step.get("calculationId", "")).to_lower() == "echo_chamber_two_straight_match3_points"
					and int(step.get("pointsDelta", 0)) >= 80
				):
					saw_step = true
	var score_gain = gameplay.current_score - score_before
	if not saw_step and score_gain < 80:
		print("[FAIL] EchoChamber: missing +80 points finalize (gain=%d)" % score_gain)
		return false
	print("[OK] EchoChamber score_gain=%d" % score_gain)
	return true


func _test_opa() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Opa")
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Opa: not equipped")
		return false
	var gameplay = match3.get_gameplay()
	_setup_double_match3_board(gameplay)
	var counter_before := SupportScript._node_int(
		rows[0].get_node("properties").get_node("scaling").get_node("counters"),
		"opaDoubleMatch3Lifetime",
		0
	)
	var score_before = gameplay.current_score
	var results: Array = _run_double_match3_move(gameplay)
	if results.is_empty():
		print("[FAIL] Opa: expected scoring move")
		return false
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "opa"
					and str(step.get("calculationId", "")).to_lower() == "opa_double_match3_scaling_multi"
					and int(step.get("multiDelta", 0)) >= 2
				):
					saw_step = true
	var counter_after := SupportScript._node_int(
		rows[0].get_node("properties").get_node("scaling").get_node("counters"),
		"opaDoubleMatch3Lifetime",
		0
	)
	var score_gain = gameplay.current_score - score_before
	if counter_after <= counter_before:
		print("[FAIL] Opa: counter did not increment (%d -> %d)" % [counter_before, counter_after])
		return false
	if not saw_step and score_gain < 2:
		print("[FAIL] Opa: missing +2 multi finalize (gain=%d)" % score_gain)
		return false
	print("[OK] Opa counter=%d score_gain=%d" % [counter_after, score_gain])
	return true
