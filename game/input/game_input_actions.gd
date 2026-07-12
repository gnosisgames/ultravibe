class_name GameInputActions
extends RefCounted

## Ultravibe rebindable InputMap actions — mirrors Unity Rewired (see
## old_unity/ultravibe_unity/Assets/Game/Prefabs/Rewired/Rewired Input Manager.prefab).
## Engine contract: UI_CANCEL_ACTION must stay in sync with GnosisGodotInputAdapter.

const UI_CANCEL_ACTION := "game_ui_cancel"

const BINDINGS := {
	"MoveHorizontal": {
		"label": "ultravibe__input__moveHorizontal",
		"category": "gameplay",
		"gamepadAllDevices": true,
		"gamepadAxis": JOY_AXIS_LEFT_X,
		"axisNegativeGamepadButtons": [JOY_BUTTON_DPAD_LEFT],
		"axisPositiveGamepadButtons": [JOY_BUTTON_DPAD_RIGHT],
		"axisNegativeKeys": [KEY_A, KEY_LEFT],
		"axisPositiveKeys": [KEY_D, KEY_RIGHT],
	},
	"MoveVertical": {
		"label": "ultravibe__input__moveVertical",
		"category": "gameplay",
		"gamepadAllDevices": true,
		"gamepadAxis": JOY_AXIS_LEFT_Y,
		"axisNegativeGamepadButtons": [JOY_BUTTON_DPAD_UP],
		"axisPositiveGamepadButtons": [JOY_BUTTON_DPAD_DOWN],
		"axisNegativeKeys": [KEY_W, KEY_UP],
		"axisPositiveKeys": [KEY_S, KEY_DOWN],
	},
	"Consumable": {
		"label": "ultravibe__input__consumable",
		"category": "gameplay",
		"mouseButton": MOUSE_BUTTON_RIGHT,
	},
	"Shuffle": {
		"label": "ultravibe__input__shuffle",
		"category": "gameplay",
		"gamepadAllDevices": true,
		"keycode": KEY_Q,
		"physicalKeycode": KEY_Q,
		"gamepadButton": JOY_BUTTON_Y,
	},
	"MatchSelect": {
		"label": "ultravibe__input__matchSelect",
		"category": "gameplay",
		"gamepadAllDevices": true,
		"gamepadButton": JOY_BUTTON_A,
	},
	"MatchCancel": {
		"label": "ultravibe__input__matchCancel",
		"category": "gameplay",
		"gamepadAllDevices": true,
		"gamepadButton": JOY_BUTTON_B,
	},
	"UIHorizontal": {
		"label": "ultravibe__input__uiHorizontal",
		"category": "ui",
		"gamepadAxis": JOY_AXIS_LEFT_X,
		"axisNegativeKeys": [KEY_LEFT],
		"axisPositiveKeys": [KEY_RIGHT],
	},
	"UIVertical": {
		"label": "ultravibe__input__uiVertical",
		"category": "ui",
		"gamepadAxis": JOY_AXIS_LEFT_Y,
		"axisNegativeKeys": [KEY_UP],
		"axisPositiveKeys": [KEY_DOWN],
	},
	"UISubmit": {
		"label": "ultravibe__input__uiSubmit",
		"keycode": KEY_ENTER,
		"physicalKeycode": KEY_ENTER,
		"extraKeys": [KEY_KP_ENTER],
		"gamepadButton": JOY_BUTTON_A,
		"category": "ui",
	},
	UI_CANCEL_ACTION: {
		"label": "ultravibe__input__uiCancel",
		"keycode": KEY_BACKSPACE,
		"physicalKeycode": KEY_BACKSPACE,
		"gamepadButton": JOY_BUTTON_B,
		"category": "ui",
	},
	"UISell": {
		"label": "ultravibe__input__uiSell",
		"keycode": KEY_T,
		"physicalKeycode": KEY_T,
		"gamepadButton": JOY_BUTTON_LEFT_SHOULDER,
		"category": "ui",
	},
	"Pause": {
		"label": "ultravibe__input__pause",
		"keycode": KEY_ESCAPE,
		"physicalKeycode": KEY_ESCAPE,
		"gamepadButton": JOY_BUTTON_LEFT_STICK,
		"category": "ui",
	},
	"quick_restart": {
		"label": "core__input__quickRestart",
		"keycode": KEY_R,
		"physicalKeycode": KEY_R,
		"gamepadButton": JOY_BUTTON_RIGHT_STICK,
		"category": "gameplay",
	},
	"UISecondaryHorizontal": {
		"label": "ultravibe__input__uiSecondaryHorizontal",
		"category": "ui",
		"gamepadAxis": JOY_AXIS_RIGHT_X,
	},
	"UISecondaryVertical": {
		"label": "ultravibe__input__uiSecondaryVertical",
		"category": "ui",
		"gamepadAxis": JOY_AXIS_RIGHT_Y,
	},
	"UITabSwitch": {
		"label": "ultravibe__input__uiTabSwitch",
		"category": "ui",
		"gamepadButton": JOY_BUTTON_RIGHT_SHOULDER,
		"extraGamepadButtons": [JOY_BUTTON_BACK],
	},
	"UIBuy": {
		"label": "ultravibe__input__uiBuy",
		"keycode": KEY_SPACE,
		"physicalKeycode": KEY_SPACE,
		"mouseButton": MOUSE_BUTTON_MIDDLE,
		"category": "ui",
	},
}

const ALL_ACTION_NAMES: Array[String] = [
	"MoveHorizontal", "MoveVertical", "Consumable", "Shuffle", "MatchSelect", "MatchCancel",
	"UIHorizontal", "UIVertical", "UISubmit", UI_CANCEL_ACTION, "UISell", "Pause", "quick_restart",
	"UISecondaryHorizontal", "UISecondaryVertical", "UITabSwitch", "UIBuy",
]

static func action_names() -> Array[String]:
	return ALL_ACTION_NAMES.duplicate()

static func gameplay_action_names() -> Array[String]:
	var names: Array[String] = []
	for key in BINDINGS.keys():
		if str(BINDINGS[key].get("category", "")) == "gameplay":
			names.append(str(key))
	return names

static func default_gamepad_button(action_name: String) -> int:
	var spec: Dictionary = BINDINGS.get(action_name, {})
	return int(spec.get("gamepadButton", -1))

## UI-category actions must bind to every connected gamepad (pause, menus, etc.).
static func gamepad_binding_all_devices(action_name: String) -> bool:
	if UI_NAV_GAMEPAD_BINDINGS.has(action_name):
		return true
	var spec: Dictionary = BINDINGS.get(action_name, {})
	if bool(spec.get("gamepadAllDevices", false)):
		return true
	return str(spec.get("category", "")) == "ui"

static func axis_negative_action(base: String) -> String:
	return "%s_neg" % base

static func axis_positive_action(base: String) -> String:
	return "%s_pos" % base

static func get_axis_value(base: String) -> float:
	return Input.get_action_strength(axis_positive_action(base)) - Input.get_action_strength(axis_negative_action(base))

## Built-in Godot UI navigation actions consulted by the focus system.
const UI_NAV_GAMEPAD_BINDINGS := {
	"ui_accept": JOY_BUTTON_A,
	"ui_cancel": JOY_BUTTON_B,
}

static func ensure_input_map() -> void:
	for action_name in BINDINGS.keys():
		var spec: Dictionary = BINDINGS[action_name]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		_apply_default_keyboard(action_name, spec)
		if spec.has("gamepadAxis"):
			_apply_gamepad_axis_pair(action_name, int(spec.gamepadAxis), gamepad_binding_all_devices(action_name))
			_strip_legacy_base_axis_bindings(action_name)
		var pad := int(spec.get("gamepadButton", -1))
		if pad >= 0:
			_apply_gamepad_button(action_name, pad, gamepad_binding_all_devices(action_name))
		for extra_pad in spec.get("extraGamepadButtons", []):
			_apply_gamepad_button(action_name, int(extra_pad), gamepad_binding_all_devices(action_name))
		if spec.has("mouseButton"):
			_apply_mouse_button(action_name, int(spec.mouseButton))
		var neg_keys: Array = spec.get("axisNegativeKeys", [])
		var pos_keys: Array = spec.get("axisPositiveKeys", [])
		if not neg_keys.is_empty() or not pos_keys.is_empty():
			_apply_axis_keyboard_pair(action_name, neg_keys, pos_keys)
		for button_index in spec.get("axisNegativeGamepadButtons", []):
			_apply_gamepad_button(axis_negative_action(action_name), int(button_index), gamepad_binding_all_devices(action_name))
		for button_index in spec.get("axisPositiveGamepadButtons", []):
			_apply_gamepad_button(axis_positive_action(action_name), int(button_index), gamepad_binding_all_devices(action_name))
	ensure_ui_navigation_gamepad_bindings()

static func ensure_ui_navigation_gamepad_bindings() -> void:
	for action_name in UI_NAV_GAMEPAD_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			continue
		_apply_gamepad_button(action_name, int(UI_NAV_GAMEPAD_BINDINGS[action_name]), true)

static func _apply_axis_keyboard_pair(base: String, negative_keys: Array, positive_keys: Array) -> void:
	var neg_name := axis_negative_action(base)
	var pos_name := axis_positive_action(base)
	for companion in [neg_name, pos_name]:
		if not InputMap.has_action(companion):
			InputMap.add_action(companion)
	for code in negative_keys:
		_add_key_if_missing(neg_name, int(code))
	for code in positive_keys:
		_add_key_if_missing(pos_name, int(code))

static func _add_key_if_missing(action_name: String, keycode: int) -> void:
	if keycode <= 0:
		return
	if not _has_keyboard_binding(action_name, keycode, keycode):
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		InputMap.action_add_event(action_name, event)

static func _apply_default_keyboard(action_name: String, spec: Dictionary) -> void:
	var keycode := int(spec.get("keycode", 0))
	var physical := int(spec.get("physicalKeycode", keycode))
	if keycode <= 0 and physical <= 0:
		return
	if not _has_keyboard_binding(action_name, keycode, physical):
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = physical
		InputMap.action_add_event(action_name, event)
	for extra in spec.get("extraKeys", []):
		var code := int(extra)
		if code <= 0:
			continue
		if not _has_keyboard_binding(action_name, code, code):
			var extra_event := InputEventKey.new()
			extra_event.keycode = code
			extra_event.physical_keycode = code
			InputMap.action_add_event(action_name, extra_event)

static func _has_keyboard_binding(action_name: String, keycode: int, physical: int) -> bool:
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventKey:
			var key_event := existing as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == physical:
				return true
	return false

static func _strip_legacy_base_axis_bindings(base_action: String) -> void:
	if not InputMap.has_action(base_action):
		return
	for existing in InputMap.action_get_events(base_action):
		if existing is InputEventJoypadMotion:
			InputMap.action_erase_event(base_action, existing)


static func _apply_gamepad_axis_pair(base_action: String, axis: int, all_devices: bool) -> void:
	var neg_name := axis_negative_action(base_action)
	var pos_name := axis_positive_action(base_action)
	for companion in [neg_name, pos_name]:
		if not InputMap.has_action(companion):
			InputMap.add_action(companion)
	_apply_gamepad_axis_direction(neg_name, axis, -1.0, all_devices)
	_apply_gamepad_axis_direction(pos_name, axis, 1.0, all_devices)


static func _apply_gamepad_axis_direction(action_name: String, axis: int, axis_value: float, all_devices: bool) -> void:
	var wanted_device := -1 if all_devices else 0
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventJoypadMotion:
			var motion := existing as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(motion.axis_value, axis_value):
				if motion.device == wanted_device:
					return
				InputMap.action_erase_event(action_name, existing)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	event.device = wanted_device
	InputMap.action_add_event(action_name, event)

static func _apply_gamepad_button(action_name: String, button_index: int, all_devices: bool = false) -> void:
	if button_index < 0:
		return
	var wanted_device := -1 if all_devices else 0
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
			if (existing as InputEventJoypadButton).device == wanted_device:
				return
			InputMap.action_erase_event(action_name, existing)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = wanted_device
	InputMap.action_add_event(action_name, event)

static func _apply_mouse_button(action_name: String, button_index: int) -> void:
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventMouseButton and (existing as InputEventMouseButton).button_index == button_index:
			return
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)
