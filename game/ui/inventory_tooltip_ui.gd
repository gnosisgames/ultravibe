class_name InventoryTooltipUi
extends RefCounted

## Rich in-play inventory tooltips: localized descriptions with score-preview args and tag chips.

const CatalogLocalizationUiScript = preload("res://game/ui/catalog_localization_ui.gd")
const ShopCatalogUiScript = preload("res://game/ui/shop_catalog_ui.gd")
const FlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

const SELL_ACTION_TYPE := "failure"
const SELL_INPUT_ACTION := "UISell"
const SELL_LOC_KEY := "core__verb__sell"
const BOON_CATEGORY := "boons"
const CONSUMABLE_CATEGORY := "consumables"


static func build_tags(engine: GnosisEngine, meta: GnosisNode, entry: GnosisNode = GnosisNode.new(null)) -> Array:
	var tags := _tags_from_metadata(engine, meta)
	_append_flavor_tags(engine, tags, entry)
	return tags


static func build_display_name(
	engine: GnosisEngine,
	entry: GnosisNode,
	category: String,
	fallback: String,
) -> String:
	var item_id := _resolve_item_id(entry)
	var meta := entry.get_node("metadata")
	var name_key := _node_str(meta, "nameKey")
	if name_key.is_empty() and engine != null:
		var catalog := _read_catalog_entry(engine, category, item_id)
		meta = catalog.get_node("metadata") if catalog.is_valid() else meta
		name_key = _node_str(meta, "nameKey")
	return CatalogLocalizationUiScript.resolve_text(engine, name_key, fallback, category, item_id)


static func build_description(
	engine: GnosisEngine,
	entry: GnosisNode,
	category: String,
	fallback: String = "",
	reroll_random_preview: bool = false,
) -> String:
	var item_id := _resolve_item_id(entry)
	var meta := entry.get_node("metadata")
	var desc_key := _node_str(meta, "descriptionKey")
	var catalog := GnosisNode.new(null)
	if engine != null:
		catalog = _read_catalog_entry(engine, category, item_id)
		if desc_key.is_empty() and catalog.is_valid():
			desc_key = _node_str(catalog.get_node("metadata"), "descriptionKey")
	var catalog_for_args := catalog if catalog.is_valid() else entry
	return CatalogLocalizationUiScript.resolve_text(
		engine,
		desc_key,
		fallback,
		category,
		item_id,
		catalog_for_args,
		reroll_random_preview,
	)


static func enrich_entry_details(
	service: GnosisService,
	entry: GnosisNode,
	category: String,
	base: Dictionary,
	reroll_random_preview: bool = false,
) -> Dictionary:
	if service == null or service.context == null or service.context.engine == null:
		return base
	var engine := service.context.engine
	var item_id := _resolve_item_id(entry)
	var name_fallback := item_id.capitalize() if not item_id.is_empty() else ""
	var meta := entry.get_node("metadata")
	base["name"] = build_display_name(engine, entry, category, name_fallback)
	base["description"] = build_description(engine, entry, category, base.get("description", ""), reroll_random_preview)
	base["tags"] = build_tags(engine, meta, entry)
	base["entry"] = entry
	return base


## Shop-parity title/description/tags for an equipped inventory row (includes flavor chips).
static func build_hud_presentation(
	engine: GnosisEngine,
	category: String,
	entry: GnosisNode,
) -> Dictionary:
	var item_id := _resolve_item_id(entry)
	var presentation := ShopCatalogUiScript.build_presentation(engine, category, item_id)
	if presentation.is_empty():
		presentation = {
			"title": item_id.capitalize(),
			"description": "",
			"tags": [],
		}
	presentation["tags"] = build_tags(engine, entry.get_node("metadata"), entry)
	return presentation


## Tooltip action rows below the body (Unity MainHud.BuildInventoryRowTooltipParameters).
static func build_inventory_row_actions(
	engine: GnosisEngine,
	entry: GnosisNode,
	category: String,
) -> Array:
	var actions: Array = []
	if engine == null or not entry.is_valid() or category.is_empty():
		return actions
	var cat := category.to_lower()
	if cat == BOON_CATEGORY and can_sell_boon_entry(engine, entry):
		actions.append(_make_sell_action(engine, entry))
	elif cat == CONSUMABLE_CATEGORY and can_sell_consumable_entry(engine, entry):
		actions.append(_make_sell_action(engine, entry))
	return actions


static func _make_sell_action(engine: GnosisEngine, entry: GnosisNode) -> Dictionary:
	var sell_price := read_inventory_sell_price(entry)
	var label := _localized(engine, SELL_LOC_KEY, "Sell $%d" % sell_price)
	var localization := engine.get_service("Localization") as GnosisLocalizationService
	if localization != null:
		label = localization.get_string_resolved(SELL_LOC_KEY, label, {}, [str(sell_price)])
	return {
		"type": SELL_ACTION_TYPE,
		"label": label,
		"input_action": SELL_INPUT_ACTION,
		"input_mouse_button": MOUSE_BUTTON_RIGHT,
	}


static func can_sell_boon_entry(engine: GnosisEngine, entry: GnosisNode) -> bool:
	if engine == null or not entry.is_valid():
		return false
	var config := engine.state.root.get_node("Persistent").get_node("configuration")
	return not FlavorsScript.inventory_entry_blocks_sell(entry, config)


static func can_sell_consumable_entry(engine: GnosisEngine, entry: GnosisNode) -> bool:
	if engine == null or not entry.is_valid():
		return false
	return not _resolve_item_id(entry).is_empty()


static func can_sell_inventory_entry(engine: GnosisEngine, entry: GnosisNode, category: String) -> bool:
	match category.to_lower():
		BOON_CATEGORY:
			return can_sell_boon_entry(engine, entry)
		CONSUMABLE_CATEGORY:
			return can_sell_consumable_entry(engine, entry)
	return false


static func read_inventory_sell_price(entry: GnosisNode) -> int:
	if not entry.is_valid():
		return 0
	var props := entry.get_node("properties")
	return maxi(0, _node_int(props, "sellPrice", 0))


static func try_sell_boon_entry(service: GnosisService, entry: GnosisNode) -> bool:
	if service == null or service.context == null or service.context.engine == null:
		return false
	if not entry.is_valid():
		return false
	var engine := service.context.engine
	if not can_sell_boon_entry(engine, entry):
		return false
	var instance_id := _node_str(entry, "instanceId")
	var boon_id := SupportScript.read_boon_catalog_id_from_inventory_entry(entry)
	if instance_id.is_empty() and boon_id.is_empty():
		return false
	var params := service.context.store.create_object()
	if not instance_id.is_empty():
		params.set_key("instanceId", instance_id)
	if not boon_id.is_empty():
		params.set_key("boonId", boon_id)
	var buy_price := SupportScript.resolve_boon_catalog_shop_buy_price(service, boon_id)
	if buy_price > 0:
		params.set_key("buyPrice", buy_price)
	var result = service.call_service("Boon", "DeactivateBoon", params)
	if result is GnosisFunctionResult and not (result as GnosisFunctionResult).is_ok:
		return false
	var sale := service.context.store.create_object()
	sale.set_key("sourceConfigId", BOON_CATEGORY)
	sale.set_key("itemId", boon_id)
	service.call_service("Match3Shop", "RecordInventorySale", sale)
	SupportScript.publish_ephemeral_state(service)
	if service.has_method("sync_equipped_boon_match3_round_effects"):
		service.call("sync_equipped_boon_match3_round_effects")
	return true


static func try_sell_consumable_entry(service: GnosisService, entry: GnosisNode) -> bool:
	if service == null or service.context == null or service.context.engine == null:
		return false
	if not entry.is_valid() or not can_sell_consumable_entry(service.context.engine, entry):
		return false
	var consumable_id := _resolve_item_id(entry)
	if consumable_id.is_empty():
		return false
	var params := service.context.store.create_object()
	params.set_key("consumableId", consumable_id)
	var result = service.call_service("Consumable", "RemoveConsumable", params)
	if result is GnosisFunctionResult and not (result as GnosisFunctionResult).is_ok:
		return false
	var sale := service.context.store.create_object()
	sale.set_key("sourceConfigId", CONSUMABLE_CATEGORY)
	sale.set_key("itemId", consumable_id)
	service.call_service("Match3Shop", "RecordInventorySale", sale)
	SupportScript.publish_ephemeral_state(service)
	return true


static func try_sell_inventory_entry(service: GnosisService, entry: GnosisNode, category: String) -> bool:
	match category.to_lower():
		BOON_CATEGORY:
			return try_sell_boon_entry(service, entry)
		CONSUMABLE_CATEGORY:
			return try_sell_consumable_entry(service, entry)
	return false


static func _tags_from_metadata(engine: GnosisEngine, meta: GnosisNode) -> Array:
	var result: Array = []
	if not meta.is_valid() or meta.get_type() != GnosisValueType.OBJECT:
		return result
	var tags_node := meta.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return result
	for i in range(tags_node.get_count()):
		var item := tags_node.get_node(i)
		if not item.is_valid() or item.get_type() != GnosisValueType.OBJECT:
			continue
		var type_id := _node_str(item, "tagType")
		if type_id.is_empty():
			type_id = _node_str(item, "type")
		var loc_key := _node_str(item, "tagLocKey")
		if loc_key.is_empty():
			loc_key = _node_str(item, "locKey")
		if loc_key.is_empty():
			continue
		var label := _localized(engine, loc_key, type_id.capitalize())
		if label.strip_edges().is_empty():
			continue
		result.append({"type": type_id, "label": label})
	return result


static func _append_flavor_tags(engine: GnosisEngine, tags: Array, entry: GnosisNode) -> void:
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return
	var props := entry.get_node("properties")
	if not props.is_valid():
		return
	for key in ["positiveFlavorId", "negativeFlavorId"]:
		var flavor_id := _node_str(props, key).strip_edges()
		if flavor_id.is_empty():
			continue
		var loc_key := "flavor%sName" % flavor_id
		var label := _localized(engine, loc_key, flavor_id)
		if label.strip_edges().is_empty():
			continue
		tags.append({"type": "flavor", "label": label})


static func _read_catalog_entry(engine: GnosisEngine, category: String, item_id: String) -> GnosisNode:
	if engine == null or engine.state == null or category.is_empty() or item_id.is_empty():
		return GnosisNode.new(null)
	var config := engine.state.root.get_node("Persistent").get_node("configuration").get_node(category)
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(item_id)


static func _resolve_item_id(entry: GnosisNode) -> String:
	for key in ["id", "consumableId", "boonId", "abilityId"]:
		var v := _node_str(entry, key)
		if not v.is_empty():
			return v
	return ""


static func _localized(engine: GnosisEngine, key: String, fallback: String) -> String:
	if key.strip_edges().is_empty() or engine == null:
		return fallback
	var localization := engine.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return localization.get_string_value(key, fallback)


static func _node_str(node: GnosisNode, key: String) -> String:
	if not node.is_valid():
		return ""
	var child := node.get_node(key)
	return str(child.value) if child.is_valid() and child.value != null else ""


static func _node_int(node: GnosisNode, key: String, fallback: int) -> int:
	if not node.is_valid():
		return fallback
	var child := node.get_node(key)
	if child.is_valid() and child.value != null and typeof(child.value) in [TYPE_INT, TYPE_FLOAT]:
		return int(child.value)
	return fallback
