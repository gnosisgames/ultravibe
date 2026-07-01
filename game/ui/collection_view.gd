class_name UltravibeCollectionView
extends GnosisUIElementView

## Compendium / gallery (viewId "collection"). Browses every catalog entry
## (boons, consumables, upgrades, bosses) as an icon grid, mirroring
## the Unity collection screen. Tiles show persistent discovery state and open a
## read-only detail panel.

const ICON_ROOT := "res://assets/icons/"
const BLOCK_ICON_DIR := "res://assets/blocks/"
const SPECIAL_ICON_IDS := {
	"abilities:gridShift": "gridSwap"
}

## Display font for boss starting-letter tokens — mirrors Unity's
## StartingCharacterText (PolygonParty, guid 744d4e... in the legacy font set).
const BOSS_LETTER_FONT := "res://assets/fonts/PolygonParty-3KXM.ttf"
const BOSS_TOKEN_DEFAULT_BG := Color(0.345098, 0.345098, 0.572549)
const BOSS_TOKEN_DEFAULT_FG := Color.WHITE

## The itemUpgrade level-up grants reuse the colored gem block sprites rather than
## a dedicated consumable icon (see Unity sprite registry in game.unity).
const CatalogSpritePathsScript = preload("res://game/ui/catalog_sprite_paths.gd")

const TOOLTIP_WIDTH := 300.0
const TOOLTIP_MAX_WIDTH := 360.0

# tab id -> [config catalog key, icon folder under assets/icons, is_variant]
const TABS := {
	"boons": {"catalog": "boons", "folder": "boons", "variant": false, "label": "ultravibe__collection__type__boon"},
	"consumables": {"catalog": "consumables", "folder": "consumables", "variant": false, "label": "ultravibe__collection__type__consumable"},
	"upgrades": {"catalog": "runUpgrades", "folder": "upgrades", "variant": false, "label": "ultravibe__collection__type__upgrade"},
	"itemUpgrades": {"catalog": "itemUpgrades", "folder": "upgrades", "variant": false, "label": "ultravibe__collection__type__itemUpgrade"},
	"bosses": {"catalog": "levels", "folder": "bosses", "variant": false, "letter": true, "label": "ultravibe__collection__type__boss"},
}

## Consumables whose id starts with this are the itemUpgrade grants; they are
## surfaced under the dedicated Item Upgrades tab instead of the Consumables grid.
const HIDDEN_CONSUMABLE_PREFIX := "ItemUpgradeGrant"

## Non-boss level profiles shown in gameplay but omitted from the collection grid.
const HIDDEN_LEVEL_IDS := {
	"normal": true,
	"advanced": true,
}

@onready var _back_button: Button = %BackButton
@onready var _boons_tab: Button = %BoonsTab
@onready var _consumables_tab: Button = %ConsumablesTab
@onready var _upgrades_tab: Button = %UpgradesTab
@onready var _item_upgrades_tab: Button = %ItemUpgradesTab
@onready var _bosses_tab: Button = %BossesTab
@onready var _grid: GridContainer = %Grid
@onready var _card: Control = $Center/Layout/Card
@onready var _detail_overlay: ColorRect = %DetailOverlay
@onready var _detail_type: Label = %DetailType
@onready var _detail_icon: TextureRect = %DetailIcon
@onready var _detail_name: Label = %DetailName
@onready var _detail_id: Label = %DetailId
@onready var _detail_description: Label = %DetailDescription
@onready var _close_detail_button: Button = %CloseDetailButton
@onready var _tooltip: TooltipPopup = %Tooltip

var _host: GnosisGodotEngine = null
var _current_tab := "boons"
var _active_tile: Control = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_back_button.pressed.connect(_on_back_pressed)
	_boons_tab.pressed.connect(func(): _show_tab("boons"))
	_consumables_tab.pressed.connect(func(): _show_tab("consumables"))
	_upgrades_tab.pressed.connect(func(): _show_tab("upgrades"))
	_item_upgrades_tab.pressed.connect(func(): _show_tab("itemUpgrades"))
	_bosses_tab.pressed.connect(func(): _show_tab("bosses"))
	_close_detail_button.pressed.connect(_hide_detail)
	if _tooltip:
		_tooltip.scale = Vector2.ZERO
		_tooltip.visible = false
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_populate(_current_tab)
		call_deferred("_focus_back_button")
	else:
		_hide_detail()
		_hide_tooltip()

func _focus_back_button() -> void:
	if is_visible_in_tree() and _back_button:
		_back_button.grab_focus()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_show_tab(_current_tab)

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _show_tab(which: String) -> void:
	_hide_tooltip()
	_current_tab = which
	_boons_tab.button_pressed = which == "boons"
	_consumables_tab.button_pressed = which == "consumables"
	_upgrades_tab.button_pressed = which == "upgrades"
	_item_upgrades_tab.button_pressed = which == "itemUpgrades"
	_bosses_tab.button_pressed = which == "bosses"
	_populate(which)

func _catalog(category: String) -> GnosisNode:
	var eng := _engine()
	if eng == null:
		return GnosisNode.new(null)
	var config := eng.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(category)

func _populate(tab: String) -> void:
	for child in _grid.get_children():
		child.free()
	if not TABS.has(tab):
		return
	var spec: Dictionary = TABS[tab]
	var catalog := _catalog(spec.catalog)
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return
	for key in catalog.get_keys():
		var entry := catalog.get_node(key)
		if not entry.is_valid():
			continue
		if tab == "consumables" and str(key).begins_with(HIDDEN_CONSUMABLE_PREFIX):
			continue
		if tab == "bosses" and HIDDEN_LEVEL_IDS.has(str(key)):
			continue
		_add_tile(str(key), entry, spec)

func _add_tile(item_id: String, entry: GnosisNode, spec: Dictionary) -> void:
	var meta := _metadata_for(entry)
	var sprite_id := _meta_str(meta, "spriteId")
	var name_key := _meta_str(meta, "nameKey")
	var desc_key := _meta_str(meta, "descriptionKey")
	var display_name := _localized(name_key, item_id.capitalize())
	var description := _localized(desc_key, "")
	var tags := _tags_for(meta)

	var tile := Button.new()
	tile.custom_minimum_size = Vector2(150, 150)
	tile.text = ""
	tile.flat = true
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = ""
	tile.clip_contents = false
	tile.modulate.a = 0.6
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tile.focus_entered.connect(func(): _on_tile_focused(tile, display_name, description, tags))
	tile.focus_exited.connect(func(): _on_tile_unfocused(tile))
	tile.mouse_entered.connect(tile.grab_focus)
	tile.pressed.connect(func(): _show_tooltip_for_tile(tile, display_name, description, tags))

	var icon_wrap := CenterContainer.new()
	icon_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon_wrap)

	if spec.get("letter", false):
		icon_wrap.add_child(_make_boss_token(item_id, meta))
	else:
		var icon_path := ""
		if spec.variant:
			icon_path = _block_icon_path(item_id, sprite_id)
		else:
			icon_path = _icon_path(spec.catalog, spec.folder, item_id, sprite_id)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(120, 120)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not icon_path.is_empty():
			icon.texture = load(icon_path)
		else:
			icon.modulate = Color(0.3, 0.34, 0.42)
		icon_wrap.add_child(icon)

	_grid.add_child(tile)

## Builds a boss "token": a rounded square tinted with the profile background
## color, with the starting letter rendered in the boss display font (darling_coffe)
## using the profile text color. Mirrors the in-game level token.
func _make_boss_token(item_id: String, meta: GnosisNode) -> Control:
	var letter := _meta_str(meta, "startingLetter").strip_edges()
	if letter.is_empty():
		letter = item_id.substr(0, 1).to_upper()
	var bg := _parse_color(_meta_str(meta, "backgroundColor"), BOSS_TOKEN_DEFAULT_BG)
	var fg := _parse_color(_meta_str(meta, "textColor"), BOSS_TOKEN_DEFAULT_FG)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(120, 120)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(24)
	box.set_border_width_all(4)
	box.border_color = bg.lightened(0.18)
	panel.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = letter
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", fg)
	label.add_theme_font_size_override("font_size", 72)
	var font := load(BOSS_LETTER_FONT)
	if font:
		label.add_theme_font_override("font", font)
	panel.add_child(label)
	return panel

## Parses a "#RRGGBB"/"#RRGGBBAA" string into a Color, falling back when invalid.
func _parse_color(value: String, fallback: Color) -> Color:
	var raw := value.strip_edges()
	if raw.is_empty() or not raw.begins_with("#"):
		return fallback
	if not Color.html_is_valid(raw):
		return fallback
	return Color.html(raw)

func _show_detail(detail: Dictionary) -> void:
	_detail_overlay.visible = true
	_detail_type.text = tr(str(detail.type_label))
	_detail_name.text = str(detail.name)
	_detail_id.text = str(detail.item_id)
	var description := str(detail.description)
	if description.is_empty():
		description = tr("ultravibe__collection__noDescription")
	_detail_description.text = description
	_detail_icon.texture = null
	var icon_path := str(detail.icon_path)
	if not icon_path.is_empty():
		_detail_icon.texture = load(icon_path)
	_detail_icon.modulate = Color.WHITE

func _hide_detail() -> void:
	if _detail_overlay:
		_detail_overlay.visible = false

func _on_tile_focused(tile: Control, title: String, description: String, tags: Array = []) -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_animate_tile(tile, true)
	_show_tooltip_for_tile(tile, title, description, tags)

func _on_tile_unfocused(tile: Control) -> void:
	_animate_tile(tile, false)
	if _active_tile == tile:
		_hide_tooltip()

func _animate_tile(tile: Control, focused: bool) -> void:
	if not is_instance_valid(tile):
		return
	tile.pivot_offset = tile.size / 2.0
	var prev: Tween = tile.get_meta("focus_tween", null)
	if prev and prev.is_running():
		prev.kill()
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if focused:
		tween.tween_property(tile, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(tile, "scale:x", 1.18, 0.2)
		tween.parallel().tween_property(tile, "scale:y", 1.18, 0.35)
		tween.parallel().tween_property(tile, "rotation_degrees", 5.0 * [-1.0, 1.0].pick_random(), 0.1)
		tween.parallel().tween_property(tile, "rotation_degrees", 0.0, 0.1).set_delay(0.1)
		tile.z_index = 1
	else:
		tween.tween_property(tile, "modulate:a", 0.6, 0.25)
		tween.parallel().tween_property(tile, "scale:x", 1.0, 0.25)
		tween.parallel().tween_property(tile, "scale:y", 1.0, 0.35)
		tween.parallel().tween_property(tile, "rotation_degrees", 0.0, 0.1)
		tile.z_index = 0
	tile.set_meta("focus_tween", tween)

func _show_tooltip_for_tile(tile: Control, title: String, description: String, tags: Array = []) -> void:
	if _tooltip == null:
		return
	_active_tile = tile
	# Free-floating, content-sized panel (the scene anchors are for in-place use).
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	var raw := description if not description.strip_edges().is_empty() else tr("ultravibe__collection__noDescription")
	_tooltip.set_content(title, raw, TOOLTIP_WIDTH, tags)
	# Let the layout settle for one frame, then shrink-wrap to content and place it.
	await get_tree().process_frame
	if _active_tile != tile or not is_instance_valid(tile):
		return
	_tooltip.reset_size()
	await get_tree().process_frame
	if _active_tile != tile or not is_instance_valid(tile):
		return
	_position_tooltip(tile)
	_tooltip.appear()

func _position_tooltip(tile: Control) -> void:
	if _tooltip == null or tile == null or not is_instance_valid(tile):
		return
	var tile_rect := tile.get_global_rect()
	# Keep the tooltip within the grid card so it never floats over the title/tabs.
	var bounds := _card.get_global_rect() if _card else get_global_rect()
	# Use the combined minimum size: it is accurate even right after a relayout,
	# whereas .size can still be stale for a frame after repopulating a tab.
	var tooltip_size := _tooltip.get_combined_minimum_size()
	tooltip_size.x = maxf(tooltip_size.x, _tooltip.size.x)
	tooltip_size.y = maxf(tooltip_size.y, _tooltip.size.y)
	tooltip_size.x = minf(tooltip_size.x, TOOLTIP_MAX_WIDTH)
	tooltip_size.y = minf(tooltip_size.y, bounds.size.y - 16.0)
	var min_y := bounds.position.y + 8.0
	var max_y := maxf(min_y, bounds.end.y - tooltip_size.y - 8.0)
	var x := tile_rect.position.x + (tile_rect.size.x - tooltip_size.x) * 0.5
	# Prefer above the tile; flip below when there is no room above inside the card.
	var y := tile_rect.position.y - tooltip_size.y - 12.0
	if y < min_y:
		y = tile_rect.end.y + 12.0
	x = clampf(x, bounds.position.x + 8.0, maxf(bounds.position.x + 8.0, bounds.end.x - tooltip_size.x - 8.0))
	y = clampf(y, min_y, max_y)
	_tooltip.global_position = Vector2(x, y)
	_tooltip.pivot_offset = Vector2(tooltip_size.x * 0.5, tooltip_size.y)

func _hide_tooltip() -> void:
	if _tooltip == null:
		return
	_active_tile = null
	_tooltip.disappear()

func _metadata_for(entry: GnosisNode) -> GnosisNode:
	var meta := entry.get_node("metadata")
	# Variants store spriteId/nameKey on the entry itself rather than under metadata.
	return meta if meta.is_valid() else entry

func _icon_path(category: String, folder: String, item_id: String, sprite_id: String) -> String:
	var dir := "%s%s/" % [ICON_ROOT, folder]
	var candidates: Array[String] = []
	var key := "%s:%s" % [category, item_id]
	if SPECIAL_ICON_IDS.has(key):
		candidates.append(SPECIAL_ICON_IDS[key])
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
	return _block_sprite_fallback(sprite_id)

## Resolves sprite IDs that point at the shared gem block art (e.g. the colored
## itemUpgrade level-up grants) to a texture under assets/blocks/.
func _block_sprite_fallback(sprite_id: String) -> String:
	return CatalogSpritePathsScript.resolve_item_upgrade_icon(sprite_id)

func _block_icon_path(item_id: String, sprite_id: String) -> String:
	var candidates: Array[String] = []
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	candidates.append("%sBlock" % item_id)
	candidates.append(item_id)
	for candidate in candidates:
		var path := "%s%s.png" % [BLOCK_ICON_DIR, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var eng := _engine()
	if eng == null:
		return fallback
	var localization := eng.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return localization.get_string_value(key, fallback)

func _on_back_pressed() -> void:
	var ui := _game_ui()
	var eng := _engine()
	if ui == null or eng == null:
		return
	UltraGameUiNav.pop_menu_back(ui, eng.store, "slide_left")

func _meta_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

## Reads the uniform `metadata.tags` list (each entry `{tagType, tagLocKey}`) into
## tooltip smart-chip dictionaries `{type, label}` with the label localized.
## Mirrors Unity's GnosisTooltipTagEntry parsing so every catalog (boons,
## consumables, upgrades, bosses) shares one format.
func _tags_for(meta: GnosisNode) -> Array:
	var result: Array = []
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
		var label := _localized(loc_key, type_id.capitalize())
		if label.strip_edges().is_empty():
			continue
		result.append({"type": type_id, "label": label})
	return result

