class_name Match3ShopService
extends GnosisService

## Minimal Godot port of Unity Match3ShopService.
## It exposes the Unity invoke surface and publishes a simple mixed catalog offer list.

const CatalogPolicyScript = preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")
const BoonSupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const FlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")

const SOURCE_BOONS := "boons"
const SOURCE_CONSUMABLES := "consumables"
const SOURCE_RUN_UPGRADES := "runUpgrades"
const UPGRADE_CATEGORY_RUN := "run"
const UPGRADE_CATEGORY_ITEM := "itemUpgrades"

const DEFAULT_CORE_SLOTS := 6
const DEFAULT_BOON_WEIGHT_PERCENT := 66
const DEFAULT_CONSUMABLE_WEIGHT_PERCENT := 34
const DEFAULT_ITEM_UPGRADE_WEIGHT_PERCENT := 0
const DEFAULT_BOON_COMMON_WEIGHT_PERCENT := 70
const DEFAULT_BOON_UNCOMMON_WEIGHT_PERCENT := 25
const DEFAULT_BOON_RARE_WEIGHT_PERCENT := 5
const DEFAULT_RUN_UPGRADE_SHOP_CHANCE_PERMILLE := 120
const DEFAULT_RUN_UPGRADE_PITY_EVERY_N := 5
const OFFER_CHANCE_PERMILLE_SCALE := 1000
const CURRENCY_ID := "money"
const DEFAULT_CORE_BASE_PRICE := 4
const DEFAULT_BASE_UPGRADE_PRICE := 10
const DEFAULT_MIN_PRICE := 1
const DEFAULT_MAX_SHOP_DISCOUNT := 0.5
const DEFAULT_PRICE_INFLATION_PER_FLOOR := 0.0
const DEFAULT_CORE_BASE_REROLL_PRICE := 5
const DEFAULT_CORE_REROLL_INCREMENT := 2
const FREE_REROLL_COUNT_KEY := "freeRerollCount"

var _reroll_count := 0
var _last_generated_core_round := 0
var _round_changed_subscription: RefCounted = null


func _init() -> void:
	super._init("Match3Shop", GnosisLifetime.TRANSIENT)


func on_run_started() -> void:
	super.on_run_started()
	_last_generated_core_round = 0
	_reroll_count = 0
	_generate_core_offer_for_queued_round()


func on_initialize() -> void:
	if context and context.event_bus:
		_round_changed_subscription = context.event_bus.subscribe(
			Match3EventsScript.FACT_MATCH3_ROUND_CHANGED,
			_on_match3_round_changed,
			0,
		)
	_ensure_core_shop()


func on_shutdown() -> void:
	if _round_changed_subscription and _round_changed_subscription.has_method("dispose"):
		_round_changed_subscription.dispose()
	_round_changed_subscription = null
	super.on_shutdown()


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
			return _reroll_core_shop(parameters)
		"PurchaseCoreItem":
			return _purchase_core_item(parameters)
		"RemoveUpgrade":
			return _remove_upgrade(parameters)
		"ResolveCatalogShopBuyPrice":
			return GnosisFunctionResult.ok(_resolve_price_payload(parameters))
		"RecordInventorySale":
			_increment_statistic("match3.shop.sales.total", 1)
			return GnosisFunctionResult.ok(context.store.create_value(true))
	return GnosisFunctionResult.fail("Unknown Match3Shop function '%s'." % name)


func _ensure_core_shop() -> GnosisNode:
	var shop: GnosisNode = get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		shop = context.store.create_object()
		set_node("match3Shop", shop, false)
	var core: GnosisNode = shop.get_node("core")
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		core = context.store.create_object()
		shop.set_key("core", core)
	_ensure_core_offers_for_queued_round()
	return shop


func _read_queued_round() -> int:
	var m3 := get_node("match3", false)
	var current_round := maxi(1, _node_int(m3, "currentRound", 1))
	return maxi(1, _node_int(m3, "nextLevel", current_round))


func _ensure_core_offers_for_queued_round() -> void:
	var queued_round := _read_queued_round()
	if queued_round != _last_generated_core_round:
		_replace_core_offer_for_round(queued_round)


func _generate_core_offer_for_queued_round() -> void:
	_replace_core_offer_for_round(_read_queued_round())


func _replace_core_offer_for_round(round: int) -> void:
	var safe_round := maxi(1, round)
	if safe_round == _last_generated_core_round:
		return
	_last_generated_core_round = safe_round
	_reroll_count = 0
	_rebuild_core_shop_offers()


func _on_match3_round_changed(event: GnosisEvent) -> void:
	if event == null:
		_generate_core_offer_for_queued_round()
		return
	var data := event.data
	if data != null and data.is_valid() and data.get_type() == GnosisValueType.OBJECT:
		var round_from_event := _node_int(data, "currentRound", -1)
		if round_from_event > 0:
			_replace_core_offer_for_round(round_from_event)
			return
	_generate_core_offer_for_queued_round()


func _rebuild_core_shop_offers() -> GnosisNode:
	var shop: GnosisNode = get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		shop = context.store.create_object()
		set_node("match3Shop", shop, false)
	var core := shop.get_node("core")
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		core = context.store.create_object()
		shop.set_key("core", core)
	var tuning: Dictionary = _read_full_core_shop_tuning(core)
	var offers: GnosisNode = context.store.create_list()
	if int(tuning["slots"]) > 0:
		for entry in _roll_core_offer_entries(tuning, core):
			offers.add(entry)
	core.set_key("offers", offers)
	core.set_key("rerollCount", _reroll_count)
	_sync_core_reroll_price_fields(core)
	shop.set_key("core", core)
	_commit_shop()
	return shop


func _roll_core_offer_entries(tuning: Dictionary, core: GnosisNode) -> Array[GnosisNode]:
	var result: Array[GnosisNode] = []
	var slots: int = int(tuning["slots"])
	if slots <= 0 or context == null or context.store == null:
		return result

	var m3 := get_node("match3", false)
	var boons_root := get_node("boons", false)
	var allow_dup := CatalogPolicyScript.read_allow_duplicate_catalog_offers(m3, boons_root)
	var owned_all := CatalogPolicyScript.collect_owned_catalog_ids(
		boons_root,
		get_node("consumables", false),
		get_node("upgrades", false),
	)
	var owned_boons: Dictionary = {} if allow_dup else owned_all.get("boon", {})
	var owned_consumables: Dictionary = {} if allow_dup else owned_all.get("consumable", {})
	_relax_owned_consumables_for_stackable_item_upgrade_grants(owned_consumables)

	var boon_pool: Array[String] = CatalogPolicyScript.build_offer_pool_from_catalog(
		_build_catalog_ids(SOURCE_BOONS),
		owned_boons,
		allow_dup,
	)
	boon_pool = _exclude_boons_with_gameplay_tag(
		boon_pool,
		BoonSupportScript.BOON_GAMEPLAY_TAG_LEGENDARY,
	)

	var consumable_pool: Array[String] = CatalogPolicyScript.build_offer_pool_from_catalog(
		_build_catalog_ids(SOURCE_CONSUMABLES),
		owned_consumables,
		allow_dup,
	)
	consumable_pool = _remove_grant_consumables_at_max_item_upgrade_count(consumable_pool)

	var run_pool: Array[String] = _build_eligible_run_upgrade_pool()
	var pity_counter := _node_int(core, "shopsSinceRunUpgradeOffer", 0)
	var could_offer_run := not run_pool.is_empty()
	var pity := could_offer_run and pity_counter >= int(tuning["run_upgrade_pity_every_n"])
	var roll := _seed_range_int(0, OFFER_CHANCE_PERMILLE_SCALE, OFFER_CHANCE_PERMILLE_SCALE)
	var got_roll := could_offer_run and not pity and roll < int(tuning["run_upgrade_shop_chance_permille"])
	var want_run_offer := pity or got_roll

	var picked_run_id := ""
	var picked_run_price := 0
	if want_run_offer and not run_pool.is_empty():
		var run_pick := _seed_range_int(0, run_pool.size(), 0)
		picked_run_id = run_pool[clampi(run_pick, 0, run_pool.size() - 1)]
		picked_run_price = _resolve_upgrade_price(picked_run_id, _current_floor())

	var drafted: Array[Dictionary] = []
	var non_run_slots := slots - (0 if picked_run_id.is_empty() else 1)
	for _i in non_run_slots:
		var source := _pick_core_source_config(
			tuning,
			boon_pool.size(),
			consumable_pool.size(),
			0,
		)
		if source.is_empty():
			break
		var item_id := ""
		if source == SOURCE_BOONS:
			if boon_pool.is_empty():
				continue
			item_id = _pick_weighted_boon_id(boon_pool, tuning)
			if not allow_dup and not item_id.is_empty():
				_remove_id_from_pool(boon_pool, item_id)
		elif source == SOURCE_CONSUMABLES:
			if consumable_pool.is_empty():
				continue
			item_id = _pick_weighted_consumable_id(consumable_pool)
			if not allow_dup and not item_id.is_empty():
				_remove_id_from_pool(consumable_pool, item_id)
		if item_id.is_empty():
			continue
		drafted.append({
			"sourceConfigId": source,
			"itemId": item_id,
			"price": _resolve_core_offer_price(source, item_id),
		})

	if not picked_run_id.is_empty():
		var run_entry := {
			"sourceConfigId": SOURCE_RUN_UPGRADES,
			"itemId": picked_run_id,
			"price": picked_run_price,
		}
		if drafted.is_empty():
			drafted.append(run_entry)
		else:
			var insert_at := _seed_range_int(0, drafted.size() + 1, drafted.size())
			drafted.insert(clampi(insert_at, 0, drafted.size()), run_entry)

	var has_run_in_shop := false
	for entry in drafted:
		if str(entry.get("sourceConfigId", "")) == SOURCE_RUN_UPGRADES:
			has_run_in_shop = true
			break
	if not could_offer_run:
		core.set_key("shopsSinceRunUpgradeOffer", 0)
	elif has_run_in_shop:
		core.set_key("shopsSinceRunUpgradeOffer", 0)
	else:
		core.set_key("shopsSinceRunUpgradeOffer", pity_counter + 1)

	for i in drafted.size():
		var draft: Dictionary = drafted[i]
		var offer := context.store.create_object()
		offer.set_key("index", i)
		offer.set_key("sourceConfigId", str(draft.get("sourceConfigId", "")))
		offer.set_key("itemId", str(draft.get("itemId", "")))
		offer.set_key("price", int(draft.get("price", 0)))
		offer.set_key("available", true)
		if str(draft.get("sourceConfigId", "")) == SOURCE_BOONS:
			_roll_boon_flavors_for_shop_offer(offer, str(draft.get("itemId", "")), i)
		result.append(offer)
	return result


func _roll_boon_flavors_for_shop_offer(offer: GnosisNode, boon_id: String, offer_index: int) -> void:
	if offer == null or not offer.is_valid() or context == null or context.store == null:
		return
	var catalog_id := boon_id.strip_edges()
	if catalog_id.is_empty():
		return
	var config_root := get_node("configuration", true)
	if not config_root.is_valid():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%s" % [_read_run_seed_hint(), catalog_id, offer_index])
	FlavorsScript.roll_flavors_onto_object(offer, catalog_id, config_root, context.store, rng)


func _build_catalog_ids(config_id: String) -> Array[String]:
	var result: Array[String] = []
	var config := get_node("configuration", true)
	if not config.is_valid():
		return result
	var catalog := config.get_node(config_id)
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return result
	var ids := catalog.get_keys()
	ids.sort()
	for item_id in ids:
		var sid := str(item_id).strip_edges()
		if not sid.is_empty():
			result.append(sid)
	return result


func _pick_core_source_config(
	tuning: Dictionary,
	boon_count: int,
	consumable_count: int,
	item_upgrade_count: int,
) -> String:
	var has_boons := boon_count > 0
	var has_consumables := consumable_count > 0
	var has_item_upgrades := item_upgrade_count > 0
	if not has_boons and not has_consumables and not has_item_upgrades:
		return ""
	if has_boons and not has_consumables and not has_item_upgrades:
		return SOURCE_BOONS
	if not has_boons and has_consumables and not has_item_upgrades:
		return SOURCE_CONSUMABLES
	if not has_boons and not has_consumables and has_item_upgrades:
		return "itemUpgrades"

	var boon_weight: int = maxi(0, int(tuning["boon_weight_percent"])) if has_boons else 0
	var consumable_weight: int = maxi(0, int(tuning["consumable_weight_percent"])) if has_consumables else 0
	var item_upgrade_weight: int = maxi(0, int(tuning["item_upgrade_weight_percent"])) if has_item_upgrades else 0
	var total_weight := boon_weight + consumable_weight + item_upgrade_weight
	if total_weight <= 0:
		var available: Array[String] = []
		if has_boons:
			available.append(SOURCE_BOONS)
		if has_consumables:
			available.append(SOURCE_CONSUMABLES)
		if has_item_upgrades:
			available.append("itemUpgrades")
		if available.is_empty():
			return ""
		var pick := _seed_range_int(0, available.size(), 0)
		return available[clampi(pick, 0, available.size() - 1)]

	var source_roll := _seed_range_int(0, total_weight, 0)
	if source_roll < boon_weight:
		return SOURCE_BOONS
	source_roll -= boon_weight
	if source_roll < consumable_weight:
		return SOURCE_CONSUMABLES
	return "itemUpgrades"


func _pick_weighted_boon_id(boon_pool: Array[String], tuning: Dictionary) -> String:
	if boon_pool.is_empty():
		return ""
	var weights: Array[int] = []
	var total_weight := 0
	for boon_id in boon_pool:
		var weight := maxi(0, _resolve_boon_weight_by_rarity(boon_id, tuning))
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0:
		var uniform_pick := _seed_range_int(0, boon_pool.size(), 0)
		return boon_pool[clampi(uniform_pick, 0, boon_pool.size() - 1)]
	var roll := _seed_range_int(0, total_weight, 0)
	var running := 0
	for i in boon_pool.size():
		running += weights[i]
		if roll < running:
			return boon_pool[i]
	return boon_pool[boon_pool.size() - 1]


func _resolve_boon_weight_by_rarity(boon_id: String, tuning: Dictionary) -> int:
	var rarity := _resolve_boon_rarity_tag(boon_id)
	match rarity:
		BoonSupportScript.BOON_GAMEPLAY_TAG_LEGENDARY:
			return 0
		"rare":
			return int(tuning["boon_rare_weight_percent"])
		"uncommon":
			return int(tuning["boon_uncommon_weight_percent"])
		_:
			return int(tuning["boon_common_weight_percent"])


func _resolve_boon_rarity_tag(boon_id: String) -> String:
	var sid := boon_id.strip_edges()
	if sid.is_empty():
		return "common"
	var config := get_node("configuration", true)
	if not config.is_valid():
		return "common"
	var boon := config.get_node("%s.%s" % [SOURCE_BOONS, sid])
	if not boon.is_valid() or boon.get_type() != GnosisValueType.OBJECT:
		return "common"
	for tag in ["rare", "uncommon", "common", BoonSupportScript.BOON_GAMEPLAY_TAG_LEGENDARY]:
		if BoonSupportScript.boon_configuration_gameplay_tags_include(boon, tag):
			return tag
	return "common"


func _exclude_boons_with_gameplay_tag(pool: Array[String], gameplay_tag: String) -> Array[String]:
	var filtered: Array[String] = []
	var config := get_node("configuration", true)
	for boon_id in pool:
		var entry := config.get_node("%s.%s" % [SOURCE_BOONS, boon_id]) if config.is_valid() else _invalid_node()
		if entry.is_valid() and BoonSupportScript.boon_configuration_gameplay_tags_include(entry, gameplay_tag):
			continue
		filtered.append(boon_id)
	return filtered


func _pick_weighted_consumable_id(consumable_pool: Array[String]) -> String:
	if consumable_pool.is_empty():
		return ""
	var reserved: Array = []
	var common: Array[String] = []
	for consumable_id in consumable_pool:
		var sid := consumable_id.strip_edges()
		if sid.is_empty():
			continue
		var permille := clampi(_read_consumable_offer_chance_permille(sid), 0, OFFER_CHANCE_PERMILLE_SCALE)
		if permille > 0:
			reserved.append({"id": sid, "permille": permille})
		else:
			common.append(sid)
	if reserved.is_empty() and common.is_empty():
		return ""
	if reserved.size() > 1:
		reserved.sort_custom(func(a, b): return str(a["id"]).to_lower() < str(b["id"]).to_lower())

	var reserved_sum := 0
	for entry in reserved:
		reserved_sum += int(entry["permille"])
	if reserved_sum > OFFER_CHANCE_PERMILLE_SCALE and reserved_sum > 0:
		var scaled_sum := 0
		for entry in reserved:
			var scaled := int(int(entry["permille"]) * OFFER_CHANCE_PERMILLE_SCALE / reserved_sum)
			entry["permille"] = scaled
			scaled_sum += scaled
		reserved_sum = scaled_sum

	var roll := _seed_range_int(0, OFFER_CHANCE_PERMILLE_SCALE, 0)
	var cursor := 0
	for entry in reserved:
		var next := cursor + int(entry["permille"])
		if roll < next:
			return str(entry["id"])
		cursor = next

	if common.is_empty():
		return _pick_uniform_from_pool(consumable_pool)
	var common_band := OFFER_CHANCE_PERMILLE_SCALE - cursor
	if common_band <= 0:
		return _pick_uniform_from_pool(common)

	var local_roll := clampi(roll - cursor, 0, common_band - 1)
	var relative_weight := maxi(0, _read_default_consumable_offer_chance_permille())
	if relative_weight <= 0:
		var idx := int(local_roll * common.size() / common_band)
		return common[clampi(idx, 0, common.size() - 1)]

	var common_weight_sum := relative_weight * common.size()
	if common_weight_sum <= 0:
		return _pick_uniform_from_pool(common)
	var mapped := int(local_roll * common_weight_sum / common_band)
	mapped = clampi(mapped, 0, common_weight_sum - 1)
	var pick := int(mapped / relative_weight)
	return common[clampi(pick, 0, common.size() - 1)]


func _read_consumable_offer_chance_permille(consumable_id: String) -> int:
	var config := get_node("configuration", true)
	if not config.is_valid():
		return 0
	var entry := config.get_node("%s.%s" % [SOURCE_CONSUMABLES, consumable_id.strip_edges()])
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return 0
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return 0
	var node := props.get_node("offerChancePermille")
	if not node.is_valid():
		return 0
	match node.get_type():
		GnosisValueType.INT, GnosisValueType.FLOAT:
			return clampi(int(node.value), 0, OFFER_CHANCE_PERMILLE_SCALE)
	return 0


func _read_default_consumable_offer_chance_permille() -> int:
	var shop := get_node("match3Shop", false)
	if not shop.is_valid():
		return 0
	var core := shop.get_node("core")
	return maxi(0, _node_int(core, "defaultConsumableOfferChancePermille", 0))


func _relax_owned_consumables_for_stackable_item_upgrade_grants(owned_consumables: Dictionary) -> void:
	if owned_consumables.is_empty():
		return
	var config := get_node("configuration", true)
	if not config.is_valid():
		return
	var consumables_root := config.get_node(SOURCE_CONSUMABLES)
	if not consumables_root.is_valid() or consumables_root.get_type() != GnosisValueType.OBJECT:
		return
	var to_remove: Array[String] = []
	for owned_id in owned_consumables.keys():
		var entry := consumables_root.get_node(str(owned_id).strip_edges())
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var metadata := entry.get_node("metadata")
		if not metadata.is_valid() or metadata.get_type() != GnosisValueType.OBJECT:
			continue
		var grant_id := _node_string(metadata, "grantItemUpgradeId", "")
		if grant_id.is_empty():
			continue
		if _is_item_upgrade_eligible_for_more(grant_id):
			to_remove.append(str(owned_id))
	for owned_id in to_remove:
		owned_consumables.erase(owned_id.to_lower())


func _remove_grant_consumables_at_max_item_upgrade_count(consumable_pool: Array[String]) -> Array[String]:
	var filtered: Array[String] = []
	var config := get_node("configuration", true)
	if not config.is_valid():
		return consumable_pool.duplicate()
	var consumables_root := config.get_node(SOURCE_CONSUMABLES)
	for consumable_id in consumable_pool:
		var sid := consumable_id.strip_edges()
		if sid.is_empty():
			continue
		var entry := consumables_root.get_node(sid) if consumables_root.is_valid() else _invalid_node()
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			filtered.append(sid)
			continue
		var metadata := entry.get_node("metadata")
		if not metadata.is_valid() or metadata.get_type() != GnosisValueType.OBJECT:
			filtered.append(sid)
			continue
		var grant_id := _node_string(metadata, "grantItemUpgradeId", "")
		if not grant_id.is_empty() and not _is_item_upgrade_eligible_for_more(grant_id):
			continue
		filtered.append(sid)
	return filtered


func _is_item_upgrade_eligible_for_more(upgrade_id: String) -> bool:
	var sid := upgrade_id.strip_edges()
	if sid.is_empty():
		return false
	return _get_item_upgrade_quantity(sid) < _read_item_upgrade_max_count(sid)


func _get_item_upgrade_quantity(upgrade_id: String) -> int:
	if context == null or context.store == null:
		return 0
	var params := context.store.create_object()
	params.set_key("categoryId", UPGRADE_CATEGORY_ITEM)
	params.set_key("upgradeId", upgrade_id.strip_edges())
	var result = call_service("Upgrade", "HasUpgrade", params)
	if result is GnosisNode and result.is_valid():
		return maxi(0, _node_int(result, "quantity", 0))
	return 0


func _read_item_upgrade_max_count(upgrade_id: String) -> int:
	var config := get_node("configuration", true)
	if not config.is_valid():
		return 1
	var entry := config.get_node("%s.%s" % ["itemUpgrades", upgrade_id.strip_edges()])
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return 1
	var props := entry.get_node("properties")
	return maxi(1, _node_int(props, "maxCount", 1))


func _build_eligible_run_upgrade_pool() -> Array[String]:
	var catalog := _build_catalog_ids(SOURCE_RUN_UPGRADES)
	if context == null or context.store == null:
		return catalog
	var params := context.store.create_object()
	params.set_key("categoryId", UPGRADE_CATEGORY_RUN)
	var result = call_service("Upgrade", "GetEligibleUpgradeIds", params)
	if not (result is GnosisNode and result.is_valid()):
		return catalog
	var eligible: Dictionary = {}
	var list: GnosisNode = result.get_node("upgradeIds")
	if list.is_valid() and list.get_type() == GnosisValueType.LIST:
		for i in list.get_count():
			var entry: GnosisNode = list.get_node(i)
			var upgrade_id: String = _node_string(entry, "upgradeId", "")
			if upgrade_id.is_empty() and entry.is_valid() and entry.get_type() == GnosisValueType.STRING:
				upgrade_id = str(entry.value).strip_edges()
			if not upgrade_id.is_empty():
				eligible[upgrade_id.to_lower()] = upgrade_id
	var pool: Array[String] = []
	for upgrade_id in catalog:
		var key: String = upgrade_id.strip_edges().to_lower()
		if eligible.has(key):
			pool.append(eligible[key])
	return pool


func _remove_id_from_pool(pool: Array[String], item_id: String) -> void:
	var want := item_id.strip_edges().to_lower()
	if want.is_empty():
		return
	for i in range(pool.size() - 1, -1, -1):
		if pool[i].strip_edges().to_lower() == want:
			pool.remove_at(i)


func _pick_uniform_from_pool(ids: Array[String]) -> String:
	if ids.is_empty():
		return ""
	var idx := _seed_range_int(0, ids.size(), 0)
	return ids[clampi(idx, 0, ids.size() - 1)]


func _seed_range_int(min_inclusive: int, max_exclusive: int, fallback: int) -> int:
	if max_exclusive <= min_inclusive or context == null or context.engine == null or context.store == null:
		return fallback
	var args := context.store.create_object()
	args.set_key("min", min_inclusive)
	args.set_key("max", max_exclusive)
	var result = call_service("Seed", "RangeInt", args)
	if result is GnosisNode and result.is_valid():
		var value: GnosisNode = result.get_node("value")
		if value.is_valid():
			return int(value.value)
	return fallback


func _read_full_core_shop_tuning(core: GnosisNode) -> Dictionary:
	return {
		"slots": _node_int(core, "slots", DEFAULT_CORE_SLOTS),
		"boon_weight_percent": _node_int(core, "boonWeightPercent", DEFAULT_BOON_WEIGHT_PERCENT),
		"consumable_weight_percent": _node_int(core, "consumableWeightPercent", DEFAULT_CONSUMABLE_WEIGHT_PERCENT),
		"item_upgrade_weight_percent": _node_int(core, "itemUpgradeWeightPercent", DEFAULT_ITEM_UPGRADE_WEIGHT_PERCENT),
		"boon_common_weight_percent": _node_int(core, "boonCommonWeightPercent", DEFAULT_BOON_COMMON_WEIGHT_PERCENT),
		"boon_uncommon_weight_percent": _node_int(core, "boonUncommonWeightPercent", DEFAULT_BOON_UNCOMMON_WEIGHT_PERCENT),
		"boon_rare_weight_percent": _node_int(core, "boonRareWeightPercent", DEFAULT_BOON_RARE_WEIGHT_PERCENT),
		"run_upgrade_shop_chance_permille": _node_int(
			core,
			"runUpgradeShopChancePermille",
			DEFAULT_RUN_UPGRADE_SHOP_CHANCE_PERMILLE,
		),
		"run_upgrade_pity_every_n": _node_int(core, "runUpgradePityEveryN", DEFAULT_RUN_UPGRADE_PITY_EVERY_N),
	}


func _reroll_core_shop(parameters: GnosisNode) -> GnosisFunctionResult:
	var force_free := _node_bool(parameters, "isFree", false)
	var used_free_bank := false if force_free else _try_consume_free_reroll_from_bank()
	var is_free := force_free or used_free_bank
	var money_before := _get_money_balance()
	var reroll_price := 0 if is_free else _current_core_reroll_price()
	if not is_free and reroll_price > 0 and not _try_spend_currency(reroll_price):
		return GnosisFunctionResult.fail("not_enough_money")
	var shop := _rebuild_core_shop_offers()
	if not is_free:
		_reroll_count += 1
		var rebuilt_core := shop.get_node("core")
		rebuilt_core.set_key("rerollCount", _reroll_count)
		_sync_core_reroll_price_fields(rebuilt_core)
	_increment_statistic("match3.shop.rerolls.total", 1)
	if context != null and context.store != null:
		var scaling_params := context.store.create_object()
		call_service("Match3", "ApplyShopRerollScalingAfterCoreShopReroll", scaling_params)
	var payload := _build_core_reroll_response_payload(shop, reroll_price, money_before, is_free, used_free_bank)
	return GnosisFunctionResult.ok(payload)


func _remove_upgrade(parameters: GnosisNode) -> GnosisFunctionResult:
	var upgrade_id := _node_string(parameters, "upgradeId", "").strip_edges()
	if upgrade_id.is_empty():
		return GnosisFunctionResult.fail("Missing upgradeId.")
	var params := context.store.create_object()
	params.set_key("categoryId", UPGRADE_CATEGORY_RUN)
	params.set_key("upgradeId", upgrade_id)
	var result = call_service("Upgrade", "RemoveUpgrade", params)
	if result == null or not (result is GnosisNode) or not result.is_valid():
		return GnosisFunctionResult.fail("RemoveUpgrade failed.")
	return GnosisFunctionResult.ok(result)


func _read_free_reroll_count() -> int:
	var shop := get_node("match3Shop", false)
	var core := shop.get_node("core") if shop.is_valid() else _invalid_node()
	return maxi(0, _node_int(core, FREE_REROLL_COUNT_KEY, 0))


func _write_free_reroll_count(count: int) -> void:
	var shop := get_node("match3Shop", false)
	if not shop.is_valid() or shop.get_type() != GnosisValueType.OBJECT:
		return
	var core := shop.get_node("core")
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		return
	core.set_key(FREE_REROLL_COUNT_KEY, maxi(0, count))


func _try_consume_free_reroll_from_bank() -> bool:
	var count := _read_free_reroll_count()
	if count <= 0:
		return false
	_write_free_reroll_count(count - 1)
	return true


func _effective_core_reroll_price() -> int:
	if _read_free_reroll_count() > 0:
		return 0
	return _current_core_reroll_price()


func _sync_core_reroll_price_fields(core: GnosisNode) -> void:
	if not core.is_valid() or core.get_type() != GnosisValueType.OBJECT:
		return
	var free_count := maxi(0, _node_int(core, FREE_REROLL_COUNT_KEY, _read_free_reroll_count()))
	core.set_key(FREE_REROLL_COUNT_KEY, free_count)
	var paid_price := _current_core_reroll_price()
	core.set_key("paidRerollPrice", paid_price)
	core.set_key("currentRerollPrice", 0 if free_count > 0 else paid_price)
	core.set_key("nextRerollIsFree", free_count > 0)


func _append_free_reroll_fields_to_payload(payload: GnosisNode) -> void:
	if not payload.is_valid() or payload.get_type() != GnosisValueType.OBJECT:
		return
	var free_count := _read_free_reroll_count()
	payload.set_key(FREE_REROLL_COUNT_KEY, free_count)
	payload.set_key("currentRerollPrice", _effective_core_reroll_price())
	payload.set_key("paidRerollPrice", _current_core_reroll_price())
	payload.set_key("nextRerollIsFree", free_count > 0)


func _get_money_balance() -> int:
	if context == null or context.store == null:
		return 0
	var params := context.store.create_object()
	params.set_key("currencyId", CURRENCY_ID)
	var result = call_service("Currency", "GetBalance", params)
	if result is GnosisFunctionResult and result.is_ok and result.payload != null and result.payload.is_valid():
		return _node_int(result.payload, "balance", 0)
	if result is GnosisNode and result.is_valid():
		return _node_int(result, "balance", 0)
	return 0


func _build_core_reroll_response_payload(
	shop: GnosisNode,
	reroll_price_paid: int,
	money_before: int,
	is_free: bool,
	used_free_bank: bool
) -> GnosisNode:
	var payload := shop if shop.is_valid() else context.store.create_object()
	if payload.get_type() != GnosisValueType.OBJECT:
		payload = context.store.create_object()
	payload.set_key("rerollPricePaid", reroll_price_paid)
	payload.set_key("moneyBefore", money_before)
	payload.set_key("moneyAfter", _get_money_balance())
	payload.set_key("isFree", is_free)
	payload.set_key("usedFreeRerollBank", used_free_bank)
	_append_free_reroll_fields_to_payload(payload)
	return payload


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
	var source := _node_string(offer, "sourceConfigId", "")
	var item_id := _node_string(offer, "itemId", "")
	if not _try_apply_core_offer_purchase(source, item_id, price, offer):
		if price > 0:
			_refund_currency(price)
		return GnosisFunctionResult.fail("purchase_core_item_failed")
	offer.set_key("purchased", true)
	offer.set_key("available", false)
	if source == "runUpgrades":
		_increment_statistic("match3.shop.upgrades.purchased.total", 1)
	else:
		_increment_statistic("match3.shop.purchases.total", 1)
	_commit_shop()
	return GnosisFunctionResult.ok(offer)


func _try_apply_core_offer_purchase(
	source_config_id: String,
	item_id: String,
	buy_price: int,
	offer: GnosisNode = null,
) -> bool:
	if context == null or context.store == null or item_id.strip_edges().is_empty():
		return false
	var source := source_config_id.strip_edges().to_lower()
	var params := context.store.create_object()
	match source:
		"runupgrades":
			params.set_key("categoryId", "run")
			params.set_key("upgradeId", item_id.strip_edges())
			return _service_invoke_succeeded(call_service("Upgrade", "AddUpgrade", params))
		"boons":
			params.set_key("bucketId", "default")
			params.set_key("boonId", item_id.strip_edges())
			if buy_price > 0:
				params.set_key("buyPrice", float(buy_price))
			if offer != null and offer.is_valid():
				FlavorsScript.copy_flavor_property_keys(offer, params)
			return _service_invoke_succeeded(call_service("Boon", "ActivateBoon", params))
		"consumables":
			params.set_key("bucketId", "default")
			params.set_key("consumableId", item_id.strip_edges())
			if buy_price > 0:
				params.set_key("buyPrice", float(buy_price))
			return _service_invoke_succeeded(call_service("Consumable", "AddConsumable", params))
		_:
			return false


func _refund_currency(amount: int) -> void:
	if amount <= 0 or context == null or context.store == null:
		return
	var params := context.store.create_object()
	params.set_key("currencyId", CURRENCY_ID)
	params.set_key("amount", amount)
	call_service("Currency", "AddCurrency", params)


func _service_invoke_succeeded(result) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode:
		return result.is_valid()
	return result != null


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
	var item_id := _node_string(parameters, "itemId", "")
	var price := _resolve_core_offer_price(config_id, item_id)
	payload.set_key("price", price)
	payload.set_key("currencyId", CURRENCY_ID)
	return payload


func _resolve_core_offer_price(source_config_id: String, item_id: String) -> int:
	var source := source_config_id.strip_edges()
	var catalog_id := item_id.strip_edges()
	if source.to_lower() == "runupgrades":
		return _resolve_upgrade_price(catalog_id, _current_floor())
	var core_tuning: Dictionary = _read_core_shop_tuning()
	var shared: Dictionary = _read_shop_tuning()
	var override_price: int = _read_config_base_price_override(source, catalog_id)
	var effective_base: float = float(override_price) if override_price >= 0 else float(core_tuning["base_price"])
	var floor_multiplier: float = 1.0 + (float(maxi(1, _current_floor())) - 1.0) * float(shared["price_inflation_per_floor_percent"])
	var discount_percent: float = _shop_discount_percent(float(shared["max_discount_percent"]))
	var discounted: float = effective_base * floor_multiplier * (1.0 - discount_percent)
	return maxi(int(shared["min_price"]), int(round(discounted)))


func _resolve_upgrade_price(upgrade_id: String, floor_number: int) -> int:
	var shared: Dictionary = _read_shop_tuning()
	var effective_base: float = _resolve_base_price_for_upgrade(upgrade_id, shared)
	var floor_multiplier: float = 1.0 + (float(maxi(1, floor_number)) - 1.0) * float(shared["price_inflation_per_floor_percent"])
	var discount_percent: float = _shop_discount_percent(float(shared["max_discount_percent"]))
	var discounted: float = effective_base * floor_multiplier * (1.0 - discount_percent)
	return maxi(int(shared["min_price"]), int(round(discounted)))


func _resolve_base_price_for_upgrade(upgrade_id: String, shared: Dictionary) -> float:
	var sid := upgrade_id.strip_edges()
	if sid.is_empty():
		return float(shared["base_price"])
	var config: GnosisNode = get_node("configuration", true)
	if not config.is_valid():
		return float(shared["base_price"])
	var upgrades: GnosisNode = config.get_node("runUpgrades")
	if not upgrades.is_valid():
		return float(shared["base_price"])
	var entry: GnosisNode = upgrades.get_node(sid)
	if not entry.is_valid():
		return float(shared["base_price"])
	var metadata: GnosisNode = entry.get_node("metadata")
	if metadata.is_valid():
		var metadata_price: int = _node_int(metadata, "shopPrice", -1)
		if metadata_price >= 0:
			return float(metadata_price)
	return float(shared["base_price"])


func _read_config_base_price_override(source_config_id: String, item_id: String) -> int:
	var source := source_config_id.strip_edges()
	var sid := item_id.strip_edges()
	if source.is_empty() or sid.is_empty():
		return -1
	var config := get_node("configuration", true)
	if not config.is_valid():
		return -1
	var category := config.get_node(source)
	if not category.is_valid():
		return -1
	var entry := category.get_node(sid)
	if not entry.is_valid():
		return -1
	var properties := entry.get_node("properties")
	if properties.is_valid():
		var from_properties := _node_int(properties, "basePrice", -1)
		if from_properties >= 0:
			return from_properties
	var metadata := entry.get_node("metadata")
	if metadata.is_valid():
		return _node_int(metadata, "shopPrice", -1)
	return -1


func _read_core_shop_tuning() -> Dictionary:
	var shop: GnosisNode = get_node("match3Shop", false)
	var core: GnosisNode = shop.get_node("core") if shop.is_valid() else _invalid_node()
	return {
		"base_price": _node_int(core, "basePrice", DEFAULT_CORE_BASE_PRICE),
		"base_reroll_price": _node_int(core, "baseRerollPrice", DEFAULT_CORE_BASE_REROLL_PRICE),
		"reroll_price_increment": _node_int(core, "rerollPriceIncrement", DEFAULT_CORE_REROLL_INCREMENT),
	}


func _read_shop_tuning() -> Dictionary:
	var shop: GnosisNode = get_node("match3Shop", false)
	var upgrades: GnosisNode = shop.get_node("upgrades") if shop.is_valid() else _invalid_node()
	return {
		"base_price": _node_int(upgrades, "basePrice", DEFAULT_BASE_UPGRADE_PRICE),
		"min_price": _node_int(shop, "minPrice", DEFAULT_MIN_PRICE),
		"max_discount_percent": _node_float(shop, "maxShopDiscountPercent", DEFAULT_MAX_SHOP_DISCOUNT),
		"price_inflation_per_floor_percent": _node_float(
			shop,
			"priceInflationPerFloorPercent",
			DEFAULT_PRICE_INFLATION_PER_FLOOR,
		),
	}


func _read_run_seed_hint() -> int:
	if context == null or context.engine == null:
		return 0
	var seed_svc = context.engine.get_service("Seed")
	if seed_svc != null and seed_svc.has_method("get_run_seed"):
		return int(seed_svc.get_run_seed())
	return 0


func _invalid_node() -> GnosisNode:
	return GnosisNode.new(null)


func _current_floor() -> int:
	var m3 := get_node("match3", false)
	return maxi(1, _node_int(m3, "currentFloor", 1))


func _shop_discount_percent(max_discount: float) -> float:
	var shop := get_node("match3Shop", false)
	var raw := _node_float(shop, "shopDiscountPercent", 0.0)
	return clampf(raw, 0.0, maxf(0.0, max_discount))


func _current_core_reroll_price() -> int:
	var tuning: Dictionary = _read_core_shop_tuning()
	var raw := maxi(0, int(tuning["base_reroll_price"]) + (_reroll_count * int(tuning["reroll_price_increment"])))
	if raw <= 0:
		return 0
	var shop := get_node("match3Shop", false)
	var core := shop.get_node("core") if shop.is_valid() else _invalid_node()
	var flat_discount := maxi(0, _node_int(core, "rerollFlatDiscount", 0))
	return maxi(1, raw - flat_discount)


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


func _node_float(node: GnosisNode, key: String, default_value: float = 0.0) -> float:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return float(child.value)
