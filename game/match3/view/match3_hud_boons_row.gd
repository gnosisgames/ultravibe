class_name Match3HudBoonsRow
extends PlayHudBoonsBar

## Top-strip boon inventory (centered row). Count label is overlaid; icons fill bar
## height with vertical bleed (negative padding) so squares read large like Unity.
## Drag/reorder follows JokerPoker card-holder layout (see match3_hud_reorderable_drag.gd).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const JuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")
const ReorderDragScript = preload("res://game/match3/view/match3_hud_reorderable_drag.gd")

const TOOLTIP_Z_INDEX := 4096

const PANEL_HORIZONTAL_INSET := 16.0
const VERTICAL_BLEED := 10.0
const SIZE_FACTOR := 0.9
const SWAY_ANGLE_DEG := 3.5
const SWAY_HALF_CYCLE_SEC := 3.2
const SWAY_ANGLE_VAR := 1.25
const SWAY_TIMING_VAR := 0.4

var _bar_panel: PanelContainer = null
var _last_layout_slot_size := -1.0
var _reorder_drag: RefCounted
var _juice_running := false
var _juice_guard_gen := 0


func _tooltip_prefer_side() -> TooltipPopup.PIVOT_SIDE:
	return TooltipPopup.PIVOT_SIDE.BOTTOM


func _build_tooltip() -> void:
	call_deferred("_finish_build_tooltip")


func _finish_build_tooltip() -> void:
	if _tooltip != null and is_instance_valid(_tooltip):
		return
	var hud := _find_match3_hud()
	if hud == null:
		return
	var layer := hud.get_hud_tooltip_layer()
	if layer == null:
		return
	_tooltip = TOOLTIP_SCENE.instantiate() as TooltipPopup
	if _tooltip == null:
		return
	_tooltip.top_level = false
	_tooltip.z_index = TOOLTIP_Z_INDEX
	_tooltip.scale = Vector2.ZERO
	_tooltip.visible = false
	layer.add_child(_tooltip)


func _find_match3_hud() -> Match3Hud:
	var node: Node = self
	while node:
		if node is Match3Hud:
			return node as Match3Hud
		node = node.get_parent()
	return null


func _show_tooltip_for_slot(index: int) -> void:
	if _tooltip == null or not is_instance_valid(_tooltip):
		_finish_build_tooltip()
	if _tooltip == null:
		return
	super._show_tooltip_for_slot(index)


func _on_slot_unhovered() -> void:
	call_deferred("_hide_tooltip_if_pointer_left")


func _hide_tooltip_if_pointer_left() -> void:
	if _tooltip_index < 0 or _tooltip_index >= _slot_nodes.size():
		_hide_tooltip()
		return
	var slot := _slot_nodes[_tooltip_index]
	if slot != null and is_instance_valid(slot):
		var hit := slot.get_node_or_null("Hit") as Control
		if hit and hit.get_global_rect().has_point(hit.get_global_mouse_position()):
			return
	_hide_tooltip()


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_gap = 14.0
	_reorder_drag = ReorderDragScript.new()
	_reorder_drag.bind(
		self,
		ReorderDragScript.Axis.HORIZONTAL,
		func() -> Array[Control]: return _slot_nodes,
		_resolve_slot_size,
		func() -> CanvasLayer:
			var hud := _find_match3_hud()
			return hud.get_hud_tooltip_layer() if hud else null,
		func() -> Node: return _bar_panel if _bar_panel else self,
		func() -> float: return float(slot_gap),
		func() -> bool: return _is_inventory_reorder_blocked(),
		func() -> bool: return _pointer_owns_strip()
	)
	_reorder_drag.drag_began.connect(_on_reorder_drag_began)
	_reorder_drag.drag_ended.connect(_on_reorder_drag_ended)
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
	if _drag_blocked():
		return
	_relayout_boon_slots()


func _relayout_boon_slots() -> void:
	_relayout_slot_sizes()
	var w := slot_size
	if w < 8.0:
		return
	for slot in _slot_nodes:
		if slot == null or not is_instance_valid(slot):
			continue
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0


func _refresh_if_changed() -> void:
	if _drag_blocked():
		return
	super._refresh_if_changed()


func force_refresh() -> void:
	if _drag_blocked():
		return
	super.force_refresh()


func _refresh() -> void:
	if _drag_blocked():
		return
	var computed := _compute_slot_size()
	if computed >= 8.0:
		slot_size = computed
		_last_layout_slot_size = computed
	super._refresh()


func _should_skip_live_refresh() -> bool:
	return super._should_skip_live_refresh() or _drag_blocked()


func play_scaling_up_juice(slot_index: int, score_kind: String) -> void:
	_begin_juice_guard()
	super.play_scaling_up_juice(slot_index, score_kind)


func play_score_juice(slot_index: int, score_kind: String, display_text: String) -> void:
	_begin_juice_guard()
	super.play_score_juice(slot_index, score_kind, display_text)


func _begin_juice_guard() -> void:
	_juice_running = true
	_juice_guard_gen += 1
	var gen := _juice_guard_gen
	var delay: float = JuiceScript.TRIGGER_JUICE_SEC + 0.08
	get_tree().create_timer(delay).timeout.connect(
		func() -> void:
			if gen != _juice_guard_gen:
				return
			_juice_running = false
			_refresh_if_changed(),
		CONNECT_ONE_SHOT
	)


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
			_rewire_slot_hover(hit, slot)
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0
	return slot


func _connect_slot_hit(hit: Button, _index: int) -> void:
	hit.gui_input.connect(_on_hit_gui_input_for.bind(hit))


func _index_for_slot(slot: Control) -> int:
	if slot == null:
		return -1
	return _slot_nodes.find(slot)


func _on_hit_gui_input_for(event: InputEvent, hit: Button) -> void:
	var slot := hit.get_parent() as Control
	var index := _index_for_slot(slot)
	if index < 0:
		return
	_on_hit_gui_input(event, index)


func _rewire_slot_hover(hit: Button, slot: Control) -> void:
	for conn in hit.mouse_entered.get_connections():
		hit.mouse_entered.disconnect(conn["callable"])
	hit.mouse_entered.connect(func() -> void:
		var idx := _index_for_slot(slot)
		if idx >= 0:
			_on_slot_hovered(idx)
	)


func _on_hit_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _try_sell_at_index(index):
			get_viewport().set_input_as_handled()
		return
	if _is_inventory_reorder_blocked() or _reorder_drag.is_drag_active():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_reorder_drag.handle_press(index, event.global_position)
		elif _reorder_drag.handle_release(index):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		pass


func _pointer_owns_strip() -> bool:
	var rect := _bar_panel.get_global_rect() if _bar_panel else get_global_rect()
	return rect.has_point(get_global_mouse_position())


func _process(delta: float) -> void:
	_reorder_drag.process_idle(delta)
	if _reorder_drag.has_orphan_layout_slots():
		_reorder_drag.finalize_to_row(self)
		_set_all_sway_paused(false)
		_set_slots_interactive(true)
	super._process(delta)
	_tick_idle_sway()


func _on_reorder_drag_began(_slot: Control, _index: int) -> void:
	_hide_tooltip()
	_set_all_sway_paused(true)
	_set_slots_interactive(false)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)


func _on_reorder_drag_ended(from_index: int, to_index: int, changed: bool) -> void:
	_reorder_drag.finalize_to_row(self)
	if changed:
		if _commit_reorder(from_index, to_index):
			_last_signature = _build_signature()
			UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -5.0)
		else:
			force_refresh()
	else:
		_last_signature = "__unset__"
	_set_all_sway_paused(false)
	_set_slots_interactive(true)
	force_refresh()


func _drag_blocked() -> bool:
	return (_reorder_drag != null and _reorder_drag.is_drag_active()) or _is_inventory_reorder_blocked()


func _is_inventory_reorder_blocked() -> bool:
	if _juice_running:
		return true
	var hud := _find_match3_hud()
	if hud != null:
		return hud.is_gameplay_input_locked()
	return false


func _set_all_sway_paused(paused: bool) -> void:
	for slot in _slot_nodes:
		_set_slot_sway_paused(slot, paused)


func _set_slots_interactive(enabled: bool) -> void:
	for slot in _slot_nodes:
		if slot == null or not is_instance_valid(slot):
			continue
		for child in slot.get_children():
			if child is Button:
				child.disabled = not enabled
				child.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func _set_slot_sway_paused(slot: Control, paused: bool) -> void:
	if slot:
		slot.set_meta(&"sway_paused", paused)


func _boon_instance_ids_in_display_order() -> Array[String]:
	var ids: Array[String] = []
	var rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	for row in rows:
		var instance_id := _node_str(row, "instanceId")
		if instance_id.is_empty():
			instance_id = SupportScript.read_boon_catalog_id_from_inventory_entry(row)
		if instance_id.is_empty():
			instance_id = _resolve_item_id(row)
		if not instance_id.is_empty():
			ids.append(instance_id)
	return ids


func _commit_reorder(from_index: int, to_index: int) -> bool:
	if _service == null or _service.context == null or _service.context.store == null:
		return false
	var ids := _boon_instance_ids_in_display_order()
	if from_index < 0 or to_index < 0 or from_index >= ids.size() or to_index >= ids.size():
		return false
	var moved: String = ids[from_index]
	ids.remove_at(from_index)
	ids.insert(to_index, moved)
	var params := _service.context.store.create_object()
	params.set_key("bucketId", "default")
	var id_list := _service.context.store.create_list()
	for instance_id in ids:
		id_list.add(instance_id)
	params.set_node("boonInstanceIds", id_list)
	var result = _service.call_service("Boon", "ReorderBoons", params)
	if not _service_invoke_ok(result):
		return false
	SupportScript.publish_ephemeral_state(_service)
	return true


func _service_invoke_ok(result: Variant) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode:
		return result.is_valid()
	return false
