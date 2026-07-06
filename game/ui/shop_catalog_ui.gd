class_name ShopCatalogUi
extends RefCounted

## Resolves shop offer presentation (title, description, icon) from catalog entries.

const ICON_ROOT := "res://assets/icons/"
const CatalogLocalizationUiScript = preload("res://game/ui/catalog_localization_ui.gd")
const CatalogSpritePathsScript = preload("res://game/ui/catalog_sprite_paths.gd")
const ConsumableCatalogUiScript = preload("res://game/ui/consumable_catalog_ui.gd")

const FOLDER_BY_CONFIG := {
	"boons": "boons",
	"consumables": "consumables",
	"runUpgrades": "upgrades",
}

const FlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")


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
		"title": CatalogLocalizationUiScript.resolve_text(
			engine, _meta_str(meta, "nameKey"), trimmed_id.capitalize(), config_key, trimmed_id, entry
		),
		"description": CatalogLocalizationUiScript.resolve_text(
			engine, _meta_str(meta, "descriptionKey"), "", config_key, trimmed_id, entry
		),
		"icon_path": _resolve_icon_path(folder, trimmed_id, sprite_id),
		"tags": ConsumableCatalogUiScript.parse_tags(engine, meta),
	}


## Catalog presentation plus rolled boon flavors from a shop offer node (if any).
static func build_shop_offer_presentation(
	engine: GnosisEngine,
	source_config_id: String,
	item_id: String,
	offer: GnosisNode = GnosisNode.new(null),
) -> Dictionary:
	var presentation := build_presentation(engine, source_config_id, item_id)
	if offer == null or not offer.is_valid():
		return presentation
	if source_config_id.strip_edges().to_lower() != "boons":
		return presentation
	var positive_id := _read_flavor_id(offer, FlavorsScript.POSITIVE_FLAVOR_ID_PROPERTY)
	var negative_id := _read_flavor_id(offer, FlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY)
	if not positive_id.is_empty():
		presentation["positive_flavor_id"] = positive_id
	if not negative_id.is_empty():
		presentation["negative_flavor_id"] = negative_id
	_append_flavor_tags(engine, presentation, positive_id, negative_id)
	return presentation


static func _read_flavor_id(node: GnosisNode, key: String) -> String:
	var value := _meta_str(node, key).strip_edges()
	if not value.is_empty():
		return value
	var props := node.get_node("properties")
	return _meta_str(props, key).strip_edges()


static func _append_flavor_tags(
	engine: GnosisEngine,
	presentation: Dictionary,
	positive_id: String,
	negative_id: String,
) -> void:
	var tags: Array = presentation.get("tags", [])
	for flavor_id in [positive_id, negative_id]:
		if flavor_id.is_empty():
			continue
		var loc_key := "flavor%sName" % flavor_id
		var label := _localized(engine, loc_key, flavor_id)
		if label.strip_edges().is_empty():
			continue
		tags.append({"type": "flavor", "label": label})
	presentation["tags"] = tags


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
	return CatalogSpritePathsScript.resolve_item_upgrade_icon(sprite_id, item_id)


static func _localized(engine: GnosisEngine, key: String, fallback: String) -> String:
	return CatalogLocalizationUiScript.resolve_text(engine, key, fallback)


static func _meta_str(node: GnosisNode, key: String) -> String:
	if not node.is_valid():
		return ""
	var child := node.get_node(key)
	return str(child.value) if child.is_valid() and child.value != null else ""
