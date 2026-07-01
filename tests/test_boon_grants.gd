extends SceneTree

## Verifies Match3.RollRandomBoon grants boons into the default bag (Vibemania parity).

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")


func _initialize() -> void:
	print("--- Boon Grants Test ---")
	var ok := _run()
	print("--- Boon Grants Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	var config := GnosisEngineConfig.new()
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.asset_registry_paths = PackedStringArray(["res://data/asset_registry.json"])
	config.register_service("Configuration", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_configuration_service.gd"))
	config.register_service("Statistic", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_statistic_service.gd"))
	config.register_service("Seed", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_seed_service.gd"))
	config.register_service("Boon", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_boon_service.gd"))
	config.register_service("Match3Shop", GnosisLifetime.TRANSIENT, func(): return load("res://game/match3/services/match3_shop_service.gd").new())
	config.register_service("Match3", GnosisLifetime.TRANSIENT, func(): return Match3ServiceScript.new())

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	var match3 = engine.get_service("Match3")
	if match3 == null:
		print("[FAIL] Match3 service missing")
		return false
	if not match3.get_functions().has("RollRandomBoon"):
		print("[FAIL] RollRandomBoon is not exposed on Match3")
		return false

	var boon = engine.get_service("Boon")
	if boon == null:
		print("[FAIL] Boon service missing")
		return false

	var before := _filled_boon_count(engine)
	var params := store.create_object()
	params.set_key("bucketId", "default")
	params.set_key("count", 2)
	var result = match3.invoke_function("RollRandomBoon", params)
	if result is GnosisFunctionResult and not result.is_ok:
		print("[FAIL] RollRandomBoon failed: %s" % result.error)
		return false
	if result is GnosisFunctionResult:
		var granted := int(result.payload.get_node("grantedCount").value) if result.payload.is_valid() else 0
		if granted < 1:
			print("[FAIL] RollRandomBoon grantedCount < 1")
			return false

	var after := _filled_boon_count(engine)
	if after <= before:
		print("[FAIL] Boon bag count did not increase (%d -> %d)" % [before, after])
		return false

	print("[SUCCESS] RollRandomBoon increased boon bag from %d to %d" % [before, after])
	return true


func _filled_boon_count(engine: GnosisEngine) -> int:
	var root: GnosisNode = engine.state.root
	if root == null or not root.is_valid():
		return 0
	var eph: GnosisNode = root.get_node("Ephemeral")
	if not eph.is_valid():
		return 0
	var bag: GnosisNode = eph.get_node("boons").get_node("default")
	if not bag.is_valid():
		return 0
	var list: GnosisNode = bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return 0
	return list.get_count()
