extends SceneTree

## Regression guard for gamepad menu navigation.
##
## The bug: with a controller, focused menu buttons would not activate (confirm)
## and dialogs would not cancel, because Godot's built-in ui_accept / ui_cancel
## actions shipped with keyboard events only -- their gamepad face-button bindings
## (A = accept, B = cancel) were missing at runtime. Gameplay worked because the
## gameplay actions kept their own gamepad buttons.
##
## This test asserts (1) the bindings are present after boot and scoped to ALL
## devices (-1) so every controller can confirm/cancel, and (2) a synthesized
## JOY_BUTTON_A press from a NON-zero device activates a focused Button via Godot's
## focus navigation (the regression was that only device 0 could activate).

var _button: Button = null
var _pressed := false
var _phase := 0
var _ok := true

func _initialize() -> void:
	print("--- UI Gamepad Nav Test ---")
	GameInputActions.ensure_input_map()
	_ok = _check_bindings() and _ok

	var layer := Control.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(layer)
	_button = Button.new()
	_button.text = "OK"
	_button.focus_mode = Control.FOCUS_ALL
	_button.pressed.connect(func(): _pressed = true)
	layer.add_child(_button)

func _process(_delta: float) -> bool:
	_phase += 1
	if _phase == 2:
		_button.grab_focus()
	elif _phase == 3:
		if _button.has_focus():
			print("[SUCCESS] button holds focus before input")
		else:
			print("[FAIL] button lost focus before input")
			_ok = false
		_send_joypad_button(JOY_BUTTON_A, true)
	elif _phase == 4:
		_send_joypad_button(JOY_BUTTON_A, false)
	elif _phase >= 6:
		if _pressed:
			print("[SUCCESS] JOY_BUTTON_A activated the focused button via ui_accept")
		else:
			print("[FAIL] focused button did not activate from JOY_BUTTON_A")
			_ok = false
		print("--- UI Gamepad Nav Test %s ---" % ("Passed" if _ok else "FAILED"))
		quit(0 if _ok else 1)
		return true
	return false

func _check_bindings() -> bool:
	var ok := true
	ok = _expect_joypad("ui_accept", JOY_BUTTON_A) and ok
	ok = _expect_joypad("ui_cancel", JOY_BUTTON_B) and ok
	return ok

func _expect_joypad(action: String, button_index: int) -> bool:
	if not InputMap.has_action(action):
		print("[FAIL] action %s missing" % action)
		return false
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button_index:
			if (ev as InputEventJoypadButton).device != -1:
				print("[FAIL] %s joypad binding is device %d, expected -1 (all devices)" % [action, (ev as InputEventJoypadButton).device])
				return false
			print("[SUCCESS] %s bound to joypad button %d on all devices" % [action, button_index])
			return true
	print("[FAIL] %s missing joypad button %d" % [action, button_index])
	return false

func _send_joypad_button(button_index: int, pressed: bool) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index
	ev.pressed = pressed
	# Fire from a non-zero device id: a device-0-only binding would ignore this,
	# so success proves the binding reaches every controller.
	ev.device = 3
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
