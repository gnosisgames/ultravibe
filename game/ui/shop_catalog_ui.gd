class_name ShopCatalogUi
extends RefCounted

## Resolves shop offer presentation (title, description, icon) from catalog entries.

const ICON_ROOT := "res://assets/icons/"
const ConsumableCatalogUiScript = preload("res://game/ui/consumable_catalog_ui.gd")

const FOLDER_BY_CONFIG := {
	"boons": "boons",
	"consumables": "consumables",
	"runUpgrades": "upgrades",
}


static func build_presentation(
	engine: GnosisEngine,
	source_config_id: String,
	item_id: String,
) -> Dictionary:
	var trimmed_id := item_id.strip_edges()
	var config_key := source_config_id.strip_edges()
	if trimmed_id.is_empty() or config_key.is_empty():
		return {}
	if config_key == "consumables":
		var preview := ConsumableCatalogUiScript.build_level_preview(engine, trimmed_id)
		if not preview.is_empty():
			return preview
	var entry := _catalog_entry(engine, config_key, trimmed_id)
	if not entry.is_valid():
		return {
			"title": trimmed_id.capitalize(),
			"description": "",
			"icon_path": "",
			"tags": [],
		}
	var meta := entry.get_node("metadata")
	if not meta.is_valid():
		meta = entry
	var sprite_id := _meta_str(meta, "spriteId")
	var folder: String = FOLDER_BY_CONFIG.get(config_key, config_key)
	return {
		"title": _localized(engine, _meta_str(meta, "nameKey"), trimmed_id.capitalize()),
		"description": _localized(engine, _meta_str(meta, "descriptionKey"), ""),
		"icon_path": _resolve_icon_path(folder, trimmed_id, sprite_id),
		"tags": ConsumableCatalogUiScript.parse_tags(engine, meta),
	}


static func _catalog_entry(engine: GnosisEngine, config_key: String, item_id: String) -> GnosisNode:
	if engine == null or engine.state == null:
		return GnosisNode.new(null)
	var config := engine.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	var catalog := config.get_node(config_key)
	if not catalog.is_valid():
		return GnosisNode.new(null)
	return catalog.get_node(item_id)


static func _resolve_icon_path(folder: String, item_id: String, sprite_id: String) -> String:
	var dir := "%s%s/" % [ICON_ROOT, folder]
	var candidates: Array[String] = []
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	if sprite_id.begins_with("consumable") and sprite_id.ends_with("Sprite"):
		var base := sprite_id.trim_prefix("consumable").trim_suffix("Sprite")
		candidates.append(base)
		candidates.append(base.capitalize())
	if sprite_id.begins_with("boon") and sprite_id.ends_with("Sprite"):
		var base := sprite_id.trim_prefix("boon").trim_suffix("Sprite")
		candidates.append(base)
	if sprite_id.begins_with("runUpgrade") and sprite_id.ends_with("Sprite"):
		var golden := sprite_id.trim_prefix("runUpgrade").trim_suffix("Sprite")
		candidates.append(golden)
		if golden == "GoldenFalling":
			candidates.append("discardUpgrade")
	candidates.append(item_id)
	candidates.append(item_id.capitalize())
	for candidate in candidates:
		var path := "%s%s.png" % [dir, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""


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
