extends SceneTree

## Verifies boon flavor runtime: positive score trigger, perishable round end, Ghost capacity.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const FlavorsScript = preload("res://game/match3/boons/match3_boon_flavors.gd")
const EngineFlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")


func _initialize() -> void:
	print("--- Boon Flavors Test ---")
	var ok := _run()
	print("--- Boon Flavors Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	if not _check_positive_flavor_score_trigger():
		return false
	if not _check_perishable_round_end():
		return false
	if not _check_ghost_capacity_exemption():
		return false
	print("[SUCCESS] Positive flavor, perishable, and Ghost capacity wired")
	return true


func _check_positive_flavor_score_trigger() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Brainrot")
	boon.invoke_function("ActivateBoon", activate)
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Brainrot not equipped for flavor test")
		return false
	rows[0].get_node("properties").set_key("positiveFlavorId", "BonusPoints")

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
		print("[FAIL] flavor test move produced no results")
		return false

	for entry in results:
		if entry is Models.MatchResult:
			for step in entry.boon_finalize_steps:
				if str(step.get("calculationId", "")).to_lower() == "flavor_bonuspoints_score_trigger":
					print("[OK] BonusPoints positive flavor triggered on score step")
					return true
	print("[FAIL] BonusPoints flavor score trigger missing")
	return false


func _check_perishable_round_end() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Rizz")
	boon.invoke_function("ActivateBoon", activate)
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Rizz not equipped for perishable test")
		return false
	rows[0].get_node("properties").set_key("flavorRoundsRemaining", 1)
	FlavorsScript.try_apply_perishable_flavors_on_round_end(match3)
	rows = SupportScript.get_active_boon_inventory_slot_rows(match3)
	if not rows.is_empty():
		print("[FAIL] Perishable boon not removed at zero rounds")
		return false
	print("[OK] Perishable flavor removed boon at round end")
	return true


func _check_ghost_capacity_exemption() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var boon = engine.get_service("Boon")
	var store := engine.store
	var config := match3.get_node("configuration", true)

	var boons_bag: GnosisNode = match3.get_node("boons", false).get_node("default")
	boons_bag.set_key("maxSize", 2)

	for boon_id in ["Brainrot", "Rizz"]:
		var activate := store.create_object()
		activate.set_key("boonId", boon_id)
		var result = boon.invoke_function("ActivateBoon", activate)
		if result is GnosisFunctionResult and not result.is_ok:
			print("[FAIL] could not fill boon bag for ghost test: %s" % result.error)
			return false

	if EngineFlavorsScript.read_empty_slot_count_by_capacity(boons_bag, config) != 0:
		print("[FAIL] expected zero empty capacity slots when bag full")
		return false

	var ghost_entry := store.create_object()
	ghost_entry.set_key("instanceId", "ghost-test")
	ghost_entry.set_key("boonId", "Sus")
	ghost_entry.set_key("id", "Sus")
	var props := store.create_object()
	props.set_key("positiveFlavorId", "Ghost")
	props.set_key("exemptFromSlotCapacity", true)
	ghost_entry.set_node("properties", props)
	boons_bag.get_node("list").add(ghost_entry)
	EngineFlavorsScript.apply_bag_capacity_metrics(boons_bag, config)

	if EngineFlavorsScript.count_capacity_consuming_equipped_slots(boons_bag.get_node("list"), config) != 2:
		print("[FAIL] ghost entry should not consume capacity (got %d consuming)" % EngineFlavorsScript.count_capacity_consuming_equipped_slots(boons_bag.get_node("list"), config))
		return false
	if boons_bag.get_node("list").get_count() != 3:
		print("[FAIL] expected three list entries with ghost overflow (got %d)" % boons_bag.get_node("list").get_count())
		return false
	print("[OK] Ghost flavor exempt from slot capacity")
	return true


func _boot_engine() -> GnosisEngine:
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


func _setup_tile(gameplay, x: int, y: int, item_id: String) -> void:
	var tile = gameplay.get_tile(x, y)
	tile.item_id = item_id
	tile.item_kind = Models.KIND_NORMAL
	tile.item_type_id = "plain"
