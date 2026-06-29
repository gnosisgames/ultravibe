extends RefCounted

## Preloaded as FallingBlockTraitOverlay by falling_block_adapter.gd (no global
## class_name so headless --script runs don't depend on a project class rescan).

## Resolves the displayable traits of the current falling piece for the
## center-bottom board overlay. Mirrors Unity MainHud.UltravibeTraits +
## BlockTraitCatalog + TraitTagFilter: the active piece's variant tags are
## filtered to catalog traits (color lanes / polarity tags are dropped), ordered
## by the traits catalog, and resolved to a localized name, tint colour and icon.

const TRAIT_SPRITE_DIR := "res://assets/ui/traits/"
const IGNORED_TAGS := {"neutral": true, "positive": true, "negative": true, "disabled": true}

var _engine: RefCounted = null
var _loaded := false
var _order: Array[String] = []
var _meta := {}

func _init(engine_ref) -> void:
	_engine = engine_ref

## Returns an ordered array of trait entries for the active piece. Each entry is
## { "name": String, "color": Color, "texture": Texture2D } (texture may be null).
func resolve_entries(grid) -> Array:
	_ensure_loaded()
	var entries: Array = []
	if grid == null or _meta.is_empty():
		return entries
	var variant_id := _active_piece_variant_id(grid)
	if variant_id.is_empty():
		return entries
	var selected := {}
	for tag in _variant_tags(variant_id):
		var t := str(tag).strip_edges().to_lower()
		if _is_displayable(t):
			selected[t] = true
	if selected.is_empty():
		return entries
	for id in _order:
		if not selected.has(id):
			continue
		var meta: Dictionary = _meta[id]
		entries.append({
			"name": _localized(meta["name_key"], _pretty(id)),
			"color": meta["color"],
			"texture": meta["texture"],
		})
	return entries

func _ensure_loaded() -> void:
	if _loaded:
		return
	var traits := _config_node("traits")
	if not traits.is_valid() or traits.get_type() != GnosisValueType.OBJECT:
		return
	_loaded = true
	for tid in traits.get_keys():
		var id := str(tid).strip_edges().to_lower()
		if id.is_empty():
			continue
		var entry := traits.get_node(tid)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var meta := entry.get_node("metadata")
		var name_key := _node_str(meta, "nameKey")
		if name_key.is_empty():
			name_key = id + "Name"
		var tint := _node_str(meta, "spriteTintColor")
		var color := Color.WHITE
		if not tint.is_empty():
			color = Color.html(tint if tint.begins_with("#") else "#" + tint)
		_meta[id] = {
			"name_key": name_key,
			"color": color,
			"texture": _load_trait_texture(_node_str(meta, "spritePath")),
		}
		_order.append(id)

func _is_displayable(tag: String) -> bool:
	if tag.is_empty() or tag.begins_with("color_") or IGNORED_TAGS.has(tag):
		return false
	return _meta.has(tag)

func _active_piece_variant_id(grid) -> String:
	for cell in grid.cells:
		if cell == null or cell.block_id.is_empty() or cell.is_locked:
			continue
		var vid: String = cell.variant_id.strip_edges().to_lower()
		return "blue" if vid.is_empty() else vid
	return ""

func _variant_tags(variant_id: String) -> Array:
	var out: Array = []
	var variants := _config_node("variants")
	if not variants.is_valid() or variants.get_type() != GnosisValueType.OBJECT:
		return out
	var variant := variants.get_node(variant_id.strip_edges().to_lower())
	if not variant.is_valid() or variant.get_type() != GnosisValueType.OBJECT:
		return out
	var tags_node := variant.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return out
	for i in range(tags_node.get_count()):
		var t := tags_node.get_node(i)
		if t.is_valid() and t.get_type() == GnosisValueType.STRING:
			out.append(str(t.value))
	return out

func _load_trait_texture(sprite_path: String) -> Texture2D:
	if sprite_path.strip_edges().is_empty():
		return null
	var path := "%s%s.png" % [TRAIT_SPRITE_DIR, sprite_path.get_file()]
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _config_node(key: String) -> GnosisNode:
	if _engine == null:
		return GnosisNode.new(null)
	var config: GnosisNode = _engine.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(key)

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty() or _engine == null:
		return fallback
	var loc := _engine.get_service("Localization") as GnosisLocalizationService
	if loc == null:
		return fallback
	return loc.get_string_value(key, fallback)

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value).strip_edges() if n.is_valid() and n.value != null else ""

func _pretty(tag_id: String) -> String:
	var parts := tag_id.split("_", false)
	for i in range(parts.size()):
		parts[i] = parts[i].capitalize()
	return " ".join(parts)
