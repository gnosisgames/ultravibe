class_name InputActionDisplay
extends RefCounted

## Resolves Kenney-style input glyph textures (via Controller Icons addon) or short
## text fallbacks when sprites are unavailable (headless tests, editor without plugin).

const GLYPH_CHIP_SIZE := Vector2(32, 32)


static func resolve_glyph_texture(entry: Dictionary) -> Texture2D:
	var icons := _controller_icons()
	if icons == null:
		return null
	var input_type: int = icons.get_last_input_type()
	if input_type == icons.InputType.CONTROLLER:
		var action := str(entry.get("input_action", "")).strip_edges()
		if not action.is_empty():
			var pad_tex := icons.parse_path(action) as Texture2D
			if pad_tex != null:
				return pad_tex
	if entry.has("input_mouse_button"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(entry.get("input_mouse_button"))
		var mouse_tex := icons.parse_event(mouse_event) as Texture2D
		if mouse_tex != null:
			return mouse_tex
	var path := str(entry.get("input_path", "")).strip_edges()
	if not path.is_empty():
		var path_tex := icons.parse_path(path) as Texture2D
		if path_tex != null:
			return path_tex
	var fallback_action := str(entry.get("input_action", "")).strip_edges()
	if not fallback_action.is_empty():
		return icons.parse_path(fallback_action) as Texture2D
	return null


static func resolve_glyph_fallback_text(entry: Dictionary) -> String:
	if entry.has("input_mouse_button"):
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(entry.get("input_mouse_button"))
		return mouse_event.as_text()
	var action := str(entry.get("input_action", "")).strip_edges()
	if not action.is_empty():
		return format_action(action)
	return str(entry.get("input_glyph", "")).strip_edges()


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


static func _controller_icons() -> Node:
	if not Engine.is_editor_hint() and Engine.get_main_loop() is SceneTree:
		var tree := Engine.get_main_loop() as SceneTree
		if tree.root:
			return tree.root.get_node_or_null("ControllerIcons")
	return null


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
