extends SceneTree

## Sprint 3 shop/economy parity: interest, weights, discount cap, floor inflation,
## sell refunds, run-upgrade pity, and shop statistics.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Shop Economy Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Shop Economy Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_interest_formula():
		return false
	if not _check_default_shop_tuning():
		return false
	if not _check_max_discount_cap():
		return false
	if not _check_floor_price_inflation():
		return false
	if not _check_inventory_sell_refund_half():
		return false
	if not _check_run_upgrade_pity_offer():
		return false
	if not _check_shop_purchase_and_sale_statistics():
		return false
	print("[SUCCESS] shop economy parity verified")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _check_interest_formula() -> bool:
	var engine := _engine()
	var currency := engine.get_service("Currency")
	var store := engine.store

	_set_money_balance(currency, 100)
	var preview := _calculate_interest(currency, "money")
	if preview != 5:
		print("[FAIL] interest at balance 100 expected 5 (cap 25 / 5), got %d" % preview)
		return false

	_set_money_balance(currency, 10)
	preview = _calculate_interest(currency, "money")
	if preview != 2:
		print("[FAIL] interest at balance 10 expected 2, got %d" % preview)
		return false

	var apply := store.create_object()
	apply.set_key("currencyId", "money")
	var apply_result = currency.invoke_function("ApplyInterestOnce", apply)
	if apply_result == null or not (apply_result is GnosisNode) or not (apply_result as GnosisNode).is_valid():
		print("[FAIL] ApplyInterestOnce failed")
		return false
	var interest_stat = _match3().get_statistic_int("currency.money.interest", 0)
	if interest_stat < 2:
		print("[FAIL] currency.money.interest stat not incremented, got %d" % interest_stat)
		return false
	print("[OK] interest cap/divisor and interest statistic")
	return true


func _check_default_shop_tuning() -> bool:
	var shop := _engine().get_service("Match3Shop")
	var result = shop.invoke_function("GetCoreShop", _engine().store.create_object())
	if not (result is GnosisFunctionResult) or not result.is_ok:
		print("[FAIL] GetCoreShop: %s" % result.error)
		return false
	var core: GnosisNode = result.payload.get_node("core")
	var boon_w := _node_int(core, "boonWeightPercent", -1)
	var cons_w := _node_int(core, "consumableWeightPercent", -1)
	var pity_n := _node_int(core, "runUpgradePityEveryN", -1)
	var permille := _node_int(core, "runUpgradeShopChancePermille", -1)
	if boon_w != 66 or cons_w != 34:
		print("[FAIL] default weights expected 66/34, got %d/%d" % [boon_w, cons_w])
		return false
	if pity_n != 5 or permille != 120:
		print("[FAIL] run upgrade pity expected 5 shops / 120‰, got %d / %d" % [pity_n, permille])
		return false
	print("[OK] default shop weights and run-upgrade pity tuning")
	return true


func _check_max_discount_cap() -> bool:
	var engine := _engine()
	var shop := engine.get_service("Match3Shop")
	var shop_eph := engine.state.root.get_node("Ephemeral").get_node("match3Shop")
	shop_eph.set_key("shopDiscountPercent", 0.75)
	var m3_eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	m3_eph.set_key("currentFloor", 1)
	shop_eph.set_key("priceInflationPerFloorPercent", 0.0)

	var params := engine.store.create_object()
	params.set_key("sourceConfigId", "boons")
	params.set_key("itemId", "Glitch")
	var price_result = shop.invoke_function("ResolveCatalogShopBuyPrice", params)
	if not (price_result is GnosisFunctionResult) or not price_result.is_ok:
		print("[FAIL] ResolveCatalogShopBuyPrice: %s" % price_result.error)
		return false
	var price := _node_int(price_result.payload, "price", -1)
	# base 5 × (1 - 0.5 max discount) = 2.5 → 3
	if price != 3:
		print("[FAIL] max 50%% discount expected price 3, got %d" % price)
		return false
	print("[OK] shop discount clamped at 50%%")
	return true


func _check_floor_price_inflation() -> bool:
	var engine := _engine()
	var shop := engine.get_service("Match3Shop")
	var shop_eph := engine.state.root.get_node("Ephemeral").get_node("match3Shop")
	shop_eph.set_key("shopDiscountPercent", 0.0)
	shop_eph.set_key("priceInflationPerFloorPercent", 0.1)
	var m3_eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	m3_eph.set_key("currentFloor", 3)

	var params := engine.store.create_object()
	params.set_key("sourceConfigId", "boons")
	params.set_key("itemId", "Glitch")
	var price_result = shop.invoke_function("ResolveCatalogShopBuyPrice", params)
	if not (price_result is GnosisFunctionResult) or not price_result.is_ok:
		print("[FAIL] floor inflation price resolve failed")
		return false
	var price := _node_int(price_result.payload, "price", -1)
	# base 5 × (1 + 2×0.1) = 6
	if price != 6:
		print("[FAIL] floor-3 inflation expected price 6, got %d" % price)
		return false
	print("[OK] per-floor price inflation")
	return true


func _check_inventory_sell_refund_half() -> bool:
	var engine := _engine()
	var boon := engine.get_service("Boon")
	var store := engine.store
	var activate := store.create_object()
	activate.set_key("boonId", "Glitch")
	activate.set_key("buyPrice", float(11))
	boon.invoke_function("ActivateBoon", activate)
	if not SupportScript.is_boon_catalog_id_equipped(_match3(), "Glitch"):
		print("[FAIL] ActivateBoon for sell refund test")
		return false
	var rows := SupportScript.get_active_boon_inventory_slot_rows(_match3())
	if rows.is_empty():
		print("[FAIL] no equipped boon row")
		return false
	var sell := InventoryTooltipUiScript.read_inventory_sell_price(rows[0])
	if sell != 5:
		print("[FAIL] sell refund expected floor(11/2)=5, got %d" % sell)
		return false
	print("[OK] inventory sell refund is half buy price (min 1)")
	return true


func _check_run_upgrade_pity_offer() -> bool:
	var engine := _engine()
	var shop := engine.get_service("Match3Shop")
	var shop_eph := engine.state.root.get_node("Ephemeral").get_node("match3Shop")
	var core := shop_eph.get_node("core")
	core.set_key("shopsSinceRunUpgradeOffer", 5)
	var rebuild = shop.invoke_function("RebuildCoreShopOffers", engine.store.create_object())
	if not (rebuild is GnosisFunctionResult) or not rebuild.is_ok:
		print("[FAIL] RebuildCoreShopOffers for pity test")
		return false
	var offers := core.get_node("offers")
	if not offers.is_valid():
		print("[FAIL] offers missing after rebuild")
		return false
	for i in range(offers.get_count()):
		var offer := offers.get_node(i)
		if not offer.is_valid():
			continue
		if _node_string(offer, "sourceConfigId", "").to_lower() == "runupgrades":
			print("[OK] run-upgrade pity injects runUpgrades offer")
			return true
	print("[FAIL] pity counter at 5 did not produce a runUpgrades offer")
	return false


func _check_shop_purchase_and_sale_statistics() -> bool:
	var engine := _engine()
	var shop := engine.get_service("Match3Shop")
	var currency := engine.get_service("Currency")
	var m3 = _match3()
	var store := engine.store

	_set_money_balance(currency, 200)
	var shop_result = shop.invoke_function("GetCoreShop", store.create_object())
	if not (shop_result is GnosisFunctionResult) or not shop_result.is_ok:
		print("[FAIL] GetCoreShop for statistics test")
		return false
	var offers: GnosisNode = shop_result.payload.get_node("core").get_node("offers")
	if not offers.is_valid() or offers.get_count() == 0:
		print("[FAIL] no shop offers for purchase stat test")
		return false

	var purchases_before = m3.get_statistic_int("match3.shop.purchases.total", 0)
	var bought := false
	for i in range(offers.get_count()):
		var offer := offers.get_node(i)
		if _node_bool(offer, "purchased", false):
			continue
		var buy := store.create_object()
		buy.set_key("index", i)
		var buy_result = shop.invoke_function("PurchaseCoreItem", buy)
		if buy_result is GnosisFunctionResult and buy_result.is_ok:
			bought = true
			break
	if not bought:
		print("[FAIL] could not purchase any core offer")
		return false
	if m3.get_statistic_int("match3.shop.purchases.total", 0) != purchases_before + 1:
		print("[FAIL] match3.shop.purchases.total not incremented")
		return false

	var sales_before = m3.get_statistic_int("match3.shop.sales.total", 0)
	var sale := store.create_object()
	shop.invoke_function("RecordInventorySale", sale)
	if m3.get_statistic_int("match3.shop.sales.total", 0) != sales_before + 1:
		print("[FAIL] match3.shop.sales.total not incremented")
		return false
	print("[OK] shop purchase and inventory sale statistics")
	return true


func _match3() -> Match3Service:
	return _engine().get_service("Match3") as Match3Service


func _set_money_balance(currency, amount: int) -> void:
	var current := _read_money(currency)
	var delta := amount - current
	if delta == 0:
		return
	var params := _engine().store.create_object()
	params.set_key("currencyId", "money")
	params.set_key("amount", abs(delta))
	if delta > 0:
		currency.invoke_function("AddCurrency", params)
	else:
		currency.invoke_function("RemoveCurrency", params)


func _read_money(currency) -> int:
	if currency == null or currency.context == null:
		return 0
	var params = currency.context.store.create_object()
	params.set_key("currencyId", "money")
	var payload = currency.invoke_function("GetBalance", params)
	if payload is GnosisNode and (payload as GnosisNode).is_valid():
		var bal := (payload as GnosisNode).get_node("balance")
		if bal.is_valid() and bal.value != null:
			return int(bal.value)
	return 0


func _calculate_interest(currency, currency_id: String) -> int:
	var params := _engine().store.create_object()
	params.set_key("currencyId", currency_id)
	var result = currency.invoke_function("CalculateInterestAmount", params)
	if result is GnosisNode and (result as GnosisNode).is_valid():
		return _node_int(result as GnosisNode, "interestAmount", 0)
	return -1


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
