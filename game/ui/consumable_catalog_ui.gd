class_name ConsumableCatalogUi
extends RefCounted

## Resolves consumable catalog presentation for level-select round-action previews.
## Mirrors Unity MainHud.TryBuildConsumableCatalogLevelPreviewPresentation.

const CONSUMABLES_CONFIG_KEY := "consumables"
const ICON_DIRS := [
	"res://assets/icons/consumables/",
	"res://assets/unity/Sprites/Consumables/",
]

static func get_catalog_entry(engine: GnosisEngine, consumable_id: String) -> GnosisNode:
	if engine == null or engine.state == null:
		return GnosisNode.new(null)
	var trimmed := consumable_id.strip_edges()
	if trimmed.is_empty():
		return GnosisNode.new(null)
	var config := engine.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	var catalog := config.get_node(CONSUMABLES_CONFIG_KEY)
	if not catalog.is_valid():
		return GnosisNode.new(null)
	return catalog.get_node(trimmed)


static func build_level_preview(engine: GnosisEngine, consumable_id: String) -> Dictionary:
	var trimmed := consumable_id.strip_edges()
	if trimmed.is_empty():
		return {}
	var entry := get_catalog_entry(engine, trimmed)
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return {}
	var meta := entry.get_node("metadata")
	if not meta.is_valid():
		meta = entry
	var sprite_id := _meta_str(meta, "spriteId")
	return {
		"consumable_id": trimmed,
		"title": _localized(engine, _meta_str(meta, "nameKey"), trimmed),
		"description": _localized(engine, _meta_str(meta, "descriptionKey"), ""),
		"icon_path": resolve_icon_path(trimmed, sprite_id),
		"tags": parse_tags(engine, meta),
	}


static func resolve_icon_path(consumable_id: String, sprite_id: String = "") -> String:
	var candidates: Array[String] = []
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	if sprite_id.begins_with("consumable") and sprite_id.ends_with("Sprite"):
		var base := sprite_id.trim_prefix("consumable").trim_suffix("Sprite")
		candidates.append(base)
		candidates.append(base.capitalize())
	candidates.append(consumable_id)
	candidates.append(consumable_id.capitalize())
	for candidate in candidates:
		for dir in ICON_DIRS:
			var path := "%s%s.png" % [dir, candidate]
			if ResourceLoader.exists(path):
				return path
	return ""


static func parse_tags(engine: GnosisEngine, meta: GnosisNode) -> Array:
	var result: Array = []
	if not meta.is_valid():
		return result
	var tags_node := meta.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return result
	for i in range(tags_node.get_count()):
		var item := tags_node.get_node(i)
		if not item.is_valid() or item.get_type() != GnosisValueType.OBJECT:
			continue
		var type_id := _meta_str(item, "tagType")
		if type_id.is_empty():
			type_id = _meta_str(item, "type")
		var loc_key := _meta_str(item, "tagLocKey")
		if loc_key.is_empty():
			loc_key = _meta_str(item, "locKey")
		if loc_key.is_empty():
			continue
		var label := _localized(engine, loc_key, type_id.capitalize())
		if label.strip_edges().is_empty():
			continue
		result.append({"type": type_id, "label": label})
	return result


static func format_level_money_reward(amount: int) -> String:
	if amount <= 0:
		return ""
	return "$%d" % amount


static func _localized(engine: GnosisEngine, key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	if engine == null:
		return fallback
	var localization := engine.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return localization.get_string_value(key, fallback)


static func _meta_str(node: GnosisNode, key: String) -> String:
	if not node.is_valid():
		return ""
	var child := node.get_node(key)
	return str(child.value) if child.is_valid() and child.value != null else ""
