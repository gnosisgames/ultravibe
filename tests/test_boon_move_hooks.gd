extends SceneTree

## Verifies Sprint 3 boon move hooks: Plot Armor shuffle counter and Rizz first-step multi.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const MoveHooksScript = preload("res://game/match3/boons/match3_boon_move_hooks.gd")


func _initialize() -> void:
	print("--- Boon Move Hooks Test ---")
	var ok := _run()
	print("--- Boon Move Hooks Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	if not _check_plot_armor_shuffle_counter():
		return false
	if not _check_rizz_first_step_multi():
		return false
	print("[SUCCESS] Plot Armor shuffle counter + Rizz first-step multi wired")
	return true


func _check_plot_armor_shuffle_counter() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "PlotArmor")
	boon.invoke_function("ActivateBoon", activate)

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] PlotArmor not equipped")
		return false

	var gameplay = match3.get_gameplay()
	gameplay.status = Models.STATUS_PLAYING
	if match3.has_method("add_manual_shuffles"):
		match3.add_manual_shuffles(1)

	var counters: GnosisNode = rows[0].get_node("properties").get_node("scaling").get_node("counters")
	var before := SupportScript._node_int(counters, MoveHooksScript.PLOT_ARMOR_SHUFFLES_USED_COUNTER_KEY, 0)

	match3.invoke_function("TryUseShuffle", store.create_object())
	var after := SupportScript._node_int(counters, MoveHooksScript.PLOT_ARMOR_SHUFFLES_USED_COUNTER_KEY, 0)
	if after != before + 1:
		print("[FAIL] PlotArmor counter before=%d after=%d" % [before, after])
		return false
	print("[OK] PlotArmor shuffle counter incremented")
	return true


func _check_rizz_first_step_multi() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Rizz")
	boon.invoke_function("ActivateBoon", activate)
	if not SupportScript.is_boon_catalog_id_equipped(match3, "Rizz"):
		print("[FAIL] Rizz not equipped")
		return false

	if match3.has_method("configure_boon_score_rng"):
		match3.configure_boon_score_rng(42)
	var gameplay = match3.get_gameplay()
	gameplay.configure_rng(42)
	gameplay.status = Models.STATUS_PLAYING

	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 2
	gameplay.load_level(layout, 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	_setup_tile(gameplay, 0, 0, "red")
	_setup_tile(gameplay, 1, 0, "blue")
	_setup_tile(gameplay, 2, 0, "red")
	_setup_tile(gameplay, 0, 1, "red")
	_setup_tile(gameplay, 1, 1, "red")
	_setup_tile(gameplay, 2, 1, "green")

	var results: Array = gameplay.process_move(
		Models.TileCoord.new(1, 0),
		Models.TileCoord.new(1, 1),
		{"red": 10, "blue": 10, "green": 10}
	)
	if results.is_empty():
		print("[FAIL] Rizz test move produced no results")
		return false

	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_resolve_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "rizz"
					and str(step.get("calculationId", "")).to_lower() == MoveHooksScript.RIZZ_CALCULATION_ID
					and int(step.get("multiDelta", 0)) > 0
				):
					print("[OK] Rizz first-step multi bonus recorded")
					return true

	print("[FAIL] Rizz resolve step missing")
	return false


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


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
