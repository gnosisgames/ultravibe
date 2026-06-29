class_name PlayHudRewardSlots
extends Control

## Inline round-reward picker rendered over the center of the playfield.
## Mirrors the old Unity board reward row: three icon slots, a selection
## checkmark (no focus ring), tooltip on hover, and click / reward_prev-next
## to move the highlight. The selected offer is granted automatically when the
## round advances (see FallingBlockService._apply_round_progress_loop).

const FB := preload("res://game/services/falling_block_ephemeral.gd")
const TOOLTIP_SCENE := preload("res://game/ui/widgets/tooltip_popup.tscn")
const CHECKMARK_ICON := preload("res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/checkmark.png")
const ICON_ROOT := "res://assets/icons/"
const SPECIAL_ICON_IDS := {
	"ability:gridShift": "gridSwap"
}
const DISPLAY_SLOT_COUNT := 3

@export var slot_size: float = 128.0
@export var slot_gap: float = 18.0
@export var checkmark_offset: Vector2 = Vector2(0, -18)

var _service: FallingBlockService = null
var _board_renderer: FallingBlockBoardRenderer = null
var _slots_root: HBoxContainer = null
var _slot_nodes: Array[Control] = []
var _last_signature := ""
var _hovered_index := -1
var _tooltip: TooltipPopup = null
var _tooltip_slot := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_slots()
	_build_tooltip()
	visible = false
	set_process(true)

func bind_service(service: FallingBlockService) -> void:
	_service = service

func _build_slots() -> void:
	_slots_root = HBoxContainer.new()
	_slots_root.name = "Slots"
	_slots_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots_root.add_theme_constant_override("separation", int(slot_gap))
	_slots_root.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots_root)
	_slot_nodes.clear()
	for i in range(DISPLAY_SLOT_COUNT):
		_slot_nodes.append(_make_slot(i))

func _make_slot(index: int) -> Control:
	var slot := Control.new()
	slot.name = "Slot%d" % index
	slot.custom_minimum_size = Vector2(slot_size, slot_size)
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var frame := Panel.new()
	frame.name = "Frame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _make_slot_style())
	slot.add_child(frame)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.custom_minimum_size = Vector2(slot_size * 0.72, slot_size * 0.72)
	icon.offset_left = -slot_size * 0.36
	icon.offset_top = -slot_size * 0.36
	icon.offset_right = slot_size * 0.36
	icon.offset_bottom = slot_size * 0.36
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(icon)

	var check := TextureRect.new()
	check.name = "Check"
	check.visible = false
	check.set_anchors_preset(Control.PRESET_CENTER_TOP)
	check.offset_left = -20.0
	check.offset_top = checkmark_offset.y
	check.offset_right = 20.0
	check.offset_bottom = checkmark_offset.y + 40.0
	check.texture = CHECKMARK_ICON
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.modulate = Color(0.35, 0.95, 0.45)
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(check)

	var hit := Button.new()
	hit.name = "Hit"
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	hit.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var slot_index := index
	hit.pressed.connect(func(): _select_slot(slot_index))
	hit.mouse_entered.connect(func(): _on_slot_hovered(slot_index))
	hit.mouse_exited.connect(_on_slot_unhovered)
	slot.add_child(hit)

	_slots_root.add_child(slot)
	return slot

func _make_slot_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.35)
	style.set_corner_radius_all(16)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.10)
	return style

func _build_tooltip() -> void:
	_tooltip = TOOLTIP_SCENE.instantiate()
	add_child(_tooltip)
	# Float in canvas space so its placement does not depend on this node's
	# (dynamically positioned) parent transform settling first.
	_tooltip.top_level = true
	_tooltip.z_index = 50
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false

func _process(_delta: float) -> void:
	_refresh_if_changed()
	_update_layout()
	# Keep the tooltip glued to its slot every frame. This self-corrects the very
	# first reveal (whose rich-text height collapses a frame or two after content
	# is set) and tracks the slot as the board scales.
	if _tooltip_slot >= 0 and _tooltip and _tooltip.visible:
		_tooltip.reset_size()
		_position_tooltip(_tooltip_slot)

func _unhandled_input(event: InputEvent) -> void:
	if not _is_active():
		return
	if event.is_action_pressed("reward_previous"):
		_step_selection(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("reward_next"):
		_step_selection(1)
		get_viewport().set_input_as_handled()

func _is_active() -> bool:
	if _service == null or _service.context == null:
		return false
	if not FallingBlockGameFlags.is_include_rewards(_service.context):
		return false
	return _offer_count() > 0

func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	_refresh()

func _refresh() -> void:
	var active := _is_active()
	visible = active
	if not active:
		_hide_tooltip()
		return
	var offers := _offers()
	var count := mini(DISPLAY_SLOT_COUNT, _offer_count())
	var selected := _selected_index(count)
	for i in range(DISPLAY_SLOT_COUNT):
		var slot := _slot_nodes[i]
		if slot == null:
			continue
		var show := i < count
		slot.visible = show
		if not show:
			continue
		var offer := offers.get_node(i)
		var details := _describe_offer(offer)
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.texture = null
			if not details.icon_path.is_empty():
				icon.texture = load(details.icon_path)
		var check := slot.get_node_or_null("Check") as TextureRect
		if check:
			check.visible = i == selected
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.tooltip_text = ""
	if _tooltip_slot >= 0 and _tooltip_slot < count:
		_show_tooltip_for_slot(_tooltip_slot)
	else:
		_hide_tooltip()

func _update_layout() -> void:
	if _board_renderer == null:
		_board_renderer = get_tree().get_first_node_in_group(
			FallingBlockBoardRenderer.BOARD_RENDERER_GROUP
		) as FallingBlockBoardRenderer
	if _board_renderer == null or not _is_active():
		return
	var w := 10
	var h := 20
	if _board_renderer._grid_state:
		w = _board_renderer._grid_state.width
		h = maxi(1, _board_renderer._grid_state.height - _board_renderer._grid_state.hidden_rows)
	var board_w := float(w * _board_renderer.cell_size)
	var board_h := float(h * _board_renderer.cell_size)
	var count := mini(DISPLAY_SLOT_COUNT, _offer_count())
	var row_w := count * slot_size + maxf(0, count - 1) * slot_gap
	# This node lives inside the board's GridClip, whose local origin (0,0) is the
	# grid's top-left and whose extent matches the playfield, so the grid centre is
	# simply half the board dimensions (no board-origin offset needed).
	var center := Vector2(board_w * 0.5, board_h * 0.5)
	if _slots_root:
		_slots_root.position = Vector2(center.x - row_w * 0.5, center.y - slot_size * 0.5)
		_slots_root.size = Vector2(row_w, slot_size)

func _ephemeral() -> GnosisNode:
	if _service == null or _service.context == null or _service.context.state == null:
		return GnosisNode.new(null)
	return _service.context.state.root.get_node("Ephemeral")

func _read_root_int(key: String, default_value: int) -> int:
	var node := _ephemeral().get_node(key)
	if not node.is_valid() or node.value == null:
		return default_value
	return int(node.value)

func _offer_count() -> int:
	var choice := _read_root_int("rewardChoiceCount", 0)
	if choice > 0:
		return mini(DISPLAY_SLOT_COUNT, choice)
	var offers := _offers()
	if not offers.is_valid() or offers.get_type() != GnosisValueType.LIST:
		return 0
	return mini(DISPLAY_SLOT_COUNT, offers.get_count())

func _offers() -> GnosisNode:
	return _ephemeral().get_node("rewardOffers")

func _selected_index(count: int) -> int:
	if count <= 0:
		return 0
	return clampi(_read_root_int("selectedRewardSlotIndex", 0), 0, count - 1)

func _select_slot(index: int) -> void:
	if _service == null:
		return
	var count := _offer_count()
	if index < 0 or index >= count:
		return
	_service.select_reward_slot(index)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -2.0)
	_last_signature = ""
	_refresh()

func _step_selection(delta: int) -> void:
	var count := _offer_count()
	if count <= 0:
		return
	var next := (_selected_index(count) + delta) % count
	if next < 0:
		next += count
	_select_slot(next)
	_show_tooltip_for_slot(next)

func _on_slot_hovered(index: int) -> void:
	_hovered_index = index
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	_show_tooltip_for_slot(index)

func _on_slot_unhovered() -> void:
	_hovered_index = -1
	_hide_tooltip()

func _show_tooltip_for_slot(index: int) -> void:
	if _tooltip == null or not _is_active():
		return
	var offers := _offers()
	if not offers.is_valid() or index < 0 or index >= offers.get_count():
		return
	_tooltip_slot = index
	var details := _describe_offer(offers.get_node(index))
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	_tooltip.set_content(details.name, details.description)
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
	_tooltip_slot = -1
	if _tooltip:
		_tooltip.disappear()

func _build_signature() -> String:
	if _service == null or _service.context == null:
		return ""
	var parts: Array[String] = []
	parts.append(str(_read_root_int("rewardChoiceCount", 0)))
	parts.append(str(_read_root_int("selectedRewardSlotIndex", 0)))
	var offers := _offers()
	if offers.is_valid() and offers.get_type() == GnosisValueType.LIST:
		for i in range(mini(DISPLAY_SLOT_COUNT, offers.get_count())):
			var offer := offers.get_node(i)
			parts.append("%s:%s" % [_node_str(offer, "type"), _node_str(offer, "itemId")])
	if _board_renderer:
		parts.append(str(_board_renderer.cell_size))
		parts.append(str(_board_renderer.get_board_origin()))
	return "|".join(parts)

func _describe_offer(offer: GnosisNode) -> Dictionary:
	var type_id := _node_str(offer, "type")
	var item_id := _node_str(offer, "itemId")
	var category := _category_for_type(type_id)
	var entry := _catalog_entry(category, item_id)
	var name := item_id.capitalize()
	var desc := type_id.capitalize()
	var sprite_id := ""
	if entry.is_valid():
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
		"icon_path": _icon_path(type_id, category, item_id, sprite_id),
	}

func _icon_path(type_id: String, category: String, item_id: String, sprite_id: String) -> String:
	if category.is_empty():
		return ""
	var folder := "%s%s/" % [ICON_ROOT, category]
	var key := "%s:%s" % [type_id.to_lower(), item_id]
	var candidates: Array[String] = []
	if SPECIAL_ICON_IDS.has(key):
		candidates.append(SPECIAL_ICON_IDS[key])
	if not sprite_id.is_empty():
		candidates.append(sprite_id)
	if sprite_id.begins_with("consumable") and sprite_id.ends_with("Sprite"):
		var base := sprite_id.trim_prefix("consumable").trim_suffix("Sprite")
		candidates.append(base)
		candidates.append(base.capitalize())
	if sprite_id.begins_with("runUpgrade") and sprite_id.ends_with("Sprite"):
		var golden := sprite_id.trim_prefix("runUpgrade").trim_suffix("Sprite")
		candidates.append(golden)
		if golden == "GoldenFalling":
			candidates.append("discardUpgrade")
	candidates.append(item_id)
	candidates.append(item_id.capitalize())
	for candidate in candidates:
		var path := "%s%s.png" % [folder, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""

func _category_for_type(type_id: String) -> String:
	match type_id.strip_edges().to_lower():
		"boon":
			return "boons"
		"consumable":
			return "consumables"
		"ability":
			return "abilities"
		"upgrade":
			return "upgrades"
	return ""

func _catalog_entry(category: String, item_id: String) -> GnosisNode:
	if category.is_empty() or item_id.is_empty() or _service == null or _service.context == null:
		return GnosisNode.new(null)
	var config := _service.context.state.root.get_node("Persistent.configuration")
	if not config.is_valid():
		return GnosisNode.new(null)
	return config.get_node(category).get_node(item_id)

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
