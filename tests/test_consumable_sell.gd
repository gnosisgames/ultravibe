extends SceneTree

## Owned consumable can be sold via RemoveConsumable (inventory sell refund).

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")


func _initialize() -> void:
	print("--- Consumable Sell Test ---")
	var ok := _run()
	print("--- Consumable Sell Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	var engine := _boot_engine()
	var match3 = engine.get_service("Match3")
	var consumable = engine.get_service("Consumable")
	var currency = engine.get_service("Currency")
	var store := engine.store

	var add := store.create_object()
	add.set_key("consumableId", "Morphomania")
	add.set_key("buyPrice", 10)
	consumable.invoke_function("AddConsumable", add)

	var list := _consumable_list(match3)
	if list.get_count() < 1:
		print("[FAIL] Morphomania not in inventory")
		return false
	var entry: GnosisNode = list.get_node(0)
	var sell_price := InventoryTooltipUiScript.read_inventory_sell_price(entry)
	if sell_price <= 0:
		print("[FAIL] sellPrice missing on consumable row")
		return false

	var actions := InventoryTooltipUiScript.build_inventory_row_actions(engine, entry, "consumables")
	if actions.is_empty():
		print("[FAIL] sell action not built for consumable tooltip")
		return false

	var money_before := _read_money(currency)
	if not InventoryTooltipUiScript.try_sell_consumable_entry(match3, entry):
		print("[FAIL] try_sell_consumable_entry returned false")
		return false
	if _consumable_list(match3).get_count() > 0:
		print("[FAIL] consumable still in inventory after sell")
		return false
	var money_after := _read_money(currency)
	if money_after < money_before + sell_price:
		print("[FAIL] money before=%d after=%d expected +%d" % [money_before, money_after, sell_price])
		return false
	print("[OK] sold consumable for %d (money %d -> %d)" % [sell_price, money_before, money_after])
	return true


func _consumable_list(match3: GnosisService) -> GnosisNode:
	var ephemeral: GnosisNode = match3.context.state.root.get_node("Ephemeral")
	return ephemeral.get_node("consumables").get_node("default").get_node("list")


func _read_money(currency) -> int:
	if currency == null or currency.context == null:
		return 0
	var params: GnosisNode = currency.context.store.create_object()
	params.set_key("currencyId", "money")
	var payload = currency.invoke_function("GetBalance", params)
	if payload is GnosisNode and (payload as GnosisNode).is_valid():
		var bal := (payload as GnosisNode).get_node("balance")
		if bal.is_valid() and bal.value != null:
			return int(bal.value)
	return 0


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
	config.register_service("Match3Shop", GnosisLifetime.TRANSIENT, func(): return load("res://game/match3/services/match3_shop_service.gd").new())

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()
	return engine
