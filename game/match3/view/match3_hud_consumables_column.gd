class_name Match3HudConsumablesColumn
extends PlayHudConsumablesBar

## Right-sidebar consumables: Unity parity — full-opacity icons, click to use,
## controller cycles a hidden slot index then fires Consumable / right-click.

const JuiceScript := preload("res://game/match3/view/match3_consumable_use_juice.gd")
const ConsumableDbgScript := preload("res://game/match3/debug/match3_consumable_debug.gd")
const ReorderDragScript = preload("res://game/match3/view/match3_hud_reorderable_drag.gd")
const TOOLTIP_Z_INDEX := 4096
## ConsumablesBar panel style uses 24px horizontal content margins on each side.
const PANEL_HORIZONTAL_INSET := 48.0

var _defer_inventory_refresh := false
var _juice_running := false
var _bar_panel: PanelContainer = null
var _last_layout_slot_size := -1.0
var _reorder_drag: RefCounted
var _float_host: Control = null
var _controller_cycle_armed := true


func _tooltip_prefer_side() -> TooltipPopup.PIVOT_SIDE:
	return TooltipPopup.PIVOT_SIDE.LEFT


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


func _ready() -> void:
	float_offset = 0.0
	slot_gap = 14.0
	clip_contents = false
	_reorder_drag = ReorderDragScript.new()
	_reorder_drag.bind(
		self,
		ReorderDragScript.Axis.VERTICAL,
		func() -> Array[Control]: return _slot_nodes,
		_resolve_slot_size,
		func() -> CanvasLayer:
			var hud := _find_match3_hud()
			return hud.get_hud_tooltip_layer() if hud else null,
		func() -> Node: return _bar_panel if _bar_panel else self,
		func() -> float: return float(slot_gap),
		func() -> bool: return _reorder_idle_blocked(),
		func() -> bool: return _pointer_owns_strip()
	)
	_reorder_drag.drag_began.connect(_on_reorder_drag_began)
	_reorder_drag.drag_ended.connect(_on_reorder_drag_ended)
	super._ready()
	resized.connect(_on_slot_layout_dirty)
	call_deferred("_resolve_bar_panel")
	call_deferred("_on_slot_layout_dirty")


func _resolve_bar_panel() -> void:
	var layout := get_parent()
	if layout and layout.get_parent() is PanelContainer:
		_bar_panel = layout.get_parent() as PanelContainer
		if not _bar_panel.resized.is_connected(_on_slot_layout_dirty):
			_bar_panel.resized.connect(_on_slot_layout_dirty)
		_ensure_float_host()


func _ensure_float_host() -> Control:
	if _float_host and is_instance_valid(_float_host):
		return _float_host
	var hud := _find_match3_hud()
	var layer: CanvasLayer = hud.get_hud_tooltip_layer() if hud else null
	if layer:
		_float_host = Control.new()
		_float_host.name = "ConsumableFloatHost"
		_float_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_float_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_float_host)
		return _float_host
	var host: Node = _bar_panel if _bar_panel else self
	_float_host = Control.new()
	_float_host.name = "ConsumableFloatHost"
	_float_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host.add_child(_float_host)
	return _float_host


func _float_local_pos(global_pos: Vector2) -> Vector2:
	var overlay := _ensure_float_host()
	return overlay.get_global_transform().affine_inverse() * global_pos


func _compute_slot_size() -> float:
	var width := size.x
	if width < 8.0:
		var layout := get_parent() as Control
		if layout and layout.size.x > 8.0:
			width = layout.size.x
		elif _bar_panel:
			width = maxf(0.0, _bar_panel.size.x - PANEL_HORIZONTAL_INSET)
	if width < 8.0:
		return -1.0
	var count := maxi(_entries().size(), 1)
	var available_h := size.y
	if available_h < 8.0:
		var layout := get_parent() as Control
		if layout and layout.size.y > 8.0:
			available_h = layout.size.y
	if available_h >= 8.0:
		var gap := float(slot_gap)
		var by_height := (available_h - gap * float(count - 1)) / float(count)
		if by_height >= 8.0:
			return minf(width, by_height)
	return width


func _on_slot_layout_dirty() -> void:
	var computed := _compute_slot_size()
	if computed < 8.0 or is_equal_approx(computed, _last_layout_slot_size):
		return
	_last_layout_slot_size = computed
	slot_size = computed
	if not _reorder_drag.is_drag_active() and not _juice_running:
		force_refresh()


func _refresh() -> void:
	if _juice_running or _defer_inventory_refresh or _reorder_drag.is_drag_active():
		ConsumableDbgScript.fatal(
			"Column._refresh",
			"BLOCKED direct slot rebuild during protected state juice=%s defer=%s drag=%s" % [
				_juice_running, _defer_inventory_refresh, _reorder_drag.is_drag_active()
			]
		)
		return
	ConsumableDbgScript.phase("Column._refresh", "rebuilding %d slots" % _slot_nodes.size(), _service, self)
	_cleanup_orphan_slots()
	var computed := _compute_slot_size()
	if computed >= 8.0:
		slot_size = computed
		_last_layout_slot_size = computed
	super._refresh()


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	var w := slot_size
	if w >= 8.0:
		slot.custom_minimum_size = Vector2(w, w)
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon:
			icon.offset_bottom = w
		var hit := slot.get_node_or_null("Hit") as Button
		if hit:
			hit.offset_bottom = w
			_rewire_slot_hover(hit, slot)
		var badge := slot.get_node_or_null("Count") as Label
		if badge:
			badge.offset_left = w - 28.0
			badge.offset_top = w - 20.0
			badge.offset_right = w + 2.0
			badge.offset_bottom = w + 2.0
	return slot


func _cleanup_orphan_slots() -> void:
	_clear_float_host()
	var hosts: Array[Node] = [self]
	if _bar_panel:
		hosts.append(_bar_panel)
	for host in hosts:
		if host == null:
			continue
		for child in host.get_children():
			if child == _tooltip or child == _float_host:
				continue
			if child is Control and str(child.name).begins_with("Slot"):
				if _is_protected_floating_slot(child as Control):
					continue
				if host != self or child not in _slot_nodes:
					child.queue_free()


func _is_protected_floating_slot(slot: Control) -> bool:
	if slot == null or not is_instance_valid(slot):
		return false
	if slot.has_meta(&"juice_rest_parent"):
		return true
	if slot.top_level:
		return true
	if _float_host and is_instance_valid(_float_host) and slot.get_parent() == _float_host:
		return true
	var parent := slot.get_parent()
	if parent and str(parent.name) == "ReorderLayoutHost":
		return true
	return slot.z_index >= 200


func _clear_float_host() -> void:
	if _float_host and is_instance_valid(_float_host):
		for child in _float_host.get_children():
			if not is_instance_valid(child):
				continue
			if str(child.name).begins_with("Slot"):
				if _is_protected_floating_slot(child as Control):
					continue
				child.queue_free()


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


func _on_hit_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _try_sell_at_index(index):
			get_viewport().set_input_as_handled()
		return
	if _is_reorder_blocked() and not _reorder_drag.is_drag_active():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_reorder_drag.handle_press(index, event.global_position)
		else:
			var pending_click: bool = _reorder_drag.pointer_down_index() == index
			if _reorder_drag.handle_release(index):
				get_viewport().set_input_as_handled()
			elif pending_click:
				_on_slot_pressed(index)


func _reorder_idle_blocked() -> bool:
	if _juice_running or _defer_inventory_refresh:
		return true
	if _service and _service.has_method("is_consumable_use_presentation_active"):
		return _service.is_consumable_use_presentation_active()
	var hud := _find_match3_hud()
	if hud != null and hud.is_gameplay_input_locked():
		return true
	return false


func _is_reorder_blocked() -> bool:
	return _reorder_idle_blocked() or _reorder_drag.is_drag_active()


func _process(delta: float) -> void:
	_reorder_drag.process_idle(delta)
	if _reorder_drag.has_orphan_layout_slots():
		_reorder_drag.finalize_to_row(self)
		_set_slots_interactive(true)
	if _reorder_drag.is_drag_active():
		return
	if _gamepad_owns_strip():
		_poll_consumable_controller_input()
		return
	super._process(delta)


func _on_reorder_drag_began(_slot: Control, _index: int) -> void:
	_hide_tooltip()
	_set_slots_interactive(false)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)


func _on_reorder_drag_ended(from_index: int, to_index: int, changed: bool) -> void:
	_reorder_drag.finalize_to_row(self)
	if changed:
		_commit_reorder(from_index, to_index)
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -5.0)
	_set_slots_interactive(true)
	_last_signature = "__unset__"
	force_refresh()


func _rewire_slot_hover(hit: Button, slot: Control) -> void:
	for conn in hit.mouse_entered.get_connections():
		hit.mouse_entered.disconnect(conn["callable"])
	hit.mouse_entered.connect(func() -> void:
		var idx := _index_for_slot(slot)
		if idx >= 0:
			_on_slot_hovered(idx)
	)


func _pointer_owns_strip() -> bool:
	var rect := _bar_panel.get_global_rect() if _bar_panel else get_global_rect()
	return rect.has_point(get_global_mouse_position())


func _gamepad_owns_strip() -> bool:
	if Input.get_connected_joypads().is_empty():
		return false
	return not _pointer_owns_strip()


func _consumable_ids_in_display_order() -> Array[String]:
	var ids: Array[String] = []
	var list := _inventory_list()
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return ids
	for i in range(list.get_count()):
		ids.append(_resolve_item_id(list.get_node(i)))
	return ids


func _commit_reorder(from_index: int, to_index: int) -> void:
	if _service == null or _service.context == null or _service.context.store == null:
		return
	var ids := _consumable_ids_in_display_order()
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
	params.set_node("consumableIds", id_list)
	var result = _service.call_service("Consumable", "ReorderConsumables", params)
	if _service_invoke_ok(result):
		_remap_selected_slot_after_reorder(from_index, to_index)


func _remap_selected_slot_after_reorder(from_index: int, to_index: int) -> void:
	if _service == null or not _service.has_method("get_selected_consumable_slot"):
		return
	var selected: int = _service.get_selected_consumable_slot()
	if selected == from_index:
		_service.select_consumable_slot(to_index)
	elif from_index < selected and to_index >= selected:
		_service.select_consumable_slot(selected - 1)
	elif from_index > selected and to_index <= selected:
		_service.select_consumable_slot(selected + 1)


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_CENTER


func _slot_alpha(index: int, details: Dictionary) -> float:
	if _reorder_drag != null and _reorder_drag.is_drag_active():
		return 1.0
	if _gamepad_owns_strip():
		return super._slot_alpha(index, details)
	return 1.0


func _extra_signature_parts() -> Array[String]:
	if _reorder_drag != null and _reorder_drag.is_drag_active():
		return []
	return super._extra_signature_parts()


func _refresh_if_changed() -> void:
	var signature := _build_signature()
	if signature == _last_signature:
		return
	if _reorder_drag.is_drag_active() or _juice_running or _defer_inventory_refresh:
		return
	ConsumableDbgScript.phase(
		"Column._refresh_if_changed",
		"REBUILD slots sig=%s -> %s (destroying %d nodes)" % [
			_last_signature.substr(0, 40),
			signature.substr(0, 40),
			_slot_nodes.size()
		],
		_service,
		self
	)
	_last_signature = signature
	_refresh()


func _should_defer_inventory_refresh() -> bool:
	return _defer_inventory_refresh or _juice_running or _reorder_drag.is_drag_active()


func force_refresh() -> void:
	if _juice_running or _defer_inventory_refresh or _reorder_drag.is_drag_active():
		ConsumableDbgScript.fatal(
			"Column.force_refresh",
			"BLOCKED during protected state juice=%s defer=%s drag=%s" % [
				_juice_running, _defer_inventory_refresh, _reorder_drag.is_drag_active()
			]
		)
		return
	ConsumableDbgScript.phase("Column.force_refresh", "destroying %d slots via direct _refresh" % _slot_nodes.size(), _service, self)
	super.force_refresh()


func _on_slot_pressed(index: int) -> void:
	ConsumableDbgScript.phase("Column._on_slot_pressed", "index=%d" % index, _service, self)
	if _reorder_drag.is_drag_active():
		ConsumableDbgScript.warn("Column._on_slot_pressed", "ignored: drag_active")
		return
	if _juice_running or _should_defer_inventory_refresh():
		ConsumableDbgScript.warn("Column._on_slot_pressed", "ignored: juice=%s defer=%s" % [_juice_running, _defer_inventory_refresh])
		return
	var entries := _entries()
	if index < 0 or index >= entries.size():
		return
	_use_slot_at_index(index)


func _use_slot_at_index(index: int) -> void:
	ConsumableDbgScript.phase("Column._use_slot_at_index", "enter index=%d slots=%d" % [index, _slot_nodes.size()], _service, self)
	if index < 0 or index >= _slot_nodes.size():
		ConsumableDbgScript.warn("Column._use_slot_at_index", "bad index=%d slot_count=%d" % [index, _slot_nodes.size()])
		return
	if _service == null or not _service.has_method("try_consume_consumable_at_slot_presentation"):
		ConsumableDbgScript.fatal("Column._use_slot_at_index", "service missing try_consume")
		return
	var entries := _entries()
	var consumable_id := str(entries[index].get("id", "")) if index < entries.size() else "?"
	var use_id := ConsumableDbgScript.begin_use(consumable_id, index, {
		"entries": entries.size(),
		"grid_ready": _service._is_board_grid_ready() if _service.has_method("_is_board_grid_ready") else "?",
	})
	_hide_tooltip()
	_juice_running = true
	_defer_inventory_refresh = true
	ConsumableDbgScript.phase("Column._use_slot_at_index", "flags set juice+defer BEFORE consume", _service, self)
	_set_slots_interactive(false)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -1.0)
	if _bar_panel:
		JuiceScript.pulse_bar(_bar_panel)
	var slot := _slot_nodes[index]
	ConsumableDbgScript.phase("Column._use_slot_at_index", "before try_consume %s" % ConsumableDbgScript.slot_snapshot(slot), _service, self)
	var consumed: bool = bool(_service.try_consume_consumable_at_slot_presentation(index))
	ConsumableDbgScript.phase("Column._use_slot_at_index", "after try_consume consumed=%s slot=%s" % [
		consumed,
		ConsumableDbgScript.slot_snapshot(slot)
	], _service, self)
	if not consumed:
		_juice_running = false
		_defer_inventory_refresh = false
		ConsumableDbgScript.end_use("consume_failed")
		_finish_consumable_use_presentation()
		return
	if not is_instance_valid(slot):
		ConsumableDbgScript.fatal("Column._use_slot_at_index", "slot invalid immediately after successful consume")
		_juice_running = false
		_defer_inventory_refresh = false
		ConsumableDbgScript.end_use("slot_freed_after_consume")
		_finish_consumable_use_presentation()
		return
	_reparent_slot_for_juice(slot)
	ConsumableDbgScript.phase("Column._use_slot_at_index", "reparented for juice %s" % ConsumableDbgScript.slot_snapshot(slot), _service, self)
	await _run_consumable_juice(slot)


func _run_consumable_juice(slot: Control) -> void:
	ConsumableDbgScript.phase("Column._run_consumable_juice", "start %s" % ConsumableDbgScript.slot_snapshot(slot), _service, self)
	var use_text := JuiceScript.DISPLAY_USE
	if _service and _service.has_method("get_consumable_use_display_text"):
		use_text = str(_service.get_consumable_use_display_text())
	if slot != null and is_instance_valid(slot):
		await JuiceScript.run_two_phase(self, slot, use_text, _service)
	else:
		ConsumableDbgScript.fatal("Column._run_consumable_juice", "slot invalid before juice phases")
	_finish_consumable_use_presentation()


func _finish_consumable_use_presentation() -> void:
	ConsumableDbgScript.phase("Column._finish", "enter juice=%s defer=%s" % [_juice_running, _defer_inventory_refresh], _service, self)
	_juice_running = false
	_defer_inventory_refresh = false
	_set_slots_interactive(true)
	_prune_invalid_slot_nodes()
	_cleanup_orphan_slots()
	if _service and _service.has_method("complete_consumable_use_presentation_hud_step"):
		ConsumableDbgScript.phase("Column._finish", "calling complete_consumable_use_presentation_hud_step", _service, self)
		_service.complete_consumable_use_presentation_hud_step()
	_refresh_parent_hud()
	_last_signature = "__unset__"
	ConsumableDbgScript.phase("Column._finish", "calling force_refresh", _service, self)
	force_refresh()
	ConsumableDbgScript.end_use("finished")


func _prune_invalid_slot_nodes() -> void:
	var kept: Array[Control] = []
	for slot in _slot_nodes:
		if slot != null and is_instance_valid(slot):
			kept.append(slot)
	_slot_nodes = kept


func _service_invoke_ok(result: Variant) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode:
		return result.is_valid()
	return false


func _refresh_parent_hud() -> void:
	super._refresh_parent_hud()


func _reparent_slot_for_juice(slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		ConsumableDbgScript.warn("Column._reparent_slot_for_juice", "slot invalid")
		return
	slot.set_meta("juice_rest_parent", slot.get_parent())
	slot.set_meta("juice_rest_index", slot.get_index())
	slot.set_meta("juice_rest_global_pos", slot.global_position)
	var overlay := _ensure_float_host()
	if slot.get_parent():
		slot.get_parent().remove_child(slot)
	overlay.add_child(slot)
	slot.top_level = true
	slot.z_index = ReorderDragScript.DRAG_FLOAT_Z_INDEX
	slot.global_position = slot.get_meta("juice_rest_global_pos")


func _restore_floating_slot(slot: Control) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	slot.top_level = false
	slot.z_index = 0
	slot.modulate = Color.WHITE
	slot.scale = Vector2.ONE
	slot.rotation = 0.0
	var parent = slot.get_meta("juice_rest_parent", null)
	var rest_index: int = int(slot.get_meta("juice_rest_index", 0))
	var rest_pos: Vector2 = slot.get_meta("juice_rest_global_pos", slot.global_position)
	if parent and is_instance_valid(parent):
		if slot.get_parent():
			slot.get_parent().remove_child(slot)
		parent.add_child(slot)
		var target := clampi(rest_index, 0, maxi(0, parent.get_child_count() - 1))
		parent.move_child(slot, target)
		slot.position = parent.get_global_transform().affine_inverse() * rest_pos
	slot.remove_meta("juice_rest_parent")
	slot.remove_meta("juice_rest_index")
	slot.remove_meta("juice_rest_global_pos")


func _set_slots_interactive(enabled: bool) -> void:
	for slot in _slot_nodes:
		if not is_instance_valid(slot):
			continue
		for child in slot.get_children():
			if child is Button:
				child.disabled = not enabled
				child.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func bind_service(service: GnosisService) -> void:
	_cleanup_orphan_slots()
	super.bind_service(service)
	call_deferred("_on_slot_layout_dirty")


func _on_slot_hovered(index: int) -> void:
	if _gamepad_owns_strip():
		return
	super._on_slot_hovered(index)


func _on_slot_unhovered() -> void:
	if _gamepad_owns_strip():
		return
	super._on_slot_unhovered()


func _position_tooltip(index: int) -> void:
	if _tooltip == null or index < 0 or index >= _slot_nodes.size():
		return
	var slot := _slot_nodes[index]
	if slot == null or not is_instance_valid(slot):
		return
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.reset_size()
	TooltipPopup.position_at_anchor(_tooltip, slot, TooltipPopup.PIVOT_SIDE.LEFT, 14.0)


func _poll_consumable_controller_input() -> void:
	if not _gamepad_owns_strip() or not _consumable_input_allowed():
		return
	if Input.is_action_just_pressed("Consumable"):
		_use_slot_at_index(_target_consumable_index())
		return
	_poll_consumable_selection_axis()


func _consumable_input_allowed() -> bool:
	if _juice_running or _reorder_drag.is_drag_active() or _defer_inventory_refresh:
		return false
	if _service and _service.has_method("is_consumable_use_presentation_active"):
		if _service.is_consumable_use_presentation_active():
			return false
	return true


func _target_consumable_index() -> int:
	if _service and _service.has_method("get_selected_consumable_slot"):
		return _service.get_selected_consumable_slot()
	return 0


func _poll_consumable_selection_axis() -> void:
	if _service == null or not _service.has_method("select_consumable_slot"):
		return
	var vy := _read_secondary_vertical_axis()
	if absf(vy) < 0.55:
		_controller_cycle_armed = true
		return
	if not _controller_cycle_armed:
		return
	_controller_cycle_armed = false
	var count := _entries().size()
	if count <= 0:
		return
	var selected: int = _service.get_selected_consumable_slot()
	var delta := -1 if vy > 0.0 else 1
	var next: int = (selected + delta + count) % count
	if next == selected:
		return
	_reorder_drag.cancel_pending()
	_reorder_drag.ensure_row_layout(self)
	_service.select_consumable_slot(next)
	force_refresh()
	call_deferred("_show_tooltip_for_slot", next)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -8.0)


func _read_secondary_vertical_axis() -> float:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return 0.0
	return Input.get_joy_axis(int(pads[0]), JOY_AXIS_RIGHT_Y)
