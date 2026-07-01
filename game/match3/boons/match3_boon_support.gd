class_name Match3BoonSupport
extends RefCounted

## Shared boon inventory / catalog helpers for Match3 boon runtime.

const CatalogPolicyScript = preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")

const BOON_GAMEPLAY_TAG_LEGENDARY := "legendary"
const BOON_CATALOG_SOURCE_CONFIG_ID := "boons"

const COLD_PALETTE_ITEM_IDS: Array[String] = ["green", "blue", "purple"]
const WARM_PALETTE_ITEM_IDS: Array[String] = ["red", "orange", "pink"]


static func read_statistic_int(service: GnosisService, path: String, fallback: int = 0) -> int:
	if service == null:
		return fallback
	if service.has_method("get_statistic_int"):
		return int(service.call("get_statistic_int", path, fallback))
	var stats: GnosisNode = service.get_node("statistics", false)
	if not stats.is_valid():
		return fallback
	var node: GnosisNode = stats.get_node(path.strip_edges())
	if not node.is_valid() or node.value == null:
		return fallback
	return int(node.value)


static func publish_ephemeral_state(service: GnosisService) -> void:
	if service != null and service.has_method("_publish_ephemeral_state"):
		service.call("_publish_ephemeral_state")


static func read_boon_catalog_id_from_inventory_entry(entry: GnosisNode) -> String:
	if entry == null or not entry.is_valid():
		return ""
	if entry.get_type() == GnosisValueType.STRING:
		return str(entry.value).strip_edges()
	var boon_id := _node_str(entry, "boonId")
	if not boon_id.is_empty():
		return boon_id
	return _node_str(entry, "id")


static func read_boon_effect_application_is_per_instance(entry: GnosisNode) -> bool:
	if entry == null or not entry.is_valid():
		return false
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	var mode := _node_str(props, "effectApplication", "catalogOnce")
	return mode.strip_edges().to_lower() == "perinstance"


static func boon_configuration_gameplay_tags_include(boon_catalog_entry: GnosisNode, tag: String) -> bool:
	var want := tag.strip_edges().to_lower()
	if want.is_empty() or boon_catalog_entry == null or not boon_catalog_entry.is_valid():
		return false
	var props := boon_catalog_entry.get_node("properties")
	if not props.is_valid():
		return false
	var tags := props.get_node("gameplayTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	for i in tags.get_count():
		var t := str(tags.get_node(i).value).strip_edges().to_lower()
		if t == want:
			return true
	return false


static func build_boon_catalog_ids_from_configuration(service: GnosisService, required_gameplay_tag: String = "") -> Array[String]:
	var out: Array[String] = []
	var config := service.get_node("configuration", true)
	if not config.is_valid():
		return out
	var boons_root := config.get_node("boons")
	if not boons_root.is_valid() or boons_root.get_type() != GnosisValueType.OBJECT:
		return out
	var filter_by_tag := not required_gameplay_tag.strip_edges().is_empty()
	var legendary_only := filter_by_tag and required_gameplay_tag.strip_edges().to_lower() == BOON_GAMEPLAY_TAG_LEGENDARY
	for key in boons_root.get_keys():
		var id := str(key).strip_edges()
		if id.is_empty():
			continue
		var cfg := boons_root.get_node(id)
		if not cfg.is_valid() or cfg.get_type() != GnosisValueType.OBJECT:
			continue
		if legendary_only:
			if not boon_configuration_gameplay_tags_include(cfg, BOON_GAMEPLAY_TAG_LEGENDARY):
				continue
		elif filter_by_tag:
			if not boon_configuration_gameplay_tags_include(cfg, required_gameplay_tag):
				continue
		elif boon_configuration_gameplay_tags_include(cfg, BOON_GAMEPLAY_TAG_LEGENDARY):
			continue
		out.append(id)
	out.sort()
	return out


static func build_boon_catalog_ids_any_tier_from_configuration(service: GnosisService) -> Array[String]:
	var out: Array[String] = []
	var config := service.get_node("configuration", true)
	if not config.is_valid():
		return out
	var boons_root := config.get_node("boons")
	if not boons_root.is_valid() or boons_root.get_type() != GnosisValueType.OBJECT:
		return out
	for key in boons_root.get_keys():
		var id := str(key).strip_edges()
		if id.is_empty():
			continue
		var cfg := boons_root.get_node(id)
		if cfg.is_valid() and cfg.get_type() == GnosisValueType.OBJECT:
			out.append(id)
	out.sort()
	return out


static func build_equipped_boon_catalog_ids_from_bag(service: GnosisService, bucket_id: String) -> Array[String]:
	var out: Array[String] = []
	var boons := service.get_node("boons", false)
	if not boons.is_valid():
		return out
	var bag := boons.get_node(bucket_id.strip_edges() if not bucket_id.is_empty() else CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid():
		bag = boons.get_node(CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid():
		return out
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return out
	for i in range(list.get_count()):
		var catalog_id := read_boon_catalog_id_from_inventory_entry(list.get_node(i))
		if not catalog_id.is_empty():
			out.append(catalog_id)
	return out


static func read_boon_bag_empty_slot_count_by_capacity(service: GnosisService, bucket_id: String) -> int:
	var boons := service.get_node("boons", false)
	if not boons.is_valid():
		return 0
	var bag := boons.get_node(bucket_id.strip_edges() if not bucket_id.is_empty() else CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid():
		bag = boons.get_node(CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid():
		return 0
	var empty_node := bag.get_node("emptySlotsCount")
	if empty_node.is_valid() and empty_node.value != null:
		return maxi(0, int(empty_node.value))
	var max_size := maxi(0, _node_int(bag, "maxSize", 0))
	var list := bag.get_node("list")
	var filled := list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	return maxi(0, max_size - filled)


static func read_boon_bag_max_slot_capacity(boons_bag: GnosisNode) -> int:
	if boons_bag == null or not boons_bag.is_valid():
		return 1
	return maxi(1, _node_int(boons_bag, "maxSize", 1))


static func is_boon_catalog_id_equipped(service: GnosisService, catalog_id: String) -> bool:
	var want := catalog_id.strip_edges().to_lower()
	if want.is_empty():
		return false
	for row in get_active_boon_inventory_slot_rows(service):
		if read_boon_catalog_id_from_inventory_entry(row).to_lower() == want:
			return true
	return false


static func index_of_active_boon_slot_by_catalog_id(service: GnosisService, catalog_id: String) -> int:
	var want := catalog_id.strip_edges().to_lower()
	if want.is_empty():
		return -1
	var rows := get_active_boon_inventory_slot_rows(service)
	for i in range(rows.size()):
		if read_boon_catalog_id_from_inventory_entry(rows[i]).to_lower() == want:
			return i
	return -1


static func get_active_boon_inventory_slot_rows(service: GnosisService) -> Array:
	var rows: Array = []
	var boons := service.get_node("boons", false)
	if not boons.is_valid() or boons.get_type() != GnosisValueType.OBJECT:
		return rows
	var bag := boons.get_node(CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return rows
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return rows
	for i in range(list.get_count()):
		var row := list.get_node(i)
		if row.is_valid() and row.get_type() == GnosisValueType.OBJECT:
			rows.append(row)
	return rows


static func resolve_boon_catalog_shop_buy_price(service: GnosisService, boon_id: String) -> int:
	if service.context == null or service.context.store == null or boon_id.strip_edges().is_empty():
		return 0
	var params := service.context.store.create_object()
	params.set_key("sourceConfigId", BOON_CATALOG_SOURCE_CONFIG_ID)
	params.set_key("itemId", boon_id.strip_edges())
	var result = service.call_service("Match3Shop", "ResolveCatalogShopBuyPrice", params)
	if result is GnosisFunctionResult:
		if not result.is_ok or result.payload == null or not result.payload.is_valid():
			return 0
		return maxi(0, _node_int(result.payload, "buyPrice", 0))
	if result is GnosisNode and result.is_valid():
		return maxi(0, _node_int(result, "buyPrice", 0))
	return 0


static func apply_shop_buy_price_to_activate_boon_params(service: GnosisService, activate_params: GnosisNode, boon_id: String) -> void:
	if activate_params == null or not activate_params.is_valid():
		return
	var buy_price := resolve_boon_catalog_shop_buy_price(service, boon_id)
	if buy_price > 0:
		activate_params.set_key("buyPrice", float(buy_price))


static func build_active_boons_context_node(store: GnosisStore, slot_rows: Array) -> GnosisNode:
	var boons_node := store.create_object()
	var props_node := store.create_object()
	var metadata_node := store.create_object()
	var gameplay_tags_node := store.create_object()
	var meta_tags_node := store.create_object()
	var gameplay_counts: Dictionary = {}
	var metadata_counts: Dictionary = {}
	for slot_entry in slot_rows:
		if slot_entry == null or not slot_entry.is_valid():
			continue
		var bid := read_boon_catalog_id_from_inventory_entry(slot_entry)
		if bid.is_empty():
			continue
		_accumulate_tag_list_counts(metadata_counts, slot_entry.get_node("metadata").get_node("tags"))
		_accumulate_tag_list_counts(gameplay_counts, slot_entry.get_node("properties").get_node("gameplayTags"))
	for key in gameplay_counts.keys():
		gameplay_tags_node.set_key(str(key), int(gameplay_counts[key]))
	for key in metadata_counts.keys():
		meta_tags_node.set_key(str(key), int(metadata_counts[key]))
	props_node.set_key("gameplayTags", gameplay_tags_node)
	metadata_node.set_key("tags", meta_tags_node)
	boons_node.set_key("properties", props_node)
	boons_node.set_key("metadata", metadata_node)
	return boons_node


static func scalable_from_int(value: int) -> GnosisScalableValue:
	return GnosisScalableValue.from_int(value)


static func read_scalable_node(node: GnosisNode, default_value: GnosisScalableValue = null) -> GnosisScalableValue:
	if default_value == null:
		default_value = GnosisScalableValue.zero()
	if node == null or not node.is_valid() or node.get_type() != GnosisValueType.OBJECT:
		return default_value
	var coef_node := node.get_node("coefficient")
	var suffix_node := node.get_node("suffixIndex")
	if coef_node.is_valid() and suffix_node.is_valid():
		return GnosisScalableValue.from_value_and_suffix(int(coef_node.value), int(suffix_node.value))
	if node.value is int or node.value is float:
		return GnosisScalableValue.from_int(int(node.value))
	return default_value


static func write_scalable_node(store: GnosisStore, value: GnosisScalableValue) -> GnosisNode:
	var node := store.create_object()
	node.set_key("coefficient", value.coefficient)
	node.set_key("suffixIndex", value.suffix_index)
	return node


static func scalable_to_move_int(value: GnosisScalableValue) -> int:
	return maxi(0, int(round(value.to_float())))


static func multiply_scalable_by_numeric_factor(cur: GnosisScalableValue, factor: float) -> GnosisScalableValue:
	var f := maxf(0.0, factor)
	if absf(f - roundf(f)) < 1e-6:
		return cur.mul(GnosisScalableValue.from_int(int(roundf(f))))
	return cur.mul(GnosisScalableValue.from_float(f))


static func is_cold_palette_item_id(item_id: String) -> bool:
	var id := item_id.strip_edges().to_lower()
	return id in COLD_PALETTE_ITEM_IDS


static func is_warm_palette_item_id(item_id: String) -> bool:
	var id := item_id.strip_edges().to_lower()
	return id in WARM_PALETTE_ITEM_IDS


static func _accumulate_tag_list_counts(counts: Dictionary, tag_list: GnosisNode) -> void:
	if counts == null or tag_list == null or not tag_list.is_valid() or tag_list.get_type() != GnosisValueType.LIST:
		return
	for i in range(tag_list.get_count()):
		var raw := str(tag_list.get_node(i).value).strip_edges().to_lower()
		if raw.is_empty():
			continue
		counts[raw] = int(counts.get(raw, 0)) + 1


static func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value).strip_edges()


static func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)
