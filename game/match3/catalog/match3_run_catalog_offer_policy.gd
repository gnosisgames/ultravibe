class_name Match3RunCatalogOfferPolicy
extends RefCounted

## Run-wide catalog offer rules (Unity Match3RunCatalogOfferPolicy parity).

const DEFAULT_BOON_BUCKET_ID := "default"
const DEFAULT_CONSUMABLE_BUCKET_ID := "default"
const DEFAULT_ITEM_UPGRADE_CATEGORY_ID := "itemUpgrades"
const BOON_CATALOG_ID_MANIFESTATION := "Manifestation"


static func read_allow_duplicate_catalog_offers(_match3_ephemeral: GnosisNode, boon_buckets_root: GnosisNode) -> bool:
	return is_boon_catalog_id_equipped_in_default_bag(boon_buckets_root, BOON_CATALOG_ID_MANIFESTATION)


static func is_boon_catalog_id_equipped_in_default_bag(boon_buckets_root: GnosisNode, catalog_id: String) -> bool:
	var want := catalog_id.strip_edges()
	if want.is_empty() or boon_buckets_root == null or not boon_buckets_root.is_valid() or boon_buckets_root.get_type() != GnosisValueType.OBJECT:
		return false
	var bag := boon_buckets_root.get_node(DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return false
	var owned: Dictionary = {}
	_append_catalog_ids_from_object_list(bag.get_node("list"), owned, "boonId", "id")
	return owned.has(want.to_lower())


static func collect_owned_catalog_ids(
	boon_buckets_root: GnosisNode,
	consumable_buckets_root: GnosisNode,
	upgrades_root: GnosisNode,
	boon_bucket_id: String = DEFAULT_BOON_BUCKET_ID,
	consumable_bucket_id: String = DEFAULT_CONSUMABLE_BUCKET_ID,
	item_upgrade_category_id: String = DEFAULT_ITEM_UPGRADE_CATEGORY_ID,
) -> Dictionary:
	var boon_ids: Dictionary = {}
	var consumable_ids: Dictionary = {}
	var item_upgrade_ids: Dictionary = {}
	if boon_buckets_root != null and boon_buckets_root.is_valid() and boon_buckets_root.get_type() == GnosisValueType.OBJECT:
		var bag := boon_buckets_root.get_node(boon_bucket_id)
		if bag.is_valid() and bag.get_type() == GnosisValueType.OBJECT:
			_append_catalog_ids_from_object_list(bag.get_node("list"), boon_ids, "boonId", "id")
	if consumable_buckets_root != null and consumable_buckets_root.is_valid() and consumable_buckets_root.get_type() == GnosisValueType.OBJECT:
		var cbag := consumable_buckets_root.get_node(consumable_bucket_id)
		if cbag.is_valid() and cbag.get_type() == GnosisValueType.OBJECT:
			_append_catalog_ids_from_object_list(cbag.get_node("list"), consumable_ids, "id", "")
	if upgrades_root != null and upgrades_root.is_valid() and upgrades_root.get_type() == GnosisValueType.OBJECT:
		var ubag := upgrades_root.get_node(item_upgrade_category_id)
		if ubag.is_valid() and ubag.get_type() == GnosisValueType.OBJECT:
			_append_catalog_ids_from_object_list(ubag.get_node("list"), item_upgrade_ids, "upgradeId", "id")
	return {
		"boon": boon_ids,
		"consumable": consumable_ids,
		"itemUpgrade": item_upgrade_ids,
	}


static func build_offer_pool_from_catalog(full_catalog: Array, owned_catalog_ids: Dictionary, allow_duplicate_catalog_offers: bool) -> Array[String]:
	var out: Array[String] = []
	if full_catalog.is_empty():
		return out
	if allow_duplicate_catalog_offers:
		for id in full_catalog:
			var sid := str(id).strip_edges()
			if not sid.is_empty():
				out.append(sid)
		return out
	for id in full_catalog:
		var sid := str(id).strip_edges()
		if sid.is_empty() or owned_catalog_ids.has(sid.to_lower()):
			continue
		out.append(sid)
	return out


static func player_owns_consumable_catalog_id(consumable_buckets_root: GnosisNode, consumable_bucket_id: String, consumable_catalog_id: String) -> bool:
	var want := consumable_catalog_id.strip_edges()
	if want.is_empty() or consumable_buckets_root == null or not consumable_buckets_root.is_valid():
		return false
	var bag := consumable_buckets_root.get_node(consumable_bucket_id)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return false
	var owned: Dictionary = {}
	_append_catalog_ids_from_object_list(bag.get_node("list"), owned, "id", "")
	return owned.has(want.to_lower())


static func _append_catalog_ids_from_object_list(list: GnosisNode, into: Dictionary, primary_key: String, secondary_key: String) -> void:
	if into == null or list == null or not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		if entry == null or not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var id := _read_string(entry, primary_key)
		if id.is_empty() and not secondary_key.is_empty():
			id = _read_string(entry, secondary_key)
		if not id.is_empty():
			into[id.to_lower()] = true


static func _read_string(node: GnosisNode, key: String) -> String:
	if node == null or not node.is_valid():
		return ""
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return ""
	return str(child.value).strip_edges()
