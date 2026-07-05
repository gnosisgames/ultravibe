class_name InputActionDisplay
extends RefCounted

## Resolves a short display string for an InputMap action (keyboard or gamepad).


static func format_mouse_button(button_index: int) -> String:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event.as_text()


static func format_action(action_name: String) -> String:
	var trimmed := action_name.strip_edges()
	if trimmed.is_empty() or not InputMap.has_action(trimmed):
		return ""
	var keyboard := _first_keyboard_label(trimmed)
	if not keyboard.is_empty():
		return keyboard
	return _first_gamepad_label(trimmed)


static func _first_keyboard_label(action_name: String) -> String:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var code := key_event.keycode if key_event.keycode != 0 else key_event.physical_keycode
			if code == 0:
				continue
			return OS.get_keycode_string(code)
	return ""


static func _first_gamepad_label(action_name: String) -> String:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton:
			var pad_event := InputEventJoypadButton.new()
			pad_event.button_index = (event as InputEventJoypadButton).button_index
			return pad_event.as_text()
	return ""
