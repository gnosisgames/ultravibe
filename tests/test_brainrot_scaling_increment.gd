extends SceneTree

## Brainrot should add base multi at finalize and sometimes bump brainrotProcTier.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")


func _initialize() -> void:
	print("--- Brainrot Scaling Increment Test ---")
	var ok := _run()
	print("--- Brainrot Scaling Increment Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	for seed in 256:
		if _try_seed(seed):
			print("[OK] Brainrot proc found with seed %d" % seed)
			return true
	print("[FAIL] no Brainrot tier proc in seed sweep")
	return false


func _try_seed(seed: int) -> bool:
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
	var activate = store.create_object()
	activate.set_key("boonId", "Brainrot")
	boon.invoke_function("ActivateBoon", activate)

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		return false
	var counters: GnosisNode = rows[0].get_node("properties").get_node("scaling").get_node("counters")
	var tier_before := SupportScript._node_int(counters, "brainrotProcTier", 0)

	if match3.has_method("configure_boon_score_rng"):
		match3.configure_boon_score_rng(seed)
	var gameplay = match3.get_gameplay()
	if gameplay != null:
		gameplay.configure_rng(seed)

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
	var results: Array = gameplay.process_move(Models.TileCoord.new(1, 0), Models.TileCoord.new(1, 1), {"red": 10})
	if results.is_empty():
		return false

	var saw_base_multi := false
	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if (
					str(step.get("boonId", "")).to_lower() == "brainrot"
					and str(step.get("calculationId", "")).to_lower() == "brainrot_scaling_mult"
					and int(step.get("multiDelta", 0)) >= 10
				):
					saw_base_multi = true
	if not saw_base_multi:
		return false

	var tier_after := SupportScript._node_int(counters, "brainrotProcTier", 0)
	return tier_after > tier_before


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
