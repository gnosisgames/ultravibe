extends SceneTree

## Verifies Sprint 5 shop polish: free reroll bank, Clickbait scaling, echo tracking, boss reroll, RemoveUpgrade.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ConsumableServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_consumable_service.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Shop Polish Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Shop Polish Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_free_reroll_bank():
		return false
	if not _check_clickbait_shop_reroll_scaling():
		return false
	if not _check_consumable_echo_tracking():
		return false
	if not _check_boss_reroll():
		return false
	if not _check_remove_upgrade():
		return false
	print("[SUCCESS] Shop polish parity wired")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _check_free_reroll_bank() -> bool:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	var shop := engine.get_service("Match3Shop")
	var store := engine.store

	var delta := store.create_object()
	delta.set_key("delta", 1)
	var add_result = match3.invoke_function("AddCoreShopFreeRerollCountDelta", delta)
	if not (add_result is GnosisFunctionResult) or not add_result.is_ok:
		print("[FAIL] AddCoreShopFreeRerollCountDelta: %s" % add_result.error)
		return false

	var balance_before := _money_balance(engine)
	var reroll := store.create_object()
	var reroll_result = shop.invoke_function("RerollCoreShop", reroll)
	if not (reroll_result is GnosisFunctionResult) or not reroll_result.is_ok:
		print("[FAIL] RerollCoreShop with free bank: %s" % reroll_result.error)
		return false
	if _money_balance(engine) != balance_before:
		print("[FAIL] free reroll spent money (before=%d after=%d)" % [balance_before, _money_balance(engine)])
		return false
	var core := engine.state.root.get_node("Ephemeral").get_node("match3Shop").get_node("core")
	if int(core.get_node("freeRerollCount").value) != 0:
		print("[FAIL] freeRerollCount not consumed")
		return false
	if not bool(reroll_result.payload.get_node("usedFreeRerollBank").value):
		print("[FAIL] usedFreeRerollBank not true")
		return false
	print("[OK] free reroll bank consumed before paid reroll")
	return true


func _check_clickbait_shop_reroll_scaling() -> bool:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	var boon := engine.get_service("Boon")
	var store := engine.store

	var activate := store.create_object()
	activate.set_key("boonId", "Clickbait")
	var activate_result = boon.invoke_function("ActivateBoon", activate)
	if activate_result == null or not (activate_result is GnosisNode) or not activate_result.is_valid():
		print("[FAIL] Activate Clickbait failed")
		return false

	var scaling := store.create_object()
	var scale_result = match3.invoke_function("ApplyShopRerollScalingAfterCoreShopReroll", scaling)
	if not (scale_result is GnosisFunctionResult) or not scale_result.is_ok:
		print("[FAIL] ApplyShopRerollScalingAfterCoreShopReroll: %s" % scale_result.error)
		return false

	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	for row in rows:
		if SupportScript.read_boon_catalog_id_from_inventory_entry(row).to_lower() != "clickbait":
			continue
		var props: GnosisNode = row.get_node("properties")
		var scaling_node: GnosisNode = props.get_node("scaling")
		var counters: GnosisNode = scaling_node.get_node("counters")
		if int(counters.get_node("shopRerollsLifetime").value) < 1:
			print("[FAIL] Clickbait shopRerollsLifetime not incremented")
			return false
		print("[OK] Clickbait shop reroll scaling counter bumped")
		return true
	print("[FAIL] Clickbait not equipped after activate")
	return false


func _check_consumable_echo_tracking() -> bool:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	var store := engine.store
	var event_bus := engine.event_bus

	var fact := store.create_object()
	fact.set_key("consumableId", "Tychomania")
	event_bus.publish(GnosisEvent.new(ConsumableServiceScript.FACT_CONSUMABLE_USED, fact, false))

	var m3 := engine.state.root.get_node("Ephemeral").get_node("match3")
	var echo_id := str(m3.get_node("echoLastRuneOrItemUpgradeGrantConsumableId").value)
	if echo_id != "Tychomania":
		print("[FAIL] echo target not tracked (got '%s')" % echo_id)
		return false

	var echomania_fact := store.create_object()
	echomania_fact.set_key("consumableId", "Echomania")
	event_bus.publish(GnosisEvent.new(ConsumableServiceScript.FACT_CONSUMABLE_USED, echomania_fact, false))
	if str(m3.get_node("echoLastRuneOrItemUpgradeGrantConsumableId").value) != "Tychomania":
		print("[FAIL] Echomania should not overwrite echo target")
		return false

	var dup := store.create_object()
	dup.set_key("bucketId", "default")
	var dup_result = match3.invoke_function("DuplicateLastRuneOrItemUpgradeGrantConsumable", dup)
	if not (dup_result is GnosisFunctionResult) or not dup_result.is_ok:
		print("[FAIL] DuplicateLastRuneOrItemUpgradeGrantConsumable: %s" % dup_result.error)
		return false
	print("[OK] consumable echo tracking and duplicate invoke")
	return true


func _check_boss_reroll() -> bool:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	var store := engine.store
	var m3_eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	m3_eph.set_key("nextLevel", 3)

	var result = match3.invoke_function("RerollUpcomingBossRound", store.create_object())
	if not (result is GnosisFunctionResult) or not result.is_ok:
		print("[FAIL] RerollUpcomingBossRound: %s" % result.error)
		return false
	var new_profile := str(result.payload.get_node("bossProfileId").value)
	var previous := str(result.payload.get_node("previousBossProfileId").value)
	if new_profile.is_empty():
		print("[FAIL] boss reroll returned empty profile")
		return false
	if new_profile.to_lower() == previous.to_lower() and _eligible_boss_count(3) > 1:
		print("[FAIL] boss reroll did not pick alternate profile")
		return false
	print("[OK] upcoming boss reroll (%s -> %s)" % [previous, new_profile])
	return true


func _check_remove_upgrade() -> bool:
	var engine := _engine()
	var shop := engine.get_service("Match3Shop")
	var upgrade := engine.get_service("Upgrade")
	var store := engine.store

	var eligible := store.create_object()
	eligible.set_key("categoryId", "run")
	var eligible_result = upgrade.invoke_function("GetEligibleUpgradeIds", eligible)
	if eligible_result == null or not (eligible_result is GnosisNode) or not eligible_result.is_valid():
		print("[FAIL] GetEligibleUpgradeIds failed")
		return false
	var ids_node: GnosisNode = eligible_result.get_node("upgradeIds")
	if ids_node.get_count() == 0:
		print("[SKIP] no eligible run upgrades to test RemoveUpgrade")
		return true
	var first_entry: GnosisNode = ids_node.get_node(0)
	var upgrade_id := str(first_entry.get_node("upgradeId").value).strip_edges()
	if upgrade_id.is_empty():
		upgrade_id = str(first_entry.value).strip_edges()

	var add := store.create_object()
	add.set_key("categoryId", "run")
	add.set_key("upgradeId", upgrade_id)
	var add_result = upgrade.invoke_function("AddUpgrade", add)
	if add_result == null or not (add_result is GnosisNode) or not add_result.is_valid():
		print("[FAIL] AddUpgrade for remove test failed")
		return false

	var remove := store.create_object()
	remove.set_key("upgradeId", upgrade_id)
	var remove_result = shop.invoke_function("RemoveUpgrade", remove)
	if not (remove_result is GnosisFunctionResult) or not remove_result.is_ok:
		print("[FAIL] RemoveUpgrade: %s" % remove_result.error)
		return false

	var has := store.create_object()
	has.set_key("categoryId", "run")
	has.set_key("upgradeId", upgrade_id)
	var has_result = upgrade.invoke_function("HasUpgrade", has)
	if has_result is GnosisNode and has_result.is_valid():
		if bool(has_result.get_node("hasUpgrade").value):
			print("[FAIL] upgrade still owned after RemoveUpgrade")
			return false
	print("[OK] RemoveUpgrade delegates to Upgrade service")
	return true


func _money_balance(engine: GnosisEngine) -> int:
	var currency := engine.get_service("Currency")
	var params := engine.store.create_object()
	params.set_key("currencyId", "money")
	var result = currency.invoke_function("GetBalance", params)
	if result is GnosisFunctionResult and result.is_ok:
		return int(result.payload.get_node("balance").value)
	return 0


func _eligible_boss_count(boss_round: int) -> int:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	if match3.has_method("_build_eligible_boss_profile_ids"):
		return match3.call("_build_eligible_boss_profile_ids", boss_round).size()
	return 1
