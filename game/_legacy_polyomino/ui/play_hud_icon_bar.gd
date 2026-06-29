class_name PlayHudIconBar
extends HBoxContainer

## Shared bottom-bar icon row: floating slots, hover tooltips, and icon resolution
## from ephemeral inventory entries. Subclasses override category, alignment,
## opacity, and click handling.

const TOOLTIP_SCENE := preload("res://game/ui/widgets/tooltip_popup.tscn")
const ICON_ROOT := "res://assets/icons/"

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

var _service: FallingBlockService = null
var _tooltip: TooltipPopup = null
var _tooltip_index := -1
var _slot_nodes: Array[Control] = []
var _last_signature := "__unset__"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bar_alignment()
	add_theme_constant_override("separation", int(slot_gap))
	_build_tooltip()
	set_process(true)

func bind_service(service: FallingBlockService) -> void:
	_service = service
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
func _on_slot_pressed(_index: int) -> void:
	pass

## Vertical placement of each slot within the bar. Bottom bars anchor to the
## bottom edge so icons float up; the topbar overrides this to center instead.
func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_END

func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN

func _build_tooltip() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child(_tooltip)
	_tooltip.top_level = true
	_tooltip.z_index = 60
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false

func _process(_delta: float) -> void:
	_refresh_if_changed()
	if _tooltip_index >= 0 and _tooltip and _tooltip.visible:
		_tooltip.reset_size()
		_position_tooltip(_tooltip_index)

func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()

func _refresh() -> void:
	for slot in _slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()
	_slot_nodes.clear()
	_hide_tooltip()

	var entries := _entries()
	for i in range(entries.size()):
		var slot := _make_slot(i, entries[i])
		add_child(slot)
		_slot_nodes.append(slot)
	if _tooltip and is_instance_valid(_tooltip):
		move_child(_tooltip, get_child_count() - 1)
	queue_redraw()

func _notification(what: int) -> void:
	# Redraw the capacity dots once the HBox has positioned the slots.
	if what == NOTIFICATION_SORT_CHILDREN:
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
	slot.custom_minimum_size = Vector2(slot_size, slot_size + float_offset)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = _slot_size_flags_vertical()

	var alpha := _slot_alpha(index, details)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_TOP_WIDE)
	icon.offset_bottom = slot_size
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = Color(1, 1, 1, alpha)
	var icon_path: String = details.get("icon_path", "")
	if not icon_path.is_empty():
		icon.texture = load(icon_path)
	slot.add_child(icon)

	var count := _slot_stack_count(details)
	if count > 1:
		var badge := Label.new()
		badge.name = "Count"
		badge.text = "x%d" % count
		badge.set_anchors_preset(Control.PRESET_TOP_LEFT)
		badge.offset_left = slot_size - 28.0
		badge.offset_top = slot_size - 20.0
		badge.offset_right = slot_size + 2.0
		badge.offset_bottom = slot_size + 2.0
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		badge.add_theme_font_size_override("font_size", 16)
		badge.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(badge)

	var hit := Button.new()
	hit.name = "Hit"
	hit.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hit.offset_bottom = slot_size
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var idx := index
	hit.pressed.connect(func(): _on_slot_pressed(idx))
	hit.mouse_entered.connect(func(): _on_slot_hovered(idx))
	hit.mouse_exited.connect(_on_slot_unhovered)
	slot.add_child(hit)

	return slot

func _on_slot_hovered(index: int) -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_show_tooltip_for_slot(index)

func _on_slot_unhovered() -> void:
	_hide_tooltip()

func _show_tooltip_for_slot(index: int) -> void:
	if _tooltip == null:
		return
	var entries := _entries()
	if index < 0 or index >= entries.size():
		return
	_tooltip_index = index
	var details: Dictionary = entries[index]
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	_tooltip.set_content(details.get("name", ""), details.get("description", ""))
	_tooltip.reset_size()
	_position_tooltip(index)
	_tooltip.appear()

func _position_tooltip(index: int) -> void:
	if _tooltip == null or index < 0 or index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	if slot == null or not is_instance_valid(slot):
		return
	var slot_rect := slot.get_global_rect()
	var size := _tooltip.size
	var x := slot_rect.position.x + (slot_rect.size.x - size.x) * 0.5
	var y := slot_rect.position.y - size.y - 14.0
	if y < 8.0:
		y = slot_rect.end.y + 14.0
	_tooltip.global_position = Vector2(x, y)
	_tooltip.pivot_offset = Vector2(size.x * 0.5, size.y)

func _hide_tooltip() -> void:
	_tooltip_index = -1
	if _tooltip:
		_tooltip.disappear()

func force_refresh() -> void:
	_last_signature = "__unset__"
	_refresh()

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

func _describe_entry(entry: GnosisNode) -> Dictionary:
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
	return {
		"name": name,
		"description": desc,
		"icon_path": _icon_path(item_id, sprite_id),
		"count": maxi(1, _node_int(entry, "currentCount", 1)),
	}

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
	candidates.append(item_id)
	candidates.append(item_id.capitalize())
	for candidate in candidates:
		var path := "%s%s.png" % [folder, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""

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
