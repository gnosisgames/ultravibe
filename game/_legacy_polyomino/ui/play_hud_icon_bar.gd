class_name PlayHudIconBar
extends BoxContainer

## Shared bottom-bar icon row: floating slots, hover tooltips, and icon resolution
## from ephemeral inventory entries. Subclasses override category, alignment,
## opacity, and click handling.

const TOOLTIP_SCENE := preload("res://game/ui/widgets/tooltip_popup.tscn")
const ICON_ROOT := "res://assets/icons/"
const CatalogSpritePathsScript = preload("res://game/ui/catalog_sprite_paths.gd")
const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")

## Icons are intentionally taller than the bar (~46px content) so they overflow
## upward and read as "hovering" above it.
@export var slot_size: float = 64.0
@export var slot_gap: float = 14.0
## Empty space reserved below each icon so it floats up off the bar's bottom edge.
@export var float_offset: float = 16.0

@export_group("Capacity dots")
## Draw a row of slot dots beneath the icons (filled = occupied, dim = empty).
@export var show_capacity_dots: bool = true
@export var dot_radius: float = 3.5
@export var dot_spacing: float = 11.0
## Reserve at the very bottom of the bar so the dots sit below the floating icons.
@export var dot_bottom_margin: float = 5.0
## Above this capacity the bag is treated as unlimited: only owned items get a
## glow dot (no empty slots are drawn), so a 999-cap bag does not draw 999 dots.
@export var max_capacity_dots: int = 12
@export var dot_filled_color: Color = Color(1, 1, 1, 0.9)
@export var dot_empty_color: Color = Color(1, 1, 1, 0.22)

var _service: GnosisService = null
var _tooltip: TooltipPopup = null
var _tooltip_index := -1
var _tooltip_reroll_elapsed := 0.0
var _tooltip_input_mode_connected := false
const TOOLTIP_REROLL_INTERVAL := 0.35
var _slot_nodes: Array[Control] = []
var _last_signature := "__unset__"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bar_alignment()
	add_theme_constant_override("separation", int(slot_gap))
	_build_tooltip()
	set_process(true)

func bind_service(service: GnosisService) -> void:
	_service = service
	_last_signature = "__unset__"
	_refresh()


func force_refresh() -> void:
	_last_signature = "__unset__"
	_refresh()

## Subclasses return the configuration/icons folder name ("boons", "consumables").
func _inventory_category() -> String:
	return ""

## Subclasses return the ephemeral bag list node for this inventory.
func _inventory_list() -> GnosisNode:
	return GnosisNode.new(null)

## Subclasses return extra signature fragments (e.g. selected slot index).
func _extra_signature_parts() -> Array[String]:
	return []

## Per-slot alpha; default is fully opaque.
func _slot_alpha(_index: int, _details: Dictionary) -> float:
	return 1.0

## Total bag capacity (slot count). 0 or a value above max_capacity_dots is
## treated as unlimited. Subclasses read their bag's maxSize.
func _bag_capacity() -> int:
	return 0

## Optional stack-count badge; override to return count > 1 when stackable.
func _slot_stack_count(_details: Dictionary) -> int:
	return 1

## Called when a slot is clicked; no-op by default (boons are read-only).
func play_scaling_up_juice(slot_index: int, score_kind: String) -> void:
	if slot_index < 0 or slot_index >= _slot_nodes.size():
		return
	var slot: Control = _slot_nodes[slot_index]
	if slot == null or not is_instance_valid(slot):
		return
	var JuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
	JuiceScript.play_on_slot(self, slot, score_kind)


func play_score_juice(slot_index: int, score_kind: String, display_text: String) -> void:
	if slot_index < 0 or slot_index >= _slot_nodes.size():
		return
	var slot: Control = _slot_nodes[slot_index]
	if slot == null or not is_instance_valid(slot):
		return
	var JuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
	JuiceScript.play_score_on_slot(self, slot, score_kind, display_text)

## Vertical placement of each slot within the bar. Bottom bars anchor to the
## bottom edge so icons float up; the topbar overrides this to center instead.
func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_END


func _slot_size_flags_horizontal() -> int:
	return Control.SIZE_SHRINK_CENTER


## When true, the icon texture scales to fill the whole slot (left rail).
func _slot_icon_fills_cell() -> bool:
	return false


func _stack_badge_font() -> Font:
	return null


func _stack_badge_font_size() -> int:
	return 16


func _stack_badge_rect(slot_size: float) -> Rect2:
	return Rect2(slot_size - 30.0, slot_size - 22.0, slot_size + 4.0, slot_size + 4.0)


func _resolve_slot_size() -> float:
	return slot_size


func _slot_icon_stretch_mode() -> TextureRect.StretchMode:
	if _slot_icon_fills_cell():
		return TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN

func _build_tooltip() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child(_tooltip)
	_tooltip.top_level = true
	_tooltip.z_index = 60
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false
	_connect_tooltip_input_mode_listener()


func _connect_tooltip_input_mode_listener() -> void:
	if _tooltip_input_mode_connected:
		return
	var icons := get_node_or_null("/root/ControllerIcons")
	if icons == null or not icons.has_signal("input_type_changed"):
		return
	icons.input_type_changed.connect(_on_tooltip_input_mode_changed)
	_tooltip_input_mode_connected = true


func _on_tooltip_input_mode_changed(_input_type: int, _controller: int) -> void:
	if _tooltip_index >= 0 and _tooltip != null and _tooltip.visible:
		_refresh_tooltip_content(_tooltip_index)

func _process(delta: float) -> void:
	if _should_skip_live_refresh():
		if _tooltip_index >= 0:
			_hide_tooltip()
		return
	_refresh_if_changed()
	if _tooltip_index >= 0 and _tooltip and _tooltip.visible:
		_position_tooltip(_tooltip_index)
		_tooltip_reroll_elapsed += delta
		if _tooltip_reroll_elapsed >= TOOLTIP_REROLL_INTERVAL:
			_tooltip_reroll_elapsed = 0.0
			_refresh_tooltip_content(_tooltip_index)


func _should_skip_live_refresh() -> bool:
	if _service == null:
		return false
	if _service.has_method("is_consumable_use_presentation_active"):
		return _service.is_consumable_use_presentation_active()
	return false


func _relayout_slot_sizes() -> void:
	var cell_size := _resolve_slot_size()
	if cell_size < 8.0:
		return
	slot_size = cell_size
	for slot in _slot_nodes:
		if not is_instance_valid(slot):
			continue
		slot.custom_minimum_size = Vector2(cell_size, cell_size + float_offset)
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.custom_minimum_size = Vector2(cell_size, cell_size)
			if _slot_icon_fills_cell():
				icon.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon.offset_right = 0.0
				icon.offset_bottom = 0.0
			else:
				icon.set_anchors_preset(Control.PRESET_TOP_WIDE)
				icon.offset_bottom = cell_size
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			if _slot_icon_fills_cell():
				hit.set_anchors_preset(Control.PRESET_FULL_RECT)
				hit.offset_right = 0.0
				hit.offset_bottom = 0.0
			else:
				hit.set_anchors_preset(Control.PRESET_TOP_WIDE)
				hit.offset_bottom = cell_size
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			var badge_rect := _stack_badge_rect(cell_size)
			badge.offset_left = badge_rect.position.x
			badge.offset_top = badge_rect.position.y
			badge.offset_right = badge_rect.end.x
			badge.offset_bottom = badge_rect.end.y
			badge.add_theme_font_size_override(&"font_size", _stack_badge_font_size())
	queue_sort()
	queue_redraw()

func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()

func _refresh() -> void:
	_free_slot_nodes_now()
	_hide_tooltip()

	var entries := _entries()
	for i in range(entries.size()):
		var slot := _make_slot(i, entries[i])
		add_child(slot)
		_slot_nodes.append(slot)
	if _tooltip and is_instance_valid(_tooltip):
		_raise_tooltip()
	call_deferred("_relayout_slot_sizes")
	queue_redraw()


func _free_slot_nodes_now() -> void:
	# queue_free is deferred — rapid gameplay refresh_from_service stacked dozens of
	# live Slot* children, inflated PanelContainers, and blew the left rail to 3x height.
	for slot in _slot_nodes:
		if slot != null and is_instance_valid(slot):
			var parent := slot.get_parent()
			if parent:
				parent.remove_child(slot)
			slot.free()
	_slot_nodes.clear()
	for child in get_children():
		if child is Control and str(child.name).begins_with("Slot"):
			remove_child(child)
			child.free()


func _raise_tooltip() -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		return
	var parent := _tooltip.get_parent()
	if parent:
		parent.move_child(_tooltip, -1)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_relayout_slot_sizes()
	elif what == NOTIFICATION_SORT_CHILDREN:
		# Redraw the capacity dots once the box has positioned the slots.
		queue_redraw()

func _draw() -> void:
	if not show_capacity_dots:
		return
	var occupied := _slot_nodes.size()
	var capacity := _bag_capacity()
	var unlimited := capacity <= 0 or capacity > max_capacity_dots
	var total_dots := occupied if unlimited else capacity
	if total_dots <= 0:
		return
	var row_width := float(total_dots - 1) * dot_spacing
	var center_x := _dots_center_x(row_width)
	var y := size.y - dot_bottom_margin - dot_radius
	var start_x := center_x - row_width * 0.5
	for i in range(total_dots):
		var pos := Vector2(start_x + float(i) * dot_spacing, y)
		if i < occupied:
			# Faint halo + bright core so occupied slots read as a soft glow.
			draw_circle(pos, dot_radius * 1.8, Color(dot_filled_color.r, dot_filled_color.g, dot_filled_color.b, dot_filled_color.a * 0.3))
			draw_circle(pos, dot_radius, dot_filled_color)
		else:
			draw_circle(pos, dot_radius, dot_empty_color)

## Horizontal center for the dots row: under the icon cluster when slots exist,
## otherwise anchored to the bar's alignment edge so an empty bag still reads.
func _dots_center_x(row_width: float) -> float:
	if not _slot_nodes.is_empty():
		var min_x := INF
		var max_x := -INF
		for slot in _slot_nodes:
			if not is_instance_valid(slot):
				continue
			min_x = minf(min_x, slot.position.x)
			max_x = maxf(max_x, slot.position.x + slot.size.x)
		if min_x <= max_x:
			return (min_x + max_x) * 0.5
	match alignment:
		BoxContainer.ALIGNMENT_END:
			return size.x - row_width * 0.5
		BoxContainer.ALIGNMENT_CENTER:
			return size.x * 0.5
		_:
			return row_width * 0.5

func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := Control.new()
	slot.name = "Slot%d" % index
	var cell_size := _resolve_slot_size()
	slot.custom_minimum_size = Vector2(cell_size, cell_size + float_offset)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = _slot_size_flags_vertical()
	slot.size_flags_horizontal = _slot_size_flags_horizontal()

	var alpha := _slot_alpha(index, details)
	var icon := TextureRect.new()
	icon.name = &"Icon"
	if _slot_icon_fills_cell():
		icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon.offset_right = 0.0
		icon.offset_bottom = 0.0
	else:
		icon.set_anchors_preset(Control.PRESET_TOP_WIDE)
		icon.offset_bottom = cell_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = _slot_icon_stretch_mode()
	icon.custom_minimum_size = Vector2(cell_size, cell_size)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, alpha)
	var icon_path: String = details.get("icon_path", "")
	if not icon_path.is_empty():
		icon.texture = load(icon_path)
	slot.add_child(icon)

	var count := _slot_stack_count(details)
	if count > 1:
		var badge := Label.new()
		badge.name = &"Count"
		badge.text = "x%d" % count
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		var badge_rect := _stack_badge_rect(cell_size)
		badge.offset_left = badge_rect.position.x
		badge.offset_top = badge_rect.position.y
		badge.offset_right = badge_rect.end.x
		badge.offset_bottom = badge_rect.end.y
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		var badge_font := _stack_badge_font()
		if badge_font:
			badge.add_theme_font_override(&"font", badge_font)
		badge.add_theme_font_size_override(&"font_size", _stack_badge_font_size())
		badge.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.95))
		badge.add_theme_color_override(&"font_outline_color", Color(0.0784314, 0.137255, 0.227451, 1))
		badge.add_theme_constant_override(&"outline_size", 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

	var hit := Button.new()
	hit.name = &"Hit"
	if _slot_icon_fills_cell():
		hit.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit.offset_right = 0.0
		hit.offset_bottom = 0.0
	else:
		hit.set_anchors_preset(Control.PRESET_TOP_WIDE)
		hit.offset_bottom = cell_size
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var idx := index
	_connect_slot_hit(hit, idx)
	hit.mouse_entered.connect(func(): _on_slot_hovered(idx))
	hit.mouse_exited.connect(_on_slot_unhovered)
	slot.add_child(hit)

	return slot


func _connect_slot_hit(hit: Button, index: int) -> void:
	hit.pressed.connect(func(): _on_slot_pressed(index))


func _on_slot_pressed(_index: int) -> void:
	pass


func _on_slot_hovered(index: int) -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_show_tooltip_for_slot(index)

func _on_slot_unhovered() -> void:
	_hide_tooltip()

func _show_tooltip_for_slot(index: int) -> void:
	if _tooltip == null:
		return
	var list := _inventory_list()
	if index < 0 or index >= list.get_count():
		return
	_tooltip_index = index
	_tooltip_reroll_elapsed = 0.0
	_refresh_tooltip_content(index)
	_tooltip.reset_size()
	_position_tooltip(index)
	_raise_tooltip()
	_tooltip.appear()


func _refresh_tooltip_content(index: int) -> void:
	if _tooltip == null:
		return
	var list := _inventory_list()
	if index < 0 or index >= list.get_count():
		return
	var entry := list.get_node(index)
	var details: Dictionary = _describe_entry(entry, true)
	var actions := _tooltip_actions_for_entry(entry)
	_tooltip.visible = true
	_tooltip.set_content(
		details.get("name", ""),
		details.get("description", ""),
		TooltipPopup.DEFAULT_CONTENT_WIDTH,
		details.get("tags", []),
		actions,
	)


func _tooltip_actions_for_entry(_entry: GnosisNode) -> Array:
	return []


func _try_handle_tooltip_action(action_id: String, _entry: GnosisNode) -> bool:
	return false


func _unhandled_input(event: InputEvent) -> void:
	if _tooltip_index < 0 or _tooltip == null or not _tooltip.visible:
		return
	var sell_requested := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		sell_requested = true
	elif event.is_action_pressed("UISell") and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		sell_requested = true
	if not sell_requested:
		return
	var list := _inventory_list()
	if _tooltip_index < 0 or _tooltip_index >= list.get_count():
		return
	var entry := list.get_node(_tooltip_index)
	if _try_handle_tooltip_action("UISell", entry):
		get_viewport().set_input_as_handled()

func _position_tooltip(index: int) -> void:
	if _tooltip == null or index < 0 or index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	if slot == null or not is_instance_valid(slot):
		return
	TooltipPopup.position_at_anchor(_tooltip, slot, _tooltip_prefer_side())


## Subclasses override when icons sit on a screen edge (e.g. left-rail upgrades).
func _tooltip_prefer_side() -> TooltipPopup.PIVOT_SIDE:
	return TooltipPopup.PIVOT_SIDE.TOP

func _hide_tooltip() -> void:
	_tooltip_index = -1
	_tooltip_reroll_elapsed = 0.0
	if _tooltip:
		_tooltip.disappear()


func _refresh_parent_hud() -> void:
	var node: Node = self
	while node:
		var script_path := str(node.get_script().resource_path) if node.get_script() else ""
		if script_path.ends_with("match3_hud.gd") and node.has_method("refresh_from_service"):
			node.refresh_from_service(_service)
			return
		if script_path.ends_with("match3_dispatcher.gd") and node.has_method("refresh_hud"):
			node.refresh_hud()
			return
		node = node.get_parent()

# --- Data ---

func _ephemeral() -> GnosisNode:
	if _service == null or _service.context == null or _service.context.state == null:
		return GnosisNode.new(null)
	return _service.context.state.root.get_node("Ephemeral")

func _entries() -> Array:
	var out: Array = []
	if _service == null:
		return out
	var list := _inventory_list()
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return out
	for i in range(list.get_count()):
		out.append(_describe_entry(list.get_node(i)))
	return out

func _build_signature() -> String:
	if _service == null or _service.context == null:
		return ""
	var parts: Array[String] = _extra_signature_parts()
	var list := _inventory_list()
	if list.is_valid() and list.get_type() == GnosisValueType.LIST:
		for i in range(list.get_count()):
			var entry := list.get_node(i)
			parts.append("%s:%d" % [_resolve_item_id(entry), _node_int(entry, "currentCount", 1)])
	return "|".join(parts)

func _describe_entry(entry: GnosisNode, reroll_random_preview: bool = false) -> Dictionary:
	var item_id := _resolve_item_id(entry)
	var name := item_id.capitalize()
	var desc := ""
	var sprite_id := ""
	var metadata := entry.get_node("metadata")
	if metadata.is_valid():
		var name_key := _node_str(metadata, "nameKey")
		var desc_key := _node_str(metadata, "descriptionKey")
		sprite_id = _node_str(metadata, "spriteId")
		name = _localized(name_key, name)
		desc = _localized_raw(desc_key, desc)
	var base := {
		"name": name,
		"description": desc,
		"icon_path": _icon_path(item_id, sprite_id),
		"count": maxi(1, _node_int(entry, "currentCount", 1)),
		"tags": [],
	}
	return InventoryTooltipUiScript.enrich_entry_details(
		_service,
		entry,
		_inventory_category(),
		base,
		reroll_random_preview,
	)

func _resolve_item_id(entry: GnosisNode) -> String:
	for key in ["id", "consumableId", "boonId", "abilityId"]:
		var v := _node_str(entry, key)
		if not v.is_empty():
			return v
	return ""

func _icon_path(item_id: String, sprite_id: String) -> String:
	var category := _inventory_category()
	if category.is_empty():
		return ""
	var folder := "%s%s/" % [ICON_ROOT, category]
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
		candidates.append(sprite_id.trim_prefix("runUpgrade").trim_suffix("Sprite"))
	if sprite_id.begins_with("upgrade") and sprite_id.ends_with("Sprite"):
		candidates.append(sprite_id.trim_prefix("upgrade").trim_suffix("Sprite"))
	candidates.append(item_id)
	candidates.append(item_id.capitalize())
	for candidate in candidates:
		var path := "%s%s.png" % [folder, candidate]
		if ResourceLoader.exists(path):
			return path
	return CatalogSpritePathsScript.resolve_item_upgrade_icon(sprite_id, item_id)

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty() or _service == null or _service.context == null:
		return fallback
	var localization := _service.context.engine.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return _clean_rich_text(localization.get_string_value(key, fallback))

func _localized_raw(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty() or _service == null or _service.context == null:
		return fallback
	var localization := _service.context.engine.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	return localization.get_string_value(key, fallback)

func _clean_rich_text(value: String) -> String:
	var text := value
	var tag_re := RegEx.new()
	if tag_re.compile("<[^>]+>") == OK:
		text = tag_re.sub(text, "", true)
	var arg_re := RegEx.new()
	if arg_re.compile("\\$\\{arg:[^}]+\\}") == OK:
		text = arg_re.sub(text, "?", true)
	return text

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

func _node_int(node: GnosisNode, key: String, default_value: int) -> int:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return int(n.value)
	return default_value
