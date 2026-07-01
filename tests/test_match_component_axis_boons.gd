extends SceneTree

## Aura / Friendzoned / ClipIt / Cooked / FourthWall / SkillIssue axis match_component boons.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Match Component Axis Boons Test ---")
	var ok := (
		_test_friendzoned()
		and _test_aura()
		and _test_clipit()
		and _test_cooked()
		and _test_fourthwall()
		and _test_skill_issue()
	)
	print("--- Match Component Axis Boons Test %s ---" % ("Passed" if ok else "FAILED"))
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


func _test_friendzoned() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Friendzoned")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_3x2(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "green")
	var results: Array = gameplay.process_move(Models.TileCoord.new(1, 0), Models.TileCoord.new(1, 1), {"red": 10})
	if results.is_empty():
		print("[FAIL] Friendzoned: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "friendzoned"
					and str(step.get("calculationId", "")).to_lower() == "friendzoned_axis_match3_mult_resolve"
				):
					saw_step = true
	if move_multi < 3:
		print("[FAIL] Friendzoned: expected multi >= 3 got %d" % move_multi)
		return false
	if not saw_step:
		print("[FAIL] Friendzoned: missing boon_resolve_steps")
		return false
	print("[OK] Friendzoned multi=%d" % move_multi)
	return true


func _test_aura() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Aura")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_6x1(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for x in 6:
		_setup_tile(gameplay, x, 0, "red" if x != 4 else "blue")
	var results: Array = gameplay.process_move(Models.TileCoord.new(4, 0), Models.TileCoord.new(5, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] Aura: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "aura"
					and int(step.get("multiDelta", 0)) >= 32
				):
					saw_step = true
	if move_multi < 33:
		print("[FAIL] Aura: expected multi >= 33 got %d" % move_multi)
		return false
	if not saw_step:
		print("[FAIL] Aura: missing +32 multi resolve step")
		return false
	print("[OK] Aura multi=%d" % move_multi)
	return true


func _test_clipit() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "ClipIt")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_6x1(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for x in 6:
		_setup_tile(gameplay, x, 0, "red" if x != 4 else "blue")
	var results: Array = gameplay.process_move(Models.TileCoord.new(4, 0), Models.TileCoord.new(5, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] ClipIt: expected scoring move")
		return false
	var move_points := 0
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_points = maxi(move_points, entry.move_points_so_far)
			for step in entry.boon_resolve_steps:
				if str(step.get("boonId", "")).to_lower() == "clipit" and int(step.get("pointsDelta", 0)) >= 120:
					saw_step = true
	var expected := 5 * Models.DEFAULT_ITEM_POINTS + 120
	if move_points < expected:
		print("[FAIL] ClipIt: expected points >= %d got %d" % [expected, move_points])
		return false
	if not saw_step:
		print("[FAIL] ClipIt: missing +120 points resolve step")
		return false
	print("[OK] ClipIt points=%d" % move_points)
	return true


func _test_cooked() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "Cooked")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_5x1(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "red")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 3, 0, "blue")
	_setup_tile(gameplay, 4, 0, "red")
	var results: Array = gameplay.process_move(Models.TileCoord.new(3, 0), Models.TileCoord.new(4, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] Cooked: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if str(step.get("boonId", "")).to_lower() == "cooked":
					saw_step = true
	if move_multi < 4:
		print("[FAIL] Cooked: expected multi >= 4 got %d" % move_multi)
		return false
	if not saw_step:
		print("[FAIL] Cooked: missing x4 multi resolve step")
		return false
	print("[OK] Cooked multi=%d" % move_multi)
	return true


func _test_fourthwall() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "FourthWall")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_5x1(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "red")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 3, 0, "blue")
	_setup_tile(gameplay, 4, 0, "red")
	var results: Array = gameplay.process_move(Models.TileCoord.new(3, 0), Models.TileCoord.new(4, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] FourthWall: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "fourthwall"
					and int(step.get("multiDelta", 0)) >= 20
				):
					saw_step = true
	if move_multi < 24:
		print("[FAIL] FourthWall: expected multi >= 24 got %d" % move_multi)
		return false
	if not saw_step:
		print("[FAIL] FourthWall: missing +20 multi resolve step")
		return false
	print("[OK] FourthWall multi=%d" % move_multi)
	return true


func _test_skill_issue() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "SkillIssue")
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout_6x1(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	for x in 6:
		_setup_tile(gameplay, x, 0, "red" if x != 4 else "blue")
	var results: Array = gameplay.process_move(Models.TileCoord.new(4, 0), Models.TileCoord.new(5, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] SkillIssue: expected scoring move")
		return false
	var move_multi := 1
	var saw_step := false
	for entry in results:
		if entry is Models.MatchResult and entry.matched_tiles.size() > 0:
			move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if str(step.get("boonId", "")).to_lower() == "skillissue":
					saw_step = true
	if move_multi < 25:
		print("[FAIL] SkillIssue: expected multi >= 25 got %d" % move_multi)
		return false
	if not saw_step:
		print("[FAIL] SkillIssue: missing x5 multi resolve step")
		return false
	print("[OK] SkillIssue multi=%d" % move_multi)
	return true


func _layout_3x2():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 2
	return layout


func _layout_5x1():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 5
	layout.height = 1
	return layout


func _layout_6x1():
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
