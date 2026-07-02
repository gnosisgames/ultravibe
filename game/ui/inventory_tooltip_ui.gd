class_name InventoryTooltipUi
extends RefCounted

## Rich in-play inventory tooltips: localized descriptions with score-preview args and tag chips.

const CatalogLocalizationUiScript = preload("res://game/ui/catalog_localization_ui.gd")


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
	)


static func enrich_entry_details(
	service: GnosisService,
	entry: GnosisNode,
	category: String,
	base: Dictionary,
) -> Dictionary:
	if service == null or service.context == null or service.context.engine == null:
		return base
	var engine := service.context.engine
	var item_id := _resolve_item_id(entry)
	var name_fallback := item_id.capitalize() if not item_id.is_empty() else ""
	var meta := entry.get_node("metadata")
	base["name"] = build_display_name(engine, entry, category, name_fallback)
	base["description"] = build_description(engine, entry, category, base.get("description", ""))
	base["tags"] = build_tags(engine, meta, entry)
	base["entry"] = entry
	return base


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
