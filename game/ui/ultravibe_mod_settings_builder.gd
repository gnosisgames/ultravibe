class_name UltravibeModSettingsBuilder
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/mods/gnosis_mod_settings_builder.gd"

const JuicyToggleScene := preload("res://game/ui/widgets/juicy_toggle.tscn")
const JuicySliderScene := preload("res://game/ui/widgets/juicy_slider.tscn")

func _create_bool_control(initial: bool, mod_active: bool, on_toggled: Callable) -> Control:
	var toggle: JuicyToggle = JuicyToggleScene.instantiate()
	toggle.disabled = not mod_active
	toggle.set_pressed_silent(initial)
	toggle.toggled.connect(on_toggled)
	return toggle

func _create_number_control(
	initial: float,
	min_value: float,
	max_value: float,
	is_float: bool,
	mod_active: bool,
	on_changed: Callable
) -> Control:
	var slider: JuicySlider = JuicySliderScene.instantiate()
	slider.custom_minimum_size = Vector2(280, 40)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_END
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = 0.01 if is_float else 1.0
	slider.value = initial
	slider.editable = mod_active
	slider.value_changed.connect(on_changed)
	return slider
