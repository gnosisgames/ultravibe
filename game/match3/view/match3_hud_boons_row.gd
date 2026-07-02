class_name Match3HudBoonsRow
extends PlayHudBoonsBar

## Top-strip boon inventory (centered row). Count label is overlaid; icons fill bar
## height with vertical bleed (negative padding) so squares read large like Unity.

const PANEL_HORIZONTAL_INSET := 16.0
## Icons extend past the strip chrome top/bottom (matches BoonsRow anchor offsets in tscn).
const VERTICAL_BLEED := 10.0
## Slightly under full bleed so icons match Unity strip scale.
const SIZE_FACTOR := 0.9
## Unity GnosisUIElementReorderableItem idle sway defaults.
const SWAY_ANGLE_DEG := 3.5
const SWAY_HALF_CYCLE_SEC := 3.2
const SWAY_ANGLE_VAR := 1.25
const SWAY_TIMING_VAR := 0.4
const DRAG_THRESHOLD := 18.0

var _bar_panel: PanelContainer = null
var _last_layout_slot_size := -1.0
var _pointer_down_index := -1
var _pointer_start := Vector2.ZERO
var _drag_active := false
var _drag_from_index := -1
var _drag_to_index := -1
var _drag_slot: Control = null
var _drag_rest_global_pos := Vector2.ZERO
var _drag_rest_parent: Node = null
var _drag_rest_index := -1
var _float_host: Control = null


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_gap = 14.0
	super._ready()
	resized.connect(_on_slot_layout_dirty)
	call_deferred("_resolve_bar_panel")
	call_deferred("_on_slot_layout_dirty")


func _resolve_bar_panel() -> void:
	var node: Node = get_parent()
	while node:
		if node is PanelContainer:
			_bar_panel = node as PanelContainer
			if not _bar_panel.resized.is_connected(_on_slot_layout_dirty):
				_bar_panel.resized.connect(_on_slot_layout_dirty)
			return
		node = node.get_parent()


func _compute_slot_size() -> float:
	# BoonsRow uses ±VERTICAL_BLEED anchor offsets — row height is the square size.
	var square := size.y
	if square < 8.0 and _bar_panel:
		square = _bar_panel.size.y + VERTICAL_BLEED * 2.0
	if square < 8.0:
		return -1.0
	if _bar_panel:
		var bar_inner_w := maxf(0.0, _bar_panel.size.x - PANEL_HORIZONTAL_INSET)
		var count := maxi(_entries().size(), 1)
		if count > 1 and bar_inner_w >= 8.0:
			var gap := float(slot_gap)
			var max_w := (bar_inner_w - gap * float(count - 1)) / float(count)
			if max_w >= 8.0:
				square = minf(square, max_w)
	return square * SIZE_FACTOR


func _on_slot_layout_dirty() -> void:
	var computed := _compute_slot_size()
	if computed < 8.0 or is_equal_approx(computed, _last_layout_slot_size):
		return
	_last_layout_slot_size = computed
	slot_size = computed
	force_refresh()


func _refresh() -> void:
	var computed := _compute_slot_size()
	if computed >= 8.0:
		slot_size = computed
		_last_layout_slot_size = computed
	super._refresh()


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_CENTER


func _tick_idle_sway() -> void:
	var time_sec := Time.get_ticks_msec() / 1000.0
	for slot in _slot_nodes:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.get_meta(&"sway_paused", false):
			continue
		if slot.size.x > 1.0 and slot.size.y > 1.0:
			slot.pivot_offset = slot.size * 0.5
		var max_angle: float = slot.get_meta(&"sway_max_angle", SWAY_ANGLE_DEG)
		var speed: float = slot.get_meta(&"sway_speed", PI / SWAY_HALF_CYCLE_SEC)
		var offset: float = slot.get_meta(&"sway_time_offset", 0.0)
		slot.rotation_degrees = sin((time_sec + offset) * speed) * max_angle


func _configure_slot_sway(slot: Control, index: int, details: Dictionary) -> void:
	var seed := index * 1315423911
	var item_id: String = str(details.get("name", ""))
	if not item_id.is_empty():
		seed = item_id.hash()
	var angle_scale := 1.0 + SWAY_ANGLE_VAR * (_sway_hash01(seed, 11) * 2.0 - 1.0)
	var timing_scale := 1.0 + SWAY_TIMING_VAR * (_sway_hash01(seed, 23) * 2.0 - 1.0)
	slot.set_meta(&"sway_max_angle", maxf(0.5, SWAY_ANGLE_DEG * angle_scale))
	slot.set_meta(
		&"sway_speed",
		PI / maxf(0.8, SWAY_HALF_CYCLE_SEC * timing_scale),
	)
	slot.set_meta(&"sway_time_offset", _sway_hash01(seed, 37) * TAU)
	slot.set_meta(&"sway_paused", false)


func _sway_hash01(seed: int, salt: int) -> float:
	var h := seed * 397 ^ salt * 0x2D2816FE
	h = (h ^ (h >> 16)) * 0x45D9F3B
	h ^= h >> 16
	return float(h & 0x7FFFFFFF) / float(0x7FFFFFFF)


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	_configure_slot_sway(slot, index, details)
	var w := slot_size
	if w >= 8.0:
		slot.custom_minimum_size = Vector2(w, w + float_offset)
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.set_anchors_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 0.0
			icon.offset_top = 0.0
			icon.offset_right = 0.0
			icon.offset_bottom = 0.0
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.set_anchors_preset(Control.PRESET_FULL_RECT)
			hit.offset_left = 0.0
			hit.offset_top = 0.0
			hit.offset_right = 0.0
			hit.offset_bottom = 0.0
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0
	return slot


func _ensure_float_host() -> Control:
	if _float_host and is_instance_valid(_float_host):
		return _float_host
	var host: Node = _bar_panel if _bar_panel else self
	_float_host = Control.new()
	_float_host.name = "BoonFloatHost"
	_float_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(_float_host)
	return _float_host


func _connect_slot_hit(hit: Button, index: int) -> void:
	hit.gui_input.connect(_on_hit_gui_input.bind(index))


func _on_hit_gui_input(event: InputEvent, index: int) -> void:
	if _is_reorder_blocked():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down_index = index
			_pointer_start = event.global_position
		elif _pointer_down_index == index:
			if _drag_active:
				_finish_drag_reorder()
			_reset_drag_state()
	elif event is InputEventMouseMotion and _pointer_down_index == index and not _drag_active:
		if event.global_position.distance_to(_pointer_start) >= DRAG_THRESHOLD:
			_begin_drag_reorder(index)


func _is_reorder_blocked() -> bool:
	return _drag_active


func _begin_drag_reorder(index: int) -> void:
	if index < 0 or index >= _slot_nodes.size():
		return
	_hide_tooltip()
	_drag_active = true
	_drag_from_index = index
	_drag_to_index = index
	_drag_slot = _slot_nodes[index]
	if _drag_slot == null or not is_instance_valid(_drag_slot):
		_reset_drag_state()
		return
	_drag_rest_parent = _drag_slot.get_parent()
	_drag_rest_index = _drag_slot.get_index()
	_drag_rest_global_pos = _drag_slot.global_position
	var overlay := _ensure_float_host()
	if _drag_rest_parent:
		_drag_rest_parent.remove_child(_drag_slot)
	overlay.add_child(_drag_slot)
	_drag_slot.position = overlay.get_global_transform().affine_inverse() * _drag_rest_global_pos
	_drag_slot.z_index = 220
	_set_slot_sway_paused(_drag_slot, true)


func _process(delta: float) -> void:
	super._process(delta)
	_tick_idle_sway()
	if not _drag_active or _drag_slot == null or not is_instance_valid(_drag_slot):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag_reorder()
		return
	var mouse_pos := get_global_mouse_position()
	var overlay := _ensure_float_host()
	_drag_slot.position = overlay.get_global_transform().affine_inverse() * mouse_pos - _drag_slot.size * 0.5
	_drag_to_index = _drop_index_at_global_x(mouse_pos.x)


func _drop_index_at_global_x(global_x: float) -> int:
	var best_index := _drag_from_index
	var best_distance := INF
	for i in range(_slot_nodes.size()):
		var slot := _slot_nodes[i]
		if slot == null or not is_instance_valid(slot):
			continue
		var rect := slot.get_global_rect()
		var center_x := rect.position.x + rect.size.x * 0.5
		var distance := absf(global_x - center_x)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _finish_drag_reorder() -> void:
	if not _drag_active:
		return
	var from_index := _drag_from_index
	var to_index := _drag_to_index
	_restore_drag_slot_visual()
	_reset_drag_state()
	if from_index >= 0 and to_index >= 0 and from_index != to_index:
		_commit_reorder(from_index, to_index)
	force_refresh()


func _restore_drag_slot_visual() -> void:
	if _drag_slot == null or not is_instance_valid(_drag_slot):
		return
	_set_slot_sway_paused(_drag_slot, false)
	_drag_slot.z_index = 0
	if _drag_rest_parent and is_instance_valid(_drag_rest_parent):
		if _drag_slot.get_parent():
			_drag_slot.get_parent().remove_child(_drag_slot)
		_drag_rest_parent.add_child(_drag_slot)
		var insert_at := clampi(_drag_rest_index, 0, _drag_rest_parent.get_child_count())
		_drag_rest_parent.move_child(_drag_slot, insert_at)


func _reset_drag_state() -> void:
	_drag_active = false
	_pointer_down_index = -1
	_drag_from_index = -1
	_drag_to_index = -1
	_drag_slot = null
	_drag_rest_parent = null
	_drag_rest_index = -1


func _set_slot_sway_paused(slot: Control, paused: bool) -> void:
	if slot:
		slot.set_meta(&"sway_paused", paused)


func _boon_instance_ids_in_display_order() -> Array[String]:
	var ids: Array[String] = []
	var list := _inventory_list()
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return ids
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		var instance_id := _node_str(entry, "instanceId")
		if instance_id.is_empty():
			instance_id = _resolve_item_id(entry)
		if not instance_id.is_empty():
			ids.append(instance_id)
	return ids


func _commit_reorder(from_index: int, to_index: int) -> void:
	if _service == null or _service.context == null or _service.context.store == null:
		return
	var ids := _boon_instance_ids_in_display_order()
	if from_index < 0 or to_index < 0 or from_index >= ids.size() or to_index >= ids.size():
		return
	var moved: String = ids[from_index]
	ids.remove_at(from_index)
	ids.insert(to_index, moved)
	var params := _service.context.store.create_object()
	params.set_key("bucketId", "default")
	var id_list := _service.context.store.create_list()
	for catalog_id in ids:
		id_list.add(catalog_id)
	params.set_node("boonInstanceIds", id_list)
	_service.call_service("Boon", "ReorderBoons", params)
