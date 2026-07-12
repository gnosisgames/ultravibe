class_name Match3BoardGamepad
extends RefCounted

## Gamepad board focus navigation and select-then-swap (Unity Match3Dispatcher.Gamepad parity).

const GameInputActions = preload("res://game/input/game_input_actions.gd")

const AXIS_THRESHOLD := 0.55
const AXIS_REPEAT_DELAY := 0.22
const AXIS_REPEAT_INTERVAL := 0.22
const STARTUP_SELECT_COOLDOWN := 0.45

var _focus := Vector2i(-1, -1)
var _focus_valid := false
var _tile_selected := false
var _awaiting_swap_outcome := false
var _horizontal_hold := 0.0
var _vertical_hold := 0.0
var _horizontal_sign := 0
var _vertical_sign := 0
var _select_blocked_until := 0.0
var _select_requires_release := false


func reset() -> void:
	_focus_valid = false
	_tile_selected = false
	_awaiting_swap_outcome = false
	_horizontal_hold = 0.0
	_vertical_hold = 0.0
	_horizontal_sign = 0
	_vertical_sign = 0


func initialize_from_board(dispatcher) -> void:
	reset()
	if not _has_active_gamepad():
		return
	var start := _find_top_left_playable(dispatcher)
	if start.x < 0:
		return
	_focus = start
	_focus_valid = true
	_select_blocked_until = Time.get_ticks_msec() / 1000.0 + STARTUP_SELECT_COOLDOWN


func process(delta: float, dispatcher) -> void:
	if dispatcher == null or dispatcher.is_busy():
		return
	if dispatcher._service == null or not dispatcher._service.is_board_input_allowed():
		return
	if not _has_active_gamepad():
		if _focus_valid:
			reset()
		return
	if not _focus_valid:
		initialize_from_board(dispatcher)
		return
	_release_ui_focus()
	_handle_axis_navigation(delta, dispatcher)
	if Input.is_action_just_pressed("MatchSelect"):
		if _select_requires_release:
			return
		if Time.get_ticks_msec() / 1000.0 < _select_blocked_until:
			return
		if _is_playable(dispatcher, _focus):
			_tile_selected = true
	elif Input.is_action_just_released("MatchSelect"):
		_select_requires_release = false
	if Input.is_action_just_pressed("MatchCancel"):
		_tile_selected = false
	if Input.is_action_just_pressed("Shuffle"):
		_try_shuffle(dispatcher)


func should_draw_focus(dispatcher) -> bool:
	return _focus_valid and _has_active_gamepad() and not dispatcher.is_busy()


func get_focus_coord() -> Vector2i:
	return _focus


func is_tile_selected() -> bool:
	return _tile_selected


func on_swap_resolved() -> void:
	_awaiting_swap_outcome = false
	_tile_selected = false


func on_swap_invalid() -> void:
	_awaiting_swap_outcome = false
	_tile_selected = false


func _handle_axis_navigation(delta: float, dispatcher) -> void:
	var h := GameInputActions.get_axis_value("MoveHorizontal")
	var v := GameInputActions.get_axis_value("MoveVertical")
	if _tile_selected:
		if absf(h) >= AXIS_THRESHOLD:
			var sign := 1 if h > 0.0 else -1
			if sign != _horizontal_sign:
				_horizontal_sign = sign
				_try_swap_from_selection(Vector2i(sign, 0), dispatcher)
		else:
			_horizontal_sign = 0
		if absf(v) >= AXIS_THRESHOLD:
			var sign_v := 1 if v > 0.0 else -1
			if sign_v != _vertical_sign:
				_vertical_sign = sign_v
				_try_swap_from_selection(Vector2i(0, -sign_v), dispatcher)
		else:
			_vertical_sign = 0
		return
	if absf(h) < AXIS_THRESHOLD:
		_horizontal_hold = 0.0
		_horizontal_sign = 0
	else:
		var sign := 1 if h > 0.0 else -1
		if sign != _horizontal_sign:
			_horizontal_sign = sign
			_horizontal_hold = 0.0
			_try_move_focus(Vector2i(sign, 0), dispatcher)
		else:
			_horizontal_hold += delta
			if _horizontal_hold >= AXIS_REPEAT_DELAY:
				while _horizontal_hold >= AXIS_REPEAT_INTERVAL:
					_horizontal_hold -= AXIS_REPEAT_INTERVAL
					_try_move_focus(Vector2i(sign, 0), dispatcher)
	if absf(v) < AXIS_THRESHOLD:
		_vertical_hold = 0.0
		_vertical_sign = 0
	else:
		var sign_v := 1 if v > 0.0 else -1
		if sign_v != _vertical_sign:
			_vertical_sign = sign_v
			_vertical_hold = 0.0
			_try_move_focus(Vector2i(0, -sign_v), dispatcher)
		else:
			_vertical_hold += delta
			if _vertical_hold >= AXIS_REPEAT_DELAY:
				while _vertical_hold >= AXIS_REPEAT_INTERVAL:
					_vertical_hold -= AXIS_REPEAT_INTERVAL
					_try_move_focus(Vector2i(0, -sign_v), dispatcher)


func _try_move_focus(delta: Vector2i, dispatcher) -> void:
	if not _focus_valid:
		return
	var next := _focus + delta
	if not _is_playable(dispatcher, next):
		next = _find_next_playable(dispatcher, _focus, delta)
	if next.x < 0:
		return
	_focus = next
	_tile_selected = false


func _try_swap_from_selection(delta: Vector2i, dispatcher) -> void:
	if delta == Vector2i.ZERO:
		return
	var target := _focus + delta
	if not _is_playable(dispatcher, target):
		return
	_commit_swap(dispatcher, _focus, target)
	_awaiting_swap_outcome = true
	_tile_selected = false


func _commit_swap(dispatcher, a: Vector2i, b: Vector2i) -> void:
	if dispatcher._adapter == null:
		return
	dispatcher._start_optimistic_swap(a, b)
	dispatcher._adapter.request_move(a.x, a.y, b.x, b.y)


func _find_swap_neighbor(_dispatcher, _from: Vector2i) -> Vector2i:
	return Vector2i(-1, -1)


func _try_shuffle(dispatcher) -> void:
	if dispatcher._service == null or dispatcher._service.context == null:
		return
	dispatcher._service.invoke_function("TryUseShuffle", dispatcher._service.context.store.create_object())


func _find_top_left_playable(dispatcher) -> Vector2i:
	for gy in dispatcher._height:
		for x in dispatcher._width:
			var cell := Vector2i(x, gy)
			if _is_playable(dispatcher, cell):
				return cell
	return Vector2i(-1, -1)


func _find_next_playable(dispatcher, from: Vector2i, delta: Vector2i) -> Vector2i:
	var cursor := from + delta
	for _i in dispatcher._width * dispatcher._height:
		if cursor.x < 0 or cursor.x >= dispatcher._width or cursor.y < 0 or cursor.y >= dispatcher._height:
			return Vector2i(-1, -1)
		if _is_playable(dispatcher, cursor):
			return cursor
		cursor += delta
	return Vector2i(-1, -1)


func _is_playable(dispatcher, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dispatcher._width and cell.y < dispatcher._height \
		and dispatcher._has_item_at(cell)


func _has_active_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0


func _release_ui_focus() -> void:
	var tree := Engine.get_main_loop()
	if tree is SceneTree:
		var vp := (tree as SceneTree).root.get_viewport() if (tree as SceneTree).root else null
		if vp and vp.gui_get_focus_owner():
			vp.gui_release_focus()
