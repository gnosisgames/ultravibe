extends SceneTree

## Minimal engine-service test for Consumable.RollRandomConsumable. This does not
## need gameplay/grid boot; it verifies the data-driven luckyBlock/boon verb exists
## and can grant a configured consumable while honoring exclusions.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"

func _initialize() -> void:
	print("--- Consumable Roll Test ---")
	var ok := _run()
	print("--- Consumable Roll Test %s ---" % ("Passed" if ok else "FAILED"))
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
	config.register_service("Consumable", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_consumable_service.gd"))

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	var consumable = engine.get_service("Consumable")
	if consumable == null:
		print("[FAIL] Consumable service missing")
		return false
	if not consumable.get_functions().has("RollRandomConsumable"):
		print("[FAIL] RollRandomConsumable is not exposed")
		return false

	var set_capacity := store.create_object()
	set_capacity.set_key("capacity", 5)
	consumable.invoke_function("SetCapacity", set_capacity)

	var roll := store.create_object()
	roll.set_key("excludeConsumableId", "luckyBlock")
	var payload = consumable.invoke_function("RollRandomConsumable", roll)
	if payload == null:
		print("[FAIL] RollRandomConsumable returned null")
		return false

	var list_payload = consumable.invoke_function("GetList", store.create_object())
	var list: GnosisNode = list_payload.get_node("list") if list_payload is GnosisNode else GnosisNode.new(null)
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST or list.get_count() != 1:
		print("[FAIL] Expected exactly one rolled consumable, got %d" % (list.get_count() if list.is_valid() else -1))
		return false

	var entry := list.get_node(0)
	var rolled_id := FallingBlockEphemeral.read_string(entry.get_node("id"), "")
	if rolled_id.is_empty():
		rolled_id = FallingBlockEphemeral.read_string(entry.get_node("consumableId"), "")
	if rolled_id.is_empty() or rolled_id == "luckyBlock":
		print("[FAIL] Rolled invalid/excluded consumable id: %s" % rolled_id)
		return false

	print("[SUCCESS] RollRandomConsumable granted '%s' while excluding luckyBlock" % rolled_id)
	return true
