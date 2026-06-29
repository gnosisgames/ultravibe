class_name UltraInputActions
extends RefCounted

## Registry of every rebindable InputMap action, mirroring the Unity Rewired setup.

const BINDINGS := {
	"move_left": {
		"label": "ultravibe__input__moveLeft",
		"keycode": KEY_A,
		"physicalKeycode": KEY_A,
		"extraKeys": [KEY_LEFT],
		"gamepadButton": JOY_BUTTON_DPAD_LEFT,
		"category": "gameplay",
	},
	"move_right": {
		"label": "ultravibe__input__moveRight",
		"keycode": KEY_D,
		"physicalKeycode": KEY_D,
		"extraKeys": [KEY_RIGHT],
		"gamepadButton": JOY_BUTTON_DPAD_RIGHT,
		"category": "gameplay",
	},
	"soft_drop": {
		"label": "ultravibe__input__softDrop",
		"keycode": KEY_S,
		"physicalKeycode": KEY_S,
		"extraKeys": [KEY_DOWN],
		"gamepadButton": JOY_BUTTON_DPAD_DOWN,
		"category": "gameplay",
	},
	"hard_drop": {
		"label": "ultravibe__input__hardDrop",
		"keycode": KEY_SPACE,
		"physicalKeycode": KEY_SPACE,
		"gamepadButton": JOY_BUTTON_A,
		"category": "gameplay",
	},
	"rotate_cw": {
		"label": "ultravibe__input__rotateCw",
		"keycode": KEY_W,
		"physicalKeycode": KEY_W,
		"extraKeys": [KEY_UP],
		"gamepadButton": JOY_BUTTON_DPAD_UP,
		"category": "gameplay",
	},
	"rotate_ccw": {
		"label": "ultravibe__input__rotateCcw",
		"keycode": KEY_Z,
		"physicalKeycode": KEY_Z,
		"gamepadButton": JOY_BUTTON_X,
		"category": "gameplay",
	},
	"discard": {
		"label": "ultravibe__input__discard",
		"keycode": KEY_Q,
		"physicalKeycode": KEY_Q,
		"gamepadButton": JOY_BUTTON_B,
		"category": "gameplay",
	},
	"use_consumable": {
		"label": "ultravibe__input__useConsumable",
		"keycode": KEY_E,
		"physicalKeycode": KEY_E,
		"gamepadButton": JOY_BUTTON_Y,
		"category": "gameplay",
	},
	"consumable_next": {
		"label": "ultravibe__input__consumableNext",
		"keycode": KEY_V,
		"physicalKeycode": KEY_V,
		"gamepadButton": JOY_BUTTON_RIGHT_SHOULDER,
		"category": "gameplay",
	},
	"consumable_previous": {
		"label": "ultravibe__input__consumablePrevious",
		"keycode": KEY_C,
		"physicalKeycode": KEY_C,
		"gamepadButton": JOY_BUTTON_LEFT_SHOULDER,
		"category": "gameplay",
	},
	"reward_previous": {
		"label": "ultravibe__input__rewardPrevious",
		"keycode": KEY_COMMA,
		"physicalKeycode": KEY_COMMA,
		"gamepadButton": JOY_BUTTON_LEFT_STICK,
		"category": "gameplay",
	},
	"reward_next": {
		"label": "ultravibe__input__rewardNext",
		"keycode": KEY_PERIOD,
		"physicalKeycode": KEY_PERIOD,
		"gamepadButton": JOY_BUTTON_RIGHT_STICK,
		"category": "gameplay",
	},
	"ability_use": {
		"label": "ultravibe__input__useAbility",
		"keycode": KEY_F,
		"physicalKeycode": KEY_F,
		"gamepadButton": JOY_BUTTON_BACK,
		"category": "gameplay",
	},
	"ability_next": {
		"label": "ultravibe__input__abilityNext",
		"keycode": KEY_BRACKETRIGHT,
		"physicalKeycode": KEY_BRACKETRIGHT,
		"gamepadButton": JOY_BUTTON_RIGHT_SHOULDER,
		"category": "gameplay",
	},
	"ability_previous": {
		"label": "ultravibe__input__abilityPrevious",
		"keycode": KEY_BRACKETLEFT,
		"physicalKeycode": KEY_BRACKETLEFT,
		"gamepadButton": JOY_BUTTON_X,
		"category": "gameplay",
	},
	"pause": {
		"label": "ultravibe__input__pause",
		"keycode": KEY_ESCAPE,
		"physicalKeycode": KEY_ESCAPE,
		"gamepadButton": JOY_BUTTON_START,
		"category": "gameplay",
	},
	"ui_submit": {
		"label": "ultravibe__input__uiSubmit",
		"keycode": KEY_ENTER,
		"physicalKeycode": KEY_ENTER,
		"extraKeys": [KEY_KP_ENTER],
		"gamepadButton": JOY_BUTTON_A,
		"category": "ui",
	},
	# NOTE: This is intentionally NOT Godot's built-in "ui_cancel" action. Godot's
	# LineEdit/TextEdit consult "ui_cancel" and, when it is bound to Backspace, they
	# refuse to treat Backspace as a delete (the event falls through to the GUI cancel
	# path, eating the keystroke and stealing focus). Keep the game's back/cancel on a
	# dedicated action so text fields (e.g. the dev console) keep working.
	"ultra_ui_cancel": {
		"label": "ultravibe__input__uiCancel",
		"keycode": KEY_BACKSPACE,
		"physicalKeycode": KEY_BACKSPACE,
		"gamepadButton": JOY_BUTTON_B,
		"category": "ui",
	},
	"ui_sell": {
		"label": "ultravibe__input__uiSell",
		"keycode": KEY_T,
		"physicalKeycode": KEY_T,
		"gamepadButton": -1,
		"category": "ui",
	},
}

const ALL_ACTION_NAMES: Array[String] = [
	"move_left", "move_right", "soft_drop", "hard_drop", "rotate_cw", "rotate_ccw",
	"discard", "use_consumable", "consumable_next", "consumable_previous",
	"ability_use", "ability_next", "ability_previous", "pause",
	"ui_submit", "ultra_ui_cancel", "ui_sell",
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

## Built-in Godot UI navigation actions consulted by the focus system. Godot's
## focus navigation activates a focused Control via "ui_accept" and reverts/cancels
## via "ui_cancel". In this project those built-ins only ship with keyboard events
## at runtime (Enter/Space on ui_accept, Escape on ui_cancel) -- their default
## gamepad buttons are absent -- so a controller could move pieces in gameplay but
## could neither activate focused buttons nor cancel in menus. Re-bind the standard
## face buttons (A = accept, B = cancel) so gamepad UI navigation matches keyboard.
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
		var pad := int(spec.get("gamepadButton", -1))
		if pad >= 0:
			_apply_gamepad_button(action_name, pad)
	ensure_ui_navigation_gamepad_bindings()

## Ensure the built-in ui_accept/ui_cancel actions keep their controller face-button
## bindings so a gamepad can confirm/cancel in menus exactly like Enter/Escape do.
static func ensure_ui_navigation_gamepad_bindings() -> void:
	for action_name in UI_NAV_GAMEPAD_BINDINGS.keys():
		if not InputMap.has_action(action_name):
			continue
		# all_devices: the built-in focus system activates ui_accept/ui_cancel via
		# Input.is_action_*, which honours the binding's device. A device-specific
		# binding only matches one controller, so confirm/cancel must use
		# InputMap.ALL_DEVICES (-1) to work from every connected gamepad.
		_apply_gamepad_button(action_name, int(UI_NAV_GAMEPAD_BINDINGS[action_name]), true)

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

static func _apply_gamepad_button(action_name: String, button_index: int, all_devices: bool = false) -> void:
	var wanted_device := -1 if all_devices else 0
	for existing in InputMap.action_get_events(action_name):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
			# Re-use the binding only when its device scope already matches; an
			# all-devices request must replace a device-specific binding (and vice
			# versa) so confirm/cancel reaches every controller.
			if (existing as InputEventJoypadButton).device == wanted_device:
				return
			InputMap.action_erase_event(action_name, existing)
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = wanted_device
	InputMap.action_add_event(action_name, event)
