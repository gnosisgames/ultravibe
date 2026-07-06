extends SceneTree

## Sprint 5 boon/consumable depth: effectApplication modes, flavor rules,
## self-destruct, consumable echo tracking, and balance-report smoke.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const FlavorsScript = preload("res://game/match3/boons/match3_boon_flavors.gd")
const EngineFlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")
const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")
const ConsumableServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_consumable_service.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Boon Consumable Depth Test ---")
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
	print("--- Boon Consumable Depth Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_per_instance_vs_catalog_once():
		return false
	if not _check_rental_round_start_cost():
		return false
	if not _check_eternal_blocks_sell():
		return false
	if not _check_double_down_self_destruct():
		return false
	if not _check_consumable_echo_tracking():
		return false
	if not _check_balance_report_smoke():
		return false
	print("[SUCCESS] boon/consumable depth parity verified")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _match3() -> Match3Service:
	return _engine().get_service("Match3") as Match3Service


func _check_per_instance_vs_catalog_once() -> bool:
	var engine := _engine()
	var match3 := _match3()
	_clear_boon_bag(match3)

	_activate_boon("CookieTime")
	_inject_boon_slot(engine, match3, "CookieTime", "cookie-dup", "perInstance")
	var per_instance_hits := _count_effect_application_invocations(match3, "CookieTime")
	if per_instance_hits != 2:
		print("[FAIL] perInstance expected 2 CookieTime slots, got %d" % per_instance_hits)
		return false

	_clear_boon_bag(match3)
	_inject_boon_slot(engine, match3, "Backstabber", "back-1", "catalogOnce")
	_inject_boon_slot(engine, match3, "Backstabber", "back-2", "catalogOnce")
	var catalog_once_hits := _count_effect_application_invocations(match3, "Backstabber")
	if catalog_once_hits != 1:
		print("[FAIL] catalogOnce expected 1 Backstabber invocation, got %d" % catalog_once_hits)
		return false

	print("[OK] perInstance vs catalogOnce effect application")
	return true


func _check_rental_round_start_cost() -> bool:
	var engine := _engine()
	var match3 := _match3()
	var currency := engine.get_service("Currency")
	_clear_boon_bag(match3)

	var add := engine.store.create_object()
	add.set_key("currencyId", "money")
	add.set_key("amount", 20)
	currency.invoke_function("AddCurrency", add)

	_activate_boon("Rizz")
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Rizz not equipped for rental test")
		return false
	rows[0].get_node("properties").set_key(EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY, "Rental")

	var money_before := _read_money(currency)
	FlavorsScript.try_apply_negative_flavors_on_round_start(match3, 1, 2)
	var money_after := _read_money(currency)
	if money_after != money_before - 3:
		print("[FAIL] Rental flavor expected -3 money, got %d -> %d" % [money_before, money_after])
		return false
	print("[OK] Rental flavor round-start money cost")
	return true


func _check_eternal_blocks_sell() -> bool:
	var engine := _engine()
	var match3 := _match3()
	_clear_boon_bag(match3)
	_activate_boon("Glitch")
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] Glitch not equipped for eternal sell test")
		return false
	rows[0].get_node("properties").set_key(EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY, "Eternal")
	var config := match3.get_node("configuration", true)
	if InventoryTooltipUiScript.can_sell_boon_entry(engine, rows[0]):
		print("[FAIL] Eternal flavor should block inventory sell")
		return false
	if not EngineFlavorsScript.inventory_entry_blocks_sell(rows[0], config):
		print("[FAIL] Eternal flavor blockSell not detected by engine helper")
		return false
	print("[OK] Eternal flavor blocks sell")
	return true


func _check_double_down_self_destruct() -> bool:
	var engine := _engine()
	var match3 := _match3()
	_clear_boon_bag(match3)
	_activate_boon("DoubleDown")

	for seed in 256:
		_activate_boon_if_missing("DoubleDown")
		match3.configure_boon_score_rng(seed)
		var runtime = match3.get("_boon_runtime")
		if runtime == null:
			print("[FAIL] boon runtime missing")
			return false
		runtime.apply_round_end_self_destructs(false)
		if SupportScript.get_active_boon_inventory_slot_rows(match3).is_empty():
			print("[OK] DoubleDown self-destruct proc (seed %d)" % seed)
			return true
	print("[FAIL] DoubleDown self-destruct never proc in seed sweep")
	return false


func _check_consumable_echo_tracking() -> bool:
	var engine := _engine()
	var match3 := _match3()
	var store := engine.store
	var event_bus := engine.event_bus

	var fact := store.create_object()
	fact.set_key("consumableId", "Tychomania")
	event_bus.publish(GnosisEvent.new(ConsumableServiceScript.FACT_CONSUMABLE_USED, fact, false))

	var m3 := engine.state.root.get_node("Ephemeral").get_node("match3")
	var echo_id := str(m3.get_node("echoLastRuneOrItemUpgradeGrantConsumableId").value)
	if echo_id != "Tychomania":
		print("[FAIL] consumable echo target not tracked (got '%s')" % echo_id)
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


func _check_balance_report_smoke() -> bool:
	var root := ProjectSettings.globalize_path("res://")
	var script_path := root.path_join("tools/match3_round_balance_report.sh")
	if not FileAccess.file_exists(script_path):
		print("[FAIL] balance report script missing")
		return false
	var output: Array = []
	var exit_code := OS.execute("/bin/bash", [script_path], output, true, false)
	var text := "\n".join(output)
	if exit_code != 0:
		print("[FAIL] match3_round_balance_report.sh exit %d" % exit_code)
		return false
	if not text.contains("Match3 round balance"):
		print("[FAIL] balance report missing expected header")
		return false
	if not text.contains("Cascade assist model"):
		print("[FAIL] balance report missing cascade assist section")
		return false
	if not text.contains("mega-chain"):
		print("[FAIL] balance report missing mega-chain model line")
		return false
	print("[OK] match3 round balance report runs")
	return true


func _activate_boon(boon_id: String) -> void:
	var boon := _engine().get_service("Boon")
	var activate := _engine().store.create_object()
	activate.set_key("boonId", boon_id)
	boon.invoke_function("ActivateBoon", activate)


func _activate_boon_if_missing(boon_id: String) -> void:
	if SupportScript.is_boon_catalog_id_equipped(_match3(), boon_id):
		return
	_activate_boon(boon_id)


func _clear_boon_bag(match3: Match3Service) -> void:
	var boon := _engine().get_service("Boon")
	var store := _engine().store
	for row in SupportScript.get_active_boon_inventory_slot_rows(match3):
		var instance_id := SupportScript._node_str(row, "instanceId").strip_edges()
		if instance_id.is_empty():
			continue
		var params := store.create_object()
		params.set_key("instanceId", instance_id)
		params.set_key("bucketId", "default")
		boon.invoke_function("DeactivateBoon", params)


func _count_effect_application_invocations(match3: Match3Service, catalog_id: String) -> int:
	var want := catalog_id.strip_edges().to_lower()
	if want.is_empty():
		return 0
	var matches: Array = []
	for row in SupportScript.get_active_boon_inventory_slot_rows(match3):
		if SupportScript.read_boon_catalog_id_from_inventory_entry(row).to_lower() == want:
			matches.append(row)
	if matches.is_empty():
		return 0
	if _entry_uses_per_instance(matches[0]):
		return matches.size()
	return 1


func _entry_uses_per_instance(entry: GnosisNode) -> bool:
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	var mode_node := props.get_node("effectApplication")
	if not mode_node.is_valid() or mode_node.value == null:
		return false
	return str(mode_node.value).strip_edges().to_lower() == "perinstance"


func _inject_boon_slot(
	engine: GnosisEngine,
	match3: Match3Service,
	boon_id: String,
	instance_id: String,
	effect_application: String,
) -> void:
	var store := engine.store
	var bag := match3.get_node("boons", false).get_node("default")
	var list := bag.get_node("list")
	var entry := store.create_object()
	entry.set_key("instanceId", instance_id)
	entry.set_key("boonId", boon_id)
	entry.set_key("id", boon_id)
	var props := store.create_object()
	props.set_key("effectApplication", effect_application)
	entry.set_node("properties", props)
	list.add(entry)
	SupportScript.publish_ephemeral_state(match3)


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
