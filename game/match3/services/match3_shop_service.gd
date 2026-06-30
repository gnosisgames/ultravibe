class_name Match3ShopService
extends GnosisService

## Minimal Godot port of Unity Match3ShopService.
## It exposes the Unity invoke surface and publishes a simple mixed catalog offer list.

const DEFAULT_OFFER_COUNT := 5
const CURRENCY_ID := "money"

var _reroll_count := 0


func _init() -> void:
	super._init("Match3Shop", GnosisLifetime.TRANSIENT)


func on_initialize() -> void:
	_ensure_core_shop()


func get_functions() -> Array:
	return [
		"GetCoreShop",
		"RebuildCoreShopOffers",
		"RerollCoreShop",
		"PurchaseCoreItem",
		"RemoveUpgrade",
		"ResolveCatalogShopBuyPrice",
		"RecordInventorySale",
	]


func invoke_function(name: String, parameters: GnosisNode) -> Variant:
	match name:
		"GetCoreShop":
			return GnosisFunctionResult.ok(_ensure_core_shop())
		"RebuildCoreShopOffers":
			return GnosisFunctionResult.ok(_rebuild_core_shop_offers())
		"RerollCoreShop":
			_reroll_count += 1
			_increment_statistic("match3.shop.rerolls.total", 1)
			return GnosisFunctionResult.ok(_rebuild_core_shop_offers())
		"PurchaseCoreItem":
			return _purchase_core_item(parameters)
		"RemoveUpgrade":
			return GnosisFunctionResult.fail("remove_upgrade_not_ported")
		"ResolveCatalogShopBuyPrice":
			return GnosisFunctionResult.ok(_resolve_price_payload(parameters))
		"RecordInventorySale":
			_increment_statistic("match3.shop.sales.total", 1)
			return GnosisFunctionResult.ok(context.store.create_value(true))
	return GnosisFunctionResult.fail("Unknown Match3Shop function '%s'." % name)


func _ensure_core_shop() -> GnosisNode:
	var shop := get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		shop = context.store.create_object()
		set_node("match3Shop", shop, false)
	var core := shop.get_node("core")
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		core = context.store.create_object()
		shop.set_key("core", core)
	if not core.get_node("offers").is_valid():
		_rebuild_core_shop_offers()
	return shop


func _rebuild_core_shop_offers() -> GnosisNode:
	var shop := get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		shop = context.store.create_object()
		set_node("match3Shop", shop, false)
	var core := context.store.create_object()
	var offers := context.store.create_list()
	var candidates := _collect_offer_candidates()
	var start := _reroll_count % maxi(1, candidates.size()) if not candidates.is_empty() else 0
	for i in mini(DEFAULT_OFFER_COUNT, candidates.size()):
		var candidate: Dictionary = candidates[(start + i) % candidates.size()]
		var offer := context.store.create_object()
		offer.set_key("index", i)
		offer.set_key("sourceConfigId", candidate.get("sourceConfigId", ""))
		offer.set_key("itemId", candidate.get("itemId", ""))
		offer.set_key("price", int(candidate.get("price", 0)))
		offer.set_key("available", true)
		offers.add(offer)
	core.set_key("offers", offers)
	core.set_key("rerollCount", _reroll_count)
	core.set_key("freeRerollCount", 0)
	shop.set_key("core", core)
	_commit_shop()
	return shop


func _collect_offer_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_add_catalog_candidates(result, "boons", 85)
	_add_catalog_candidates(result, "consumables", 45)
	_add_catalog_candidates(result, "runUpgrades", 120)
	return result


func _add_catalog_candidates(result: Array[Dictionary], config_id: String, base_price: int) -> void:
	var config := get_node("configuration", true)
	if not config.is_valid():
		return
	var catalog := config.get_node(config_id)
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return
	var ids := catalog.get_keys()
	ids.sort()
	for item_id in ids:
		if str(item_id).strip_edges().is_empty():
			continue
		result.append({
			"sourceConfigId": config_id,
			"itemId": str(item_id),
			"price": base_price,
		})


func _purchase_core_item(parameters: GnosisNode) -> GnosisFunctionResult:
	var index := _node_int(parameters, "index", -1)
	var shop := _ensure_core_shop()
	var offers := shop.get_node("core.offers")
	if index < 0 or not offers.is_valid() or index >= offers.get_count():
		return GnosisFunctionResult.fail("invalid_offer_index")
	var offer := offers.get_node(index)
	if not offer.is_valid():
		return GnosisFunctionResult.fail("invalid_offer_index")
	if _node_bool(offer, "purchased", false):
		return GnosisFunctionResult.fail("already_purchased")
	var price := _node_int(offer, "price", 0)
	if price > 0 and not _try_spend_currency(price):
		return GnosisFunctionResult.fail("insufficient_funds")
	offer.set_key("purchased", true)
	offer.set_key("available", false)
	_increment_statistic("match3.shop.purchases.total", 1)
	_commit_shop()
	return GnosisFunctionResult.ok(offer)


func _try_spend_currency(amount: int) -> bool:
	if amount <= 0:
		return true
	if context == null or context.store == null:
		return false
	var params := context.store.create_object()
	params.set_key("currencyId", CURRENCY_ID)
	params.set_key("amount", amount)
	var result = call_service("Currency", "TrySpendCurrency", params)
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode and result.is_valid():
		return _node_bool(result, "success", false)
	return false


func _resolve_price_payload(parameters: GnosisNode) -> GnosisNode:
	var payload := context.store.create_object()
	var config_id := _node_string(parameters, "sourceConfigId", "")
	var price := 50
	match config_id:
		"boons":
			price = 85
		"runUpgrades":
			price = 120
		"consumables":
			price = 45
	payload.set_key("price", price)
	payload.set_key("currencyId", CURRENCY_ID)
	return payload


func _increment_statistic(key: String, delta: int = 1) -> void:
	if delta == 0 or key.strip_edges().is_empty():
		return
	if context == null or context.engine == null or context.store == null:
		return
	var statistic = context.engine.get_service("Statistic")
	if statistic == null or not statistic.has_method("invoke_function"):
		return
	var payload := context.store.create_object()
	payload.set_key("persistent", false)
	payload.set_key("key", key.strip_edges())
	payload.set_key("delta", delta)
	statistic.invoke_function("IncrementCounter", payload)


func _commit_shop() -> void:
	if context and context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3Shop"]
		context.engine.commit("match3Shop", changed_paths)


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)


func _node_string(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)


func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)
