extends SceneTree

## CryptoBro grants money on round skip scaled by total skips (cap $20).

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")


func _initialize() -> void:
	print("--- CryptoBro Round Skip Test ---")
	var ok := _test_without_boon() and _test_skip_grants() and _test_skip_cap()
	print("--- CryptoBro Round Skip Test %s ---" % ("Passed" if ok else "FAILED"))
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


func _money_balance(currency) -> int:
	var res = currency.get_balance("money")
	if res and res.payload and res.payload.is_valid():
		return int(res.payload.get_node("balance").value)
	return 0


func _simulate_round_skip(match3) -> void:
	match3.call("_increment_statistic", "match3.rounds.skipped", 1)
	var runtime = match3.get("_boon_runtime")
	if runtime != null and runtime.has_method("on_round_skipped"):
		runtime.on_round_skipped()


func _test_without_boon() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var currency = engine.get_service("Currency")
	var before := _money_balance(currency)
	_simulate_round_skip(match3)
	var after := _money_balance(currency)
	if after != before:
		print("[FAIL] skip without CryptoBro should not grant money (%d -> %d)" % [before, after])
		return false
	print("[OK] no grant without CryptoBro")
	return true


func _test_skip_grants() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var currency = engine.get_service("Currency")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "CryptoBro")
	var before := _money_balance(currency)
	_simulate_round_skip(match3)
	var after_first := _money_balance(currency)
	if after_first - before != 4:
		print("[FAIL] first skip expected +$4 got +$%d" % (after_first - before))
		return false
	_simulate_round_skip(match3)
	var after_second := _money_balance(currency)
	if after_second - after_first != 8:
		print("[FAIL] second skip expected +$8 got +$%d" % (after_second - after_first))
		return false
	print("[OK] skip grants scale with total skips (4 then 8)")
	return true


func _test_skip_cap() -> bool:
	var engine = _engine()
	var match3 = engine.get_service("Match3")
	var currency = engine.get_service("Currency")
	var boon = engine.get_service("Boon")
	_activate(boon, engine.store, "CryptoBro")
	for _i in 5:
		_simulate_round_skip(match3)
	var before := _money_balance(currency)
	_simulate_round_skip(match3)
	var after := _money_balance(currency)
	if after - before != 20:
		print("[FAIL] capped skip expected +$20 got +$%d" % (after - before))
		return false
	print("[OK] skip grant capped at $20")
	return true
