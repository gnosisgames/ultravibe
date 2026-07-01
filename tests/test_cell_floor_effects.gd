extends SceneTree

## Gold enhanced floor should grant money when a gem on it scores.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Models = preload("res://game/match3/core/match3_models.gd")


func _initialize() -> void:
	print("--- Cell Floor Gold Effect Test ---")
	var ok := _run()
	print("--- Cell Floor Gold Effect Test %s ---" % ("Passed" if ok else "FAILED"))
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
	var currency = engine.get_service("Currency")
	if match3 == null or currency == null:
		print("[FAIL] services missing")
		return false

	var money_before := _money_balance(currency)
	var gameplay = match3.get_gameplay()
	gameplay.load_level(_tiny_layout(), 99999, 20, 3, {"red": 10, "blue": 10, "green": 10})
	gameplay.get_tile(0, 0).cell_floor_type_id = "Gold"
	gameplay.get_tile(1, 0).item_id = "red"
	gameplay.get_tile(2, 0).item_id = "red"
	gameplay.get_tile(0, 0).item_id = "red"

	var results: Array = gameplay.process_move(Models.TileCoord.new(0, 0), Models.TileCoord.new(1, 0), {"red": 10})
	if results.is_empty():
		print("[FAIL] expected scoring move")
		return false

	var money_after := _money_balance(currency)
	if money_after <= money_before:
		print("[FAIL] Gold floor did not add money (%d -> %d)" % [money_before, money_after])
		return false

	var saw_pop := false
	for entry in results:
		if entry is Models.MatchResult:
			for pop in entry.floor_float_pops:
				if int(pop.get("moneyDelta", 0)) > 0:
					saw_pop = true
	if not saw_pop:
		print("[FAIL] missing floor money float pop")
		return false

	print("[SUCCESS] Gold floor granted money %d -> %d" % [money_before, money_after])
	return true


func _money_balance(currency) -> int:
	var res = currency.get_balance("money")
	if res and res.payload and res.payload.is_valid():
		return int(res.payload.get_node("balance").value)
	return 0


func _tiny_layout():
	var layout = preload("res://game/match3/core/match3_board_layout.gd").new()
	layout.id = "test"
	layout.width = 3
	layout.height = 1
	return layout
