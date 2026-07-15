class_name Match3HudReorderableDrag
extends RefCounted

## JokerPoker-style manual card-holder layout + drag reorder for HUD icon strips.
## Reference: templates/joker-poker-reference/card_holder.gd + card_hover.gd

enum Axis { HORIZONTAL, VERTICAL }

signal drag_began(slot: Control, index: int)
signal drag_ended(from_index: int, to_index: int, changed: bool)

const HELD_FRAMES_BEFORE_DRAG := 5
const DRAG_PIXEL_THRESHOLD := 28.0
const DRAG_LERP_SPEED := 20.0
const DRAG_SHIFT_SEC := 0.15
const DROP_SEC := 0.3
const DRAG_SCALE := 1.05
const DRAG_ALPHA := 0.75
const DRAG_VISUAL_SEC := 0.2
const DRAG_FLOAT_Z_INDEX := 4090
const DRAG_LIFT_OFFSET := 14.0
const LAYOUT_EDGE_INSET := 8.0
const Z_INDEX_BASE := 2

var owner: Node
var axis: Axis = Axis.HORIZONTAL
var get_slots: Callable
var get_slot_size: Callable
var get_tooltip_layer: Callable
var get_layout_parent: Callable
var get_slot_gap: Callable
var is_blocked: Callable
var can_pointer_drag: Callable

var _pointer_down_index := -1
var _pointer_start := Vector2.ZERO
var _held_frames := 0
var _drag_active := false
var _drag_start_index := -1
var _drag_current_index := -1
var _drag_slot: Control = null
var _drag_grab_offset_global := Vector2.ZERO
var _drag_visual_global := Vector2.ZERO
var _layout_host: Control = null
var _float_host: Control = null
var _slot_layout_tweens: Dictionary = {}
var _drag_finish_tween: Tween = null


func bind(
	p_owner: Node,
	p_axis: Axis,
	p_get_slots: Callable,
	p_get_slot_size: Callable,
	p_get_tooltip_layer: Callable,
	p_get_layout_parent: Callable,
	p_get_slot_gap: Callable,
	p_is_blocked: Callable,
	p_can_pointer_drag: Callable = Callable()
) -> void:
	owner = p_owner
	axis = p_axis
	get_slots = p_get_slots
	get_slot_size = p_get_slot_size
	get_tooltip_layer = p_get_tooltip_layer
	get_layout_parent = p_get_layout_parent
	get_slot_gap = p_get_slot_gap
	is_blocked = p_is_blocked
	can_pointer_drag = p_can_pointer_drag


func is_drag_active() -> bool:
	return _drag_active or _is_finishing_drag()


func _is_finishing_drag() -> bool:
	return _drag_finish_tween != null and is_instance_valid(_drag_finish_tween)


func has_orphan_layout_slots() -> bool:
	if _drag_active or _is_finishing_drag():
		return false
	for slot in _slots():
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.top_level or slot.get_parent() == _float_host or slot.get_parent() == _layout_host:
			return true
	return false


func pointer_down_index() -> int:
	return _pointer_down_index


func handle_press(index: int, global_pos: Vector2) -> void:
	if _drag_active or _callable_true(is_blocked) or not _pointer_drag_allowed():
		return
	_pointer_down_index = index
	_pointer_start = global_pos
	_held_frames = 0
	var slot := _slot_at(index)
	if slot != null:
		_drag_grab_offset_global = global_pos - slot.global_position


func handle_release(index: int) -> bool:
	## Returns true when release ended an active drag (caller should skip click).
	if _pointer_down_index != index:
		return false
	if _drag_active:
		_finish_drag()
		return true
	_pointer_down_index = -1
	_held_frames = 0
	return false


func handle_motion(_index: int, _global_pos: Vector2) -> void:
	# Drag commit is evaluated in process_idle() so hover/tooltips stay alive until
	# the pointer moves far enough while held.
	pass


func cancel_pending() -> void:
	if _drag_active:
		return
	_pointer_down_index = -1
	_held_frames = 0


func ensure_row_layout(row: BoxContainer) -> void:
	if _drag_active or _is_finishing_drag():
		return
	var slots := _slots()
	for slot in slots:
		if slot == null or not is_instance_valid(slot):
			continue
		if slot.top_level or slot.get_parent() == _float_host or slot.get_parent() == _layout_host:
			reparent_slots_to_row(row)
			return


func process_idle(delta: float) -> void:
	if _drag_active:
		process(delta)
		return
	if _pointer_down_index < 0:
		return
	if not _pointer_drag_allowed():
		cancel_pending()
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_pointer_down_index = -1
		_held_frames = 0
		return
	if _callable_true(is_blocked):
		if _pointer_down_index >= 0 and not _drag_active:
			cancel_pending()
		return
	_held_frames += 1
	var dist: float = owner.get_global_mouse_position().distance_to(_pointer_start)
	if dist >= DRAG_PIXEL_THRESHOLD and _held_frames > HELD_FRAMES_BEFORE_DRAG:
		_begin_drag(_pointer_down_index)


func _pointer_drag_allowed() -> bool:
	if not can_pointer_drag.is_valid():
		return true
	return bool(can_pointer_drag.call())


func restore_row_layout_if_needed(row: BoxContainer) -> void:
	ensure_row_layout(row)


func process(delta: float) -> void:
	if _is_finishing_drag():
		return
	if not _drag_active or _drag_slot == null or not is_instance_valid(_drag_slot):
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_finish_drag()
		return
	var target_global: Vector2 = owner.get_global_mouse_position() - _drag_grab_offset_global
	if axis == Axis.HORIZONTAL:
		target_global.y -= DRAG_LIFT_OFFSET
	else:
		target_global.x -= DRAG_LIFT_OFFSET
	_drag_visual_global = _drag_visual_global.lerp(target_global, DRAG_LERP_SPEED * delta)
	_drag_slot.global_position = _drag_visual_global
	_try_reorder_from_drag_position()


func organize_slots(animated: bool = false, duration: float = DRAG_SHIFT_SEC, skip_index: int = -1) -> void:
	var slots := _slots()
	if slots.is_empty():
		return
	_ensure_layout_host()
	for i in range(slots.size()):
		var slot: Control = slots[i]
		if slot == null or not is_instance_valid(slot):
			continue
		if i == skip_index:
			continue
		if slot.get_parent() != _layout_host:
			_reparent_slot_preserve_global(slot, _layout_host)
		var target_pos := _layout_slot_position(i, slot)
		_kill_slot_layout_tween(slot)
		slot.z_index = Z_INDEX_BASE + i
		if animated and duration > 0.0:
			var tw := owner.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_property(slot, "position", target_pos, duration) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_slot_layout_tweens[slot] = tw
		else:
			slot.position = target_pos


func reset() -> void:
	_kill_drag_finish_tween()
	_kill_slot_layout_tweens()
	_drag_active = false
	_pointer_down_index = -1
	_held_frames = 0
	_drag_start_index = -1
	_drag_current_index = -1
	_drag_slot = null
	_drag_grab_offset_global = Vector2.ZERO


func finalize_to_row(row: BoxContainer) -> void:
	_kill_drag_finish_tween()
	_kill_slot_layout_tweens()
	reparent_slots_to_row(row)


func reparent_slots_to_row(row: BoxContainer) -> void:
	var slots := _slots()
	for i in range(slots.size()):
		var slot: Control = slots[i]
		if slot == null or not is_instance_valid(slot):
			continue
		slot.top_level = false
		slot.z_index = 0
		slot.scale = Vector2.ONE
		slot.modulate = Color.WHITE
		if slot.get_parent() != row:
			if slot.get_parent():
				slot.get_parent().remove_child(slot)
			row.add_child(slot)
		row.move_child(slot, i)
		slot.position = Vector2.ZERO


func _begin_drag(index: int) -> void:
	var slots := _slots()
	if index < 0 or index >= slots.size():
		return
	_kill_drag_finish_tween()
	_kill_slot_layout_tweens()
	_drag_active = true
	_drag_start_index = index
	_drag_current_index = index
	_drag_slot = slots[index]
	if _drag_slot == null or not is_instance_valid(_drag_slot):
		reset()
		return
	var resolved := slots.find(_drag_slot)
	if resolved >= 0 and resolved != _drag_current_index:
		_drag_start_index = resolved
		_drag_current_index = resolved
	_ensure_layout_host()
	for slot in slots:
		if slot == null or not is_instance_valid(slot):
			continue
		_reparent_slot_preserve_global(slot, _layout_host)
	organize_slots(false, 0.0, _drag_current_index)
	_drag_visual_global = _drag_slot.global_position
	_lift_drag_slot_to_float_host(_drag_visual_global)
	_tween_drag_visual(_drag_slot, true)
	drag_began.emit(_drag_slot, index)


func _finish_drag() -> void:
	if not _drag_active or _is_finishing_drag():
		return
	var from_index := _drag_start_index
	var to_index := _drag_current_index
	var changed := from_index >= 0 and to_index >= 0 and from_index != to_index
	_drag_active = false
	_kill_slot_layout_tweens()
	if _drag_slot and is_instance_valid(_drag_slot):
		var target_local := _layout_slot_position(to_index, _drag_slot)
		var target_global: Vector2 = _layout_local_to_global(target_local)
		if axis == Axis.HORIZONTAL:
			target_global.y -= DRAG_LIFT_OFFSET
		else:
			target_global.x -= DRAG_LIFT_OFFSET
		_drag_finish_tween = owner.create_tween()
		_drag_finish_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_drag_finish_tween.set_parallel(true)
		organize_slots(true, DROP_SEC, to_index)
		_drag_finish_tween.tween_property(_drag_slot, "global_position", target_global, DROP_SEC) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tween_drag_visual_on_tween(_drag_finish_tween, _drag_slot, false)
		_drag_finish_tween.finished.connect(
			func() -> void:
				_complete_drop(from_index, to_index, changed),
			CONNECT_ONE_SHOT
		)
	else:
		_complete_drop(from_index, to_index, changed)


func _complete_drop(from_index: int, to_index: int, changed: bool) -> void:
	_drag_finish_tween = null
	if _drag_slot and is_instance_valid(_drag_slot):
		_drag_slot.top_level = false
		_drag_slot.z_index = 0
		_drag_slot.scale = Vector2.ONE
		_drag_slot.modulate = Color.WHITE
	drag_ended.emit(from_index, to_index, changed)
	reset()


func _try_reorder_from_drag_position() -> void:
	if _layout_host == null or _drag_slot == null:
		return
	var local_pos := _layout_host.get_global_transform().affine_inverse() * _drag_visual_global
	var axis_pos := local_pos.x if axis == Axis.HORIZONTAL else local_pos.y
	var target_index := _slot_index_at_axis(axis_pos)
	if target_index < 0:
		return
	target_index = clampi(target_index, _drag_current_index - 1, _drag_current_index + 1)
	if target_index != _drag_current_index:
		_move_slot_to_index(target_index)


func _slot_index_at_axis(axis_pos: float) -> int:
	var slots := _slots()
	var count := slots.size()
	if count <= 0:
		return -1
	var metrics := _layout_metrics()
	var start_main: float = metrics.start_main
	var step: float = metrics.step
	for i in range(count):
		var center: float = start_main + step * float(i)
		var half: float = metrics.child_size * 0.5
		if axis_pos >= center - half and axis_pos <= center + half:
			return i
	var nearest := 0
	var best_distance := INF
	for i in range(count):
		var center: float = start_main + step * float(i)
		var distance := absf(axis_pos - center)
		if distance < best_distance:
			best_distance = distance
			nearest = i
	return nearest


func _move_slot_to_index(to_index: int) -> void:
	var slots := _slots()
	var from_index := _drag_current_index
	if from_index < 0 or to_index < 0 or from_index >= slots.size() or to_index >= slots.size():
		return
	if from_index == to_index:
		return
	# Only swap with direct neighbors so slot identity stays predictable.
	if absi(to_index - from_index) != 1:
		return
	var moved: Control = slots[from_index]
	slots.remove_at(from_index)
	slots.insert(to_index, moved)
	_drag_current_index = to_index
	if _drag_slot != moved:
		_drag_slot = moved
	organize_slots(true, DRAG_SHIFT_SEC, _drag_current_index)


func _layout_metrics() -> Dictionary:
	var slots := _slots()
	var count := slots.size()
	var child_size := _resolve_slot_size()
	if child_size < 8.0:
		child_size = 64.0
	var spacing := _resolve_slot_gap()
	var host := _layout_host if _layout_host and is_instance_valid(_layout_host) else null
	var host_span := 0.0
	if host:
		host_span = host.size.x if axis == Axis.HORIZONTAL else host.size.y
	if host_span < 8.0 and owner is Control:
		host_span = (owner as Control).size.x if axis == Axis.HORIZONTAL else (owner as Control).size.y
	var total: float = child_size * float(count) + spacing * float(maxi(0, count - 1))
	var start_main: float = (host_span - total) * 0.5 + child_size * 0.5
	var step: float = child_size + spacing
	return {
		"count": count,
		"child_size": child_size,
		"spacing": spacing,
		"host": host,
		"host_span": host_span,
		"start_main": start_main,
		"step": step,
	}


func _layout_slot_position(index: int, slot: Control) -> Vector2:
	var metrics := _layout_metrics()
	var center_main: float = metrics.start_main + metrics.step * float(index)
	var host: Control = metrics.host
	var host_cross := host.size.y if axis == Axis.HORIZONTAL else host.size.x
	if host_cross < 8.0 and owner is Control:
		host_cross = (owner as Control).size.y if axis == Axis.HORIZONTAL else (owner as Control).size.x
	var child_main: float = metrics.child_size
	var child_cross := slot.size.y if axis == Axis.HORIZONTAL else slot.size.x
	if child_cross < 1.0:
		child_cross = child_main
	var main_pos: float = center_main - child_main * 0.5
	var cross_pos := maxf(0.0, (host_cross - child_cross) * 0.5)
	if axis == Axis.HORIZONTAL:
		return Vector2(main_pos, cross_pos)
	return Vector2(cross_pos, main_pos)


func _layout_local_to_global(local_pos: Vector2) -> Vector2:
	if _layout_host == null:
		return local_pos
	return _layout_host.get_global_transform() * local_pos


func _ensure_layout_host() -> Control:
	if _layout_host and is_instance_valid(_layout_host):
		return _layout_host
	var parent: Node = get_layout_parent.call() if get_layout_parent.is_valid() else owner
	_layout_host = Control.new()
	_layout_host.name = "ReorderLayoutHost"
	_layout_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_layout_host)
	return _layout_host


func _ensure_float_host() -> Control:
	if _float_host and is_instance_valid(_float_host):
		return _float_host
	var layer: CanvasLayer = null
	if get_tooltip_layer.is_valid():
		layer = get_tooltip_layer.call()
	if layer == null:
		return _ensure_layout_host()
	_float_host = Control.new()
	_float_host.name = "ReorderFloatHost"
	_float_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_float_host)
	return _float_host


func _lift_drag_slot_to_float_host(slot_global: Vector2) -> void:
	if _drag_slot == null:
		return
	var float_host := _ensure_float_host()
	if _drag_slot.get_parent():
		_drag_slot.get_parent().remove_child(_drag_slot)
	float_host.add_child(_drag_slot)
	_drag_slot.top_level = true
	_drag_slot.z_index = DRAG_FLOAT_Z_INDEX
	_drag_slot.global_position = slot_global
	_drag_visual_global = slot_global


func _reparent_slot_preserve_global(slot: Control, parent: Control) -> void:
	var global_pos := slot.global_position
	if slot.get_parent() != parent:
		if slot.get_parent():
			slot.get_parent().remove_child(slot)
		parent.add_child(slot)
	slot.position = parent.get_global_transform().affine_inverse() * global_pos


func _tween_drag_visual(slot: Control, dragging: bool) -> void:
	if slot == null or not is_instance_valid(slot):
		return
	var tw := owner.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	_tween_drag_visual_on_tween(tw, slot, dragging)


func _tween_drag_visual_on_tween(tw: Tween, slot: Control, dragging: bool) -> void:
	var target_scale := Vector2(DRAG_SCALE, DRAG_SCALE) if dragging else Vector2.ONE
	var target_alpha := DRAG_ALPHA if dragging else 1.0
	tw.tween_property(slot, "scale", target_scale, DRAG_VISUAL_SEC) \
		.set_trans(Tween.TRANS_BACK if dragging else Tween.TRANS_QUAD) \
		.set_ease(Tween.EASE_OUT)
	var modulate: Color = slot.modulate
	tw.tween_property(slot, "modulate", Color(modulate.r, modulate.g, modulate.b, target_alpha), DRAG_VISUAL_SEC) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _kill_slot_layout_tween(slot: Control) -> void:
	if slot == null:
		return
	if _slot_layout_tweens.has(slot):
		var tw: Tween = _slot_layout_tweens[slot]
		if tw and is_instance_valid(tw):
			tw.kill()
		_slot_layout_tweens.erase(slot)


func _kill_slot_layout_tweens() -> void:
	for slot in _slot_layout_tweens.keys():
		_kill_slot_layout_tween(slot)
	_slot_layout_tweens.clear()


func _kill_drag_finish_tween() -> void:
	if _drag_finish_tween and is_instance_valid(_drag_finish_tween):
		_drag_finish_tween.kill()
	_drag_finish_tween = null


func _slots() -> Array[Control]:
	if get_slots.is_valid():
		return get_slots.call()
	return []


func _slot_at(index: int) -> Control:
	var slots := _slots()
	if index < 0 or index >= slots.size():
		return null
	return slots[index]


func _resolve_slot_size() -> float:
	if get_slot_size.is_valid():
		return float(get_slot_size.call())
	return 64.0


func _resolve_slot_gap() -> float:
	if get_slot_gap.is_valid():
		return maxf(0.0, float(get_slot_gap.call()))
	return 14.0


func _callable_true(callable_fn: Callable) -> bool:
	if not callable_fn.is_valid():
		return false
	return bool(callable_fn.call())
