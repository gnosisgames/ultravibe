class_name JuicyToggle
extends Button

## Custom-drawn Ultravibe switch with button-like hover/focus juice.

const OFF_BG := Color(0.164706, 0.207843, 0.313725, 1.0)
const ON_BG := Color(0.345098, 0.345098, 0.572549, 1.0)
const OUTLINE := Color(1, 1, 1, 1)
const KNOB := Color(1, 1, 1, 1)
const KNOB_DARK := Color(0.078431, 0.137255, 0.227451, 1.0)
const SHADOW := Color(0.078431, 0.137255, 0.227451, 0.85)

var _scale_tween: Tween
var _knob_tween: Tween
var _knob_ratio: float = 0.0
var _hovered: bool = false
var silent: bool = false

func _ready() -> void:
	toggle_mode = true
	text = ""
	flat = true
	_knob_ratio = 1.0 if button_pressed else 0.0
	if Engine.is_editor_hint():
		return
	focus_mode = FOCUS_ALL
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_unhover)
	toggled.connect(_on_toggled)

func set_pressed_silent(value: bool) -> void:
	silent = true
	set_pressed_no_signal(value)
	_set_knob_ratio(1.0 if value else 0.0)
	silent = false

func _on_mouse_entered() -> void:
	grab_focus()

func _on_toggled(_on: bool) -> void:
	_tween_knob(1.0 if _on else 0.0)
	if silent:
		return
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)
	if _on:
		UltraUiFx.vibrate(self)

func _on_hover() -> void:
	if disabled:
		return
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
	_hovered = true
	_animate_scale(1.1)

func _on_unhover() -> void:
	_hovered = false
	_animate_scale(1.0)

func _animate_scale(target: float) -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(target, target), 0.2)

func _tween_knob(target: float) -> void:
	if _knob_tween and _knob_tween.is_running():
		_knob_tween.kill()
	_knob_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_knob_tween.tween_method(_set_knob_ratio, _knob_ratio, target, 0.22)

func _set_knob_ratio(value: float) -> void:
	_knob_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var pad := 4.0
	var rect := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		return

	var radius := int(rect.size.y * 0.5)
	var bg := OFF_BG.lerp(ON_BG, _knob_ratio)
	var outline_width := 4 if (button_pressed or _hovered or has_focus()) else 3

	var shadow_box := StyleBoxFlat.new()
	shadow_box.bg_color = SHADOW
	shadow_box.set_corner_radius_all(radius)
	draw_style_box(shadow_box, Rect2(rect.position + Vector2(3, 4), rect.size))

	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = OUTLINE
	box.set_border_width_all(outline_width)
	box.set_corner_radius_all(radius)
	draw_style_box(box, rect)

	var knob_radius := rect.size.y * 0.34
	var knob_x_min := rect.position.x + rect.size.y * 0.5
	var knob_x_max := rect.end.x - rect.size.y * 0.5
	var knob_center := Vector2(lerpf(knob_x_min, knob_x_max, _knob_ratio), rect.get_center().y)

	draw_circle(knob_center + Vector2(2, 3), knob_radius + 1.0, SHADOW)
	draw_circle(knob_center, knob_radius + 2.0, KNOB_DARK)
	draw_circle(knob_center, knob_radius, KNOB)
