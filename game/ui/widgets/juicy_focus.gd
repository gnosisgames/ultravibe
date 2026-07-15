class_name JuicyFocus
extends RefCounted

## Scale/rotate hover juice for non-Button controls (shop tiles, panels, etc.).
## Mirrors RoundedSquareBtn / JuicyButton timing and random tilt wiggle.

const TWEEN_META := "_juicy_focus_tween"
const WIRED_META := "_juicy_focus_wired"
const PREV_Z_META := "_juicy_focus_prev_z"
const HOVER_META := "_juicy_focus_mouse_hover"

static func wire(
	control: Control,
	hover_animate: bool = true,
	play_sfx: bool = true,
	width_full_rot: float = 128.0,
	grab_focus_on_mouse: bool = true,
	raise_z_on_focus: bool = false,
	animate_on_mouse_hover: bool = false
) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control.has_meta(WIRED_META):
		return
	control.set_meta(WIRED_META, true)

	if animate_on_mouse_hover and not grab_focus_on_mouse:
		control.set_meta(HOVER_META, false)
		control.mouse_entered.connect(func() -> void:
			control.set_meta(HOVER_META, true)
			_apply_juice_state(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
		)
		control.mouse_exited.connect(func() -> void:
			control.set_meta(HOVER_META, false)
			_apply_juice_state(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
		)
		control.focus_entered.connect(func() -> void:
			_apply_juice_state(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
		)
		control.focus_exited.connect(func() -> void:
			_apply_juice_state(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
		)
		return

	control.focus_entered.connect(func() -> void:
		enter(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
	)
	control.focus_exited.connect(func() -> void:
		exit(control, hover_animate, raise_z_on_focus)
	)
	if grab_focus_on_mouse:
		control.mouse_entered.connect(control.grab_focus)
		control.mouse_exited.connect(control.release_focus)


static func _apply_juice_state(
	control: Control,
	hover_animate: bool,
	play_sfx: bool,
	width_full_rot: float,
	raise_z_on_focus: bool
) -> void:
	if control.has_focus() or control.get_meta(HOVER_META, false):
		enter(control, hover_animate, play_sfx, width_full_rot, raise_z_on_focus)
	else:
		exit(control, hover_animate, raise_z_on_focus)


static func enter(
	control: Control,
	hover_animate: bool = true,
	play_sfx: bool = true,
	width_full_rot: float = 128.0,
	raise_z_on_focus: bool = false
) -> void:
	if control == null or not is_instance_valid(control):
		return
	if control is BaseButton and (control as BaseButton).disabled:
		return
	if play_sfx:
		UltraUiFx.vibrate(control)
		UltraUiFx.play_ui_sfx(control, UltraUiFx.CLIP_HOVER, -4.0)
	if raise_z_on_focus:
		control.set_meta(PREV_Z_META, control.z_index)
		control.z_index = 1
	if not hover_animate:
		return
	_kill_tween(control)
	control.pivot_offset = control.size / 2.0
	var scale_ratio := clampf(width_full_rot / maxf(control.size.x, 1.0), 0.5, 1.0)
	var scale_target := 1.0 + 0.2 * scale_ratio
	var tween := control.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	control.set_meta(TWEEN_META, tween)
	tween.tween_property(control, "scale:x", scale_target, 0.2)
	tween.parallel().tween_property(control, "scale:y", scale_target, 0.35)
	tween.parallel().tween_property(
		control,
		"rotation_degrees",
		5.0 * scale_ratio * [-1.0, 1.0].pick_random(),
		0.1
	)
	tween.parallel().tween_property(control, "rotation_degrees", 0.0, 0.1).set_delay(0.1)


static func exit(
	control: Control,
	hover_animate: bool = true,
	raise_z_on_focus: bool = false
) -> void:
	if control == null or not is_instance_valid(control):
		return
	if raise_z_on_focus and control.has_meta(PREV_Z_META):
		control.z_index = int(control.get_meta(PREV_Z_META))
		control.remove_meta(PREV_Z_META)
	if not hover_animate:
		_reset_visual(control)
		return
	_kill_tween(control)
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	control.set_meta(TWEEN_META, tween)
	tween.tween_property(control, "scale:x", 1.0, 0.25)
	tween.parallel().tween_property(control, "scale:y", 1.0, 0.35)
	tween.parallel().tween_property(control, "rotation_degrees", 0.0, 0.1)


static func play_pressed(control: Control, play_sfx: bool = true) -> void:
	if control == null or not is_instance_valid(control):
		return
	if play_sfx:
		UltraUiFx.play_ui_sfx(control, UltraUiFx.CLIP_PRESSED)
	_kill_tween(control)
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	control.set_meta(TWEEN_META, tween)
	tween.tween_property(control, "scale", Vector2(0.92, 0.92), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.14)


static func _kill_tween(control: Control) -> void:
	if not control.has_meta(TWEEN_META):
		return
	var tween: Variant = control.get_meta(TWEEN_META)
	if tween is Tween and (tween as Tween).is_valid() and (tween as Tween).is_running():
		(tween as Tween).kill()
	control.remove_meta(TWEEN_META)


static func _reset_visual(control: Control) -> void:
	_kill_tween(control)
	control.scale = Vector2.ONE
	control.rotation_degrees = 0.0
	control.pivot_offset = Vector2.ZERO
