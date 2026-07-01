class_name Match3BoonGrants
extends RefCounted

## Boon grant invokes (Unity Match3GnosisService.BoonGrants parity).

const CatalogPolicyScript = preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

var _service: GnosisService
var _rng := RandomNumberGenerator.new()


func _init(service: GnosisService) -> void:
	_service = service


func roll_random_boon(params: GnosisNode) -> GnosisFunctionResult:
	if _service.context == null or _service.context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var bucket_id := CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	var required_tag := ""
	var count := 1
	if params != null and params.is_valid() and params.get_type() == GnosisValueType.OBJECT:
		bucket_id = SupportScript._node_str(params, "bucketId", bucket_id)
		required_tag = SupportScript._node_str(params, "requiredTag")
		count = SupportScript._node_int(params, "count", 1)
	if bucket_id.is_empty():
		bucket_id = CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	var empty_slots := SupportScript.read_boon_bag_empty_slot_count_by_capacity(_service, bucket_id)
	if empty_slots < 1:
		return GnosisFunctionResult.fail("no_empty_boon_slot")
	count = clampi(count, 1, empty_slots)
	var catalog := SupportScript.build_boon_catalog_ids_from_configuration(_service, required_tag)
	if catalog.is_empty():
		return GnosisFunctionResult.fail("boon_catalog_empty")
	var m3 := _service.get_node("match3", false)
	var boons_root := _service.get_node("boons", false)
	var owned := CatalogPolicyScript.collect_owned_catalog_ids(
		boons_root,
		_service.get_node("consumables", false),
		_service.get_node("upgrades", false),
	)
	var allow_dup := CatalogPolicyScript.read_allow_duplicate_catalog_offers(m3, boons_root)
	var pool := CatalogPolicyScript.build_offer_pool_from_catalog(catalog, owned.get("boon", {}), allow_dup)
	if pool.is_empty():
		return GnosisFunctionResult.fail("boon_offer_pool_empty")
	var granted := 0
	var last_boon_id := ""
	for _g in range(count):
		if pool.is_empty():
			break
		if SupportScript.read_boon_bag_empty_slot_count_by_capacity(_service, bucket_id) < 1:
			break
		var idx := _rng.randi_range(0, pool.size() - 1)
		var boon_id := pool[idx]
		if boon_id.is_empty():
			continue
		var activate_params := _service.context.store.create_object()
		activate_params.set_key("bucketId", bucket_id)
		activate_params.set_key("boonId", boon_id)
		SupportScript.apply_shop_buy_price_to_activate_boon_params(_service, activate_params, boon_id)
		var result = _service.call_service("Boon", "ActivateBoon", activate_params)
		if not _invoke_ok(result):
			continue
		granted += 1
		last_boon_id = boon_id
		_notify_boon_activated(boon_id)
		if not allow_dup:
			pool.remove_at(idx)
	if granted <= 0:
		return GnosisFunctionResult.fail("activate_boon_failed")
	SupportScript.publish_ephemeral_state(_service)
	var ok := _service.context.store.create_object()
	ok.set_key("success", true)
	ok.set_key("grantedCount", granted)
	ok.set_key("boonId", last_boon_id)
	ok.set_key("bucketId", bucket_id)
	return GnosisFunctionResult.ok(ok)


func duplicate_random_equipped_boon(params: GnosisNode) -> GnosisFunctionResult:
	if _service.context == null or _service.context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var bucket_id := CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	if params != null and params.is_valid():
		bucket_id = SupportScript._node_str(params, "bucketId", bucket_id)
	if bucket_id.is_empty():
		bucket_id = CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	if SupportScript.read_boon_bag_empty_slot_count_by_capacity(_service, bucket_id) < 1:
		return GnosisFunctionResult.fail("no_empty_boon_slot")
	var equipped := SupportScript.build_equipped_boon_catalog_ids_from_bag(_service, bucket_id)
	if equipped.is_empty():
		return GnosisFunctionResult.fail("no_equipped_boon_to_duplicate")
	var boon_id := equipped[_rng.randi_range(0, equipped.size() - 1)]
	if boon_id.is_empty():
		return GnosisFunctionResult.fail("no_equipped_boon_to_duplicate")
	var activate_params := _service.context.store.create_object()
	activate_params.set_key("bucketId", bucket_id)
	activate_params.set_key("boonId", boon_id)
	SupportScript.apply_shop_buy_price_to_activate_boon_params(_service, activate_params, boon_id)
	var result = _service.call_service("Boon", "ActivateBoon", activate_params)
	if not _invoke_ok(result):
		return GnosisFunctionResult.fail("activate_boon_failed")
	_notify_boon_activated(boon_id)
	SupportScript.publish_ephemeral_state(_service)
	var ok := _service.context.store.create_object()
	ok.set_key("success", true)
	ok.set_key("grantedCount", 1)
	ok.set_key("boonId", boon_id)
	ok.set_key("bucketId", bucket_id)
	return GnosisFunctionResult.ok(ok)


func panic_swap_all_equipped_boons(params: GnosisNode) -> GnosisFunctionResult:
	if _service.context == null or _service.context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var bucket_id := CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	if params != null and params.is_valid():
		bucket_id = SupportScript._node_str(params, "bucketId", bucket_id)
	if bucket_id.is_empty():
		bucket_id = CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	var equipped_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	if equipped_rows.is_empty():
		return GnosisFunctionResult.fail("no_equipped_boon_to_swap")
	var to_swap: Array[Dictionary] = []
	for row in equipped_rows:
		if row == null or not row.is_valid():
			continue
		var catalog_id := SupportScript.read_boon_catalog_id_from_inventory_entry(row)
		if catalog_id.is_empty():
			continue
		var instance_id := SupportScript._node_str(row, "instanceId")
		if instance_id.is_empty():
			continue
		to_swap.append({"instanceId": instance_id, "entry": row})
	if to_swap.is_empty():
		return GnosisFunctionResult.fail("no_equipped_boon_to_swap")
	var catalog := SupportScript.build_boon_catalog_ids_any_tier_from_configuration(_service)
	if catalog.is_empty():
		return GnosisFunctionResult.fail("boon_catalog_empty")
	for entry in to_swap:
		_deactivate_and_remove_boon_instance(entry["entry"], str(entry["instanceId"]))
	var swap_count := to_swap.size()
	var activated := 0
	var last_boon_id := ""
	var safety := 0
	var safety_max := maxi(swap_count * catalog.size(), swap_count * 8)
	while activated < swap_count and safety < safety_max:
		safety += 1
		var picked := catalog[_rng.randi_range(0, catalog.size() - 1)]
		if picked.is_empty():
			continue
		var activate_params := _service.context.store.create_object()
		activate_params.set_key("bucketId", bucket_id)
		activate_params.set_key("boonId", picked)
		SupportScript.apply_shop_buy_price_to_activate_boon_params(_service, activate_params, picked)
		var result = _service.call_service("Boon", "ActivateBoon", activate_params)
		if not _invoke_ok(result):
			continue
		activated += 1
		last_boon_id = picked
		_notify_boon_activated(picked)
	if activated < swap_count:
		return GnosisFunctionResult.fail("activate_boon_failed")
	if _service.has_method("sync_equipped_boon_match3_round_effects"):
		_service.call("sync_equipped_boon_match3_round_effects")
	SupportScript.publish_ephemeral_state(_service)
	var ok := _service.context.store.create_object()
	ok.set_key("success", true)
	ok.set_key("swappedCount", activated)
	ok.set_key("boonId", last_boon_id)
	ok.set_key("bucketId", bucket_id)
	return GnosisFunctionResult.ok(ok)


func try_grant_hype_train_round_start_common_boons(previous_round: int, new_round: int) -> void:
	if previous_round == new_round:
		return
	if not SupportScript.is_boon_catalog_id_equipped(_service, "HypeTrain"):
		return
	var bucket_id := CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID
	var empty_slots := SupportScript.read_boon_bag_empty_slot_count_by_capacity(_service, bucket_id)
	if empty_slots < 1:
		return
	var to_grant := mini(2, empty_slots)
	var common_catalog: Array[String] = []
	for id in SupportScript.build_boon_catalog_ids_from_configuration(_service, "common"):
		if id.to_lower() != "hypetrain":
			common_catalog.append(id)
	if common_catalog.is_empty():
		return
	var boons_root := _service.get_node("boons", false)
	var m3 := _service.get_node("match3", false)
	var owned := CatalogPolicyScript.collect_owned_catalog_ids(
		boons_root,
		_service.get_node("consumables", false),
		_service.get_node("upgrades", false),
	)
	var allow_dup := CatalogPolicyScript.read_allow_duplicate_catalog_offers(m3, boons_root)
	var pool := CatalogPolicyScript.build_offer_pool_from_catalog(common_catalog, owned.get("boon", {}), allow_dup)
	pool = pool.filter(func(id: String) -> bool: return id.to_lower() != "hypetrain")
	if pool.is_empty():
		return
	var granted := 0
	for _g in range(to_grant):
		if pool.is_empty():
			break
		var idx := _rng.randi_range(0, pool.size() - 1)
		var boon_id := pool[idx]
		var activate_params := _service.context.store.create_object()
		activate_params.set_key("bucketId", bucket_id)
		activate_params.set_key("boonId", boon_id)
		SupportScript.apply_shop_buy_price_to_activate_boon_params(_service, activate_params, boon_id)
		if not _invoke_ok(_service.call_service("Boon", "ActivateBoon", activate_params)):
			continue
		granted += 1
		if not allow_dup:
			pool.remove_at(idx)
	if granted > 0:
		SupportScript.publish_ephemeral_state(_service)


func try_grant_crypto_bro_currency_on_round_skip() -> void:
	if not SupportScript.is_boon_catalog_id_equipped(_service, "CryptoBro"):
		return
	var total_skips: int = SupportScript.read_statistic_int(_service, "match3.rounds.skipped", 0)
	if total_skips <= 0:
		return
	const DOLLARS_PER_SKIP_TIER := 4
	const GRANT_CAP := 20
	var amount := mini(GRANT_CAP, DOLLARS_PER_SKIP_TIER * total_skips)
	if amount <= 0:
		return
	var args := _service.context.store.create_object()
	args.set_key("currencyId", "money")
	args.set_key("amount", amount)
	var result = _service.call_service("Currency", "AddCurrency", args)
	if not _invoke_ok(result):
		return
	SupportScript.publish_ephemeral_state(_service)


func _deactivate_and_remove_boon_instance(slot_entry: GnosisNode, instance_id: String) -> void:
	var params := _service.context.store.create_object()
	params.set_key("instanceId", instance_id)
	params.set_key("bucketId", CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	_service.call_service("Boon", "DeactivateBoon", params)


func _invoke_ok(result) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode:
		return result.is_valid()
	return result != null


func _notify_boon_activated(boon_id: String) -> void:
	if _service != null and _service.has_method("on_boon_activated"):
		_service.call("on_boon_activated", boon_id)
