class_name UltravibeAchievementsView
extends GnosisUIElementView

const UltraAchievementProgress = preload("res://game/ui/ultra_achievement_progress.gd")

## Achievement gallery (viewId "achievements"). Flow-wrapped trophy tiles with focus
## tooltips; earned vs locked uses opacity, hidden entries show a "?" glyph.

enum TileState { EARNED, LOCKED_VISIBLE, HIDDEN }

const ICON_ACHIEVEMENT := preload("res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/achievement.png")
const ICON_LOCKED := preload("res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/locked.png")
const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

const TOOLTIP_WIDTH := 300.0
const TOOLTIP_MAX_WIDTH := 360.0
const OPACITY_EARNED_IDLE := 0.72
const OPACITY_EARNED_FOCUS := 1.0
const OPACITY_LOCKED_IDLE := 0.42
const OPACITY_LOCKED_FOCUS := 0.62
const OPACITY_HIDDEN_IDLE := 0.34
const OPACITY_HIDDEN_FOCUS := 0.52

@onready var _back_button: Button = %BackButton
@onready var _tab_bar: PanelContainer = $Center/Layout/TabBar
@onready var _grid: HFlowContainer = %Grid
@onready var _card: PanelContainer = $Center/Layout/Card
@onready var _tooltip: TooltipPopup = %Tooltip

var _host: GnosisGodotEngine = null
var _active_tile: Control = null
var _tooltip_show_generation := 0
var _counter_label: Label = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_back_button.pressed.connect(_on_back_pressed)
	if _tooltip:
		_tooltip.scale = Vector2.ZERO
		_tooltip.visible = false
	_ensure_progress_counter()
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		_refresh_progress_counter()
		_populate_grid()
		call_deferred("_focus_back_button")
	else:
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
	_refresh_progress_counter()
	_populate_grid()

func _achievement_service():
	var eng := _engine()
	return eng.get_service("Achievement") if eng else null

func _ensure_progress_counter() -> void:
	if _counter_label != null or _tab_bar == null:
		return
	var tabs := _tab_bar.get_node_or_null("Tabs")
	if tabs == null:
		return
	_counter_label = Label.new()
	_counter_label.name = "AchievementCounter"
	_counter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_counter_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UltraAchievementProgress.apply_gallery_style(_counter_label)
	tabs.add_child(_counter_label)

func _refresh_progress_counter() -> void:
	if _counter_label == null:
		return
	_counter_label.text = UltraAchievementProgress.label(_achievement_service())

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _catalog() -> GnosisNode:
	var eng := _engine()
	if eng == null:
		return GnosisNode.new(null)
	var config := eng.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node("achievements")

func _populate_grid() -> void:
	if _grid == null:
		return
	for child in _grid.get_children():
		child.free()
	var catalog := _catalog()
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return
	for key in catalog.get_keys():
		var entry := catalog.get_node(key)
		if not entry.is_valid():
			continue
		var achievement_id := str(key)
		var achievements = _achievement_service()
		var earned: bool = achievements != null and achievements.is_earned(achievement_id)
		_add_tile(achievement_id, entry, earned)

func _add_tile(achievement_id: String, entry: GnosisNode, earned: bool) -> void:
	var hidden := _meta_bool(entry, "hidden")
	var tile_state := TileState.EARNED if earned else (TileState.HIDDEN if hidden else TileState.LOCKED_VISIBLE)
	var copy := _display_copy(entry, tile_state)
	var idle_opacity := _idle_opacity_for(tile_state)

	var tile := Button.new()
	tile.custom_minimum_size = Vector2(150, 150)
	tile.text = ""
	tile.flat = true
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = ""
	tile.clip_contents = false
	tile.modulate.a = idle_opacity
	tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	tile.focus_entered.connect(func(): _on_tile_focused(tile, tile_state, copy.title, copy.description))
	tile.focus_exited.connect(func(): _on_tile_unfocused(tile, tile_state))
	tile.mouse_entered.connect(tile.grab_focus)

	var icon_wrap := CenterContainer.new()
	icon_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(icon_wrap)

	if tile_state == TileState.HIDDEN and not earned:
		var mystery := Label.new()
		mystery.text = "?"
		mystery.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mystery.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mystery.add_theme_font_override("font", UI_FONT)
		mystery.add_theme_font_size_override("font_size", 84)
		mystery.add_theme_color_override("font_color", Color(0.88, 0.86, 0.98, 1))
		mystery.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_wrap.add_child(mystery)
	else:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(96, 96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = ICON_ACHIEVEMENT if earned else ICON_LOCKED
		if earned:
			icon.modulate = Color(0.92, 0.88, 1.0, 1)
		else:
			icon.modulate = Color(0.72, 0.7, 0.84, 1)
		icon_wrap.add_child(icon)

	_grid.add_child(tile)

func _display_copy(entry: GnosisNode, tile_state: TileState) -> Dictionary:
	if tile_state == TileState.HIDDEN:
		return {
			"title": tr("ultravibe__achievement__secret__name"),
			"description": tr("ultravibe__achievement__secret__description"),
		}
	var name_key := _meta_str(entry, "nameKey")
	var desc_key := _meta_str(entry, "descriptionKey")
	return {
		"title": _localized(name_key, name_key),
		"description": _localized(desc_key, ""),
	}

func _idle_opacity_for(tile_state: TileState) -> float:
	match tile_state:
		TileState.EARNED:
			return OPACITY_EARNED_IDLE
		TileState.HIDDEN:
			return OPACITY_HIDDEN_IDLE
	return OPACITY_LOCKED_IDLE

func _focus_opacity_for(tile_state: TileState) -> float:
	match tile_state:
		TileState.EARNED:
			return OPACITY_EARNED_FOCUS
		TileState.HIDDEN:
			return OPACITY_HIDDEN_FOCUS
	return OPACITY_LOCKED_FOCUS

func _on_tile_focused(tile: Control, tile_state: TileState, title: String, description: String) -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_animate_tile(tile, tile_state, true)
	_show_tooltip_for_tile(tile, title, description)

func _on_tile_unfocused(tile: Control, tile_state: TileState) -> void:
	_animate_tile(tile, tile_state, false)
	if _active_tile == tile:
		_hide_tooltip()

func _animate_tile(tile: Control, tile_state: TileState, focused: bool) -> void:
	if not is_instance_valid(tile):
		return
	tile.pivot_offset = tile.size / 2.0
	var prev: Tween = tile.get_meta("focus_tween", null)
	if prev and prev.is_running():
		prev.kill()
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	var target_alpha := _focus_opacity_for(tile_state) if focused else _idle_opacity_for(tile_state)
	if focused:
		tween.tween_property(tile, "modulate:a", target_alpha, 0.2)
		tween.parallel().tween_property(tile, "scale:x", 1.18, 0.2)
		tween.parallel().tween_property(tile, "scale:y", 1.18, 0.35)
		tween.parallel().tween_property(tile, "rotation_degrees", 5.0 * [-1.0, 1.0].pick_random(), 0.1)
		tween.parallel().tween_property(tile, "rotation_degrees", 0.0, 0.1).set_delay(0.1)
		tile.z_index = 1
	else:
		tween.tween_property(tile, "modulate:a", target_alpha, 0.25)
		tween.parallel().tween_property(tile, "scale:x", 1.0, 0.25)
		tween.parallel().tween_property(tile, "scale:y", 1.0, 0.35)
		tween.parallel().tween_property(tile, "rotation_degrees", 0.0, 0.1)
		tile.z_index = 0
	tile.set_meta("focus_tween", tween)

func _show_tooltip_for_tile(tile: Control, title: String, description: String) -> void:
	if _tooltip == null:
		return
	if _active_tile == tile and _tooltip.visible and _tooltip.scale.x > 0.05:
		return
	_tooltip_show_generation += 1
	var generation := _tooltip_show_generation
	_active_tile = tile
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	var raw := description if not description.strip_edges().is_empty() else tr("ultravibe__collection__noDescription")
	_tooltip.set_content(title, raw, TOOLTIP_WIDTH)
	await get_tree().process_frame
	if generation != _tooltip_show_generation or _active_tile != tile or not is_instance_valid(tile):
		return
	_tooltip.reset_size()
	await get_tree().process_frame
	if generation != _tooltip_show_generation or _active_tile != tile or not is_instance_valid(tile):
		return
	_position_tooltip(tile)
	_tooltip.appear()

func _position_tooltip(tile: Control) -> void:
	if _tooltip == null or tile == null or not is_instance_valid(tile):
		return
	var tile_rect := tile.get_global_rect()
	var bounds := _card.get_global_rect() if _card else get_global_rect()
	var tooltip_size := _tooltip.get_combined_minimum_size()
	tooltip_size.x = maxf(tooltip_size.x, _tooltip.size.x)
	tooltip_size.y = maxf(tooltip_size.y, _tooltip.size.y)
	tooltip_size.x = minf(tooltip_size.x, TOOLTIP_MAX_WIDTH)
	tooltip_size.y = minf(tooltip_size.y, bounds.size.y - 16.0)
	var min_y := bounds.position.y + 8.0
	var max_y := maxf(min_y, bounds.end.y - tooltip_size.y - 8.0)
	var x := tile_rect.position.x + (tile_rect.size.x - tooltip_size.x) * 0.5
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
	_tooltip_show_generation += 1
	_active_tile = null
	_tooltip.disappear()

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

func _meta_str(node: GnosisNode, key: String) -> String:
	var meta := node.get_node("metadata")
	if not meta.is_valid():
		meta = node
	var field := meta.get_node(key)
	return str(field.value) if field.is_valid() and field.value != null else ""

func _meta_bool(node: GnosisNode, key: String) -> bool:
	var meta := node.get_node("metadata")
	if not meta.is_valid():
		meta = node
	var field := meta.get_node(key)
	return field.is_valid() and bool(field.value)

func _on_back_pressed() -> void:
	var ui := _game_ui()
	var eng := _engine()
	if ui == null or eng == null:
		return
	UltraGameUiNav.pop_menu_back(ui, eng.store, "slide_left")
