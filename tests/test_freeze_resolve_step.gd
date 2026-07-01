extends SceneTree

## Freeze boon should add +4 multi per cold palette tile destroyed during resolve_step.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Freeze Resolve Step Test ---")
	var ok := _run()
	print("--- Freeze Resolve Step Test %s ---" % ("Passed" if ok else "FAILED"))
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
	activate.set_key("boonId", "Freeze")
	boon.invoke_function("ActivateBoon", activate)

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Freeze not equipped")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.load_level(_layout(), 99999, 20, 3, {"green": 10, "blue": 10, "red": 10})
	_setup_tile(gameplay, 0, 0, "green")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "green")
	_setup_tile(gameplay, 0, 1, "green")
	_setup_tile(gameplay, 1, 1, "green")
	_setup_tile(gameplay, 2, 1, "red")

	var results: Array = gameplay.process_move(Models.TileCoord.new(1, 0), Models.TileCoord.new(1, 1), {"green": 10})
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	var move_multi := 0
	var saw_freeze_step := false
	for entry in results:
		if entry is Models.MatchResult:
			if entry.matched_tiles.size() > 0:
				move_multi = maxi(move_multi, entry.move_multi_so_far)
			for step in entry.boon_resolve_steps:
				if str(step.get("boonId", "")).to_lower() == "freeze" and int(step.get("multiDelta", 0)) > 0:
					saw_freeze_step = true

	var expected_gem_multi := 3 * Models.DEFAULT_ITEM_MULTI
	var expected_freeze_multi := 3 * 4
	var expected_total := expected_gem_multi + expected_freeze_multi
	if move_multi < expected_total:
		print(
			"[FAIL] Freeze multi too low: got %d expected >= %d (gems=%d freeze=%d)"
			% [move_multi, expected_total, expected_gem_multi, expected_freeze_multi]
		)
		return false

	if not saw_freeze_step:
		print("[FAIL] missing Freeze boon_resolve_steps entry")
		return false

	print("[SUCCESS] Freeze added multi total=%d" % move_multi)
	return true


func _layout():
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
	tile.point_for_item = Models.DEFAULT_ITEM_POINTS
	tile.multi_for_item = Models.DEFAULT_ITEM_MULTI
