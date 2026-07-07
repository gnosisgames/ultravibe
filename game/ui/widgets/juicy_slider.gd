@tool
class_name JuicySlider
extends HSlider

## A themed HSlider that draws its own animated track / fill / knob:
## - the whole slider scale-pops (TRANS_BACK) on hover/focus, like RoundedSquareBtn
## - the blue fill is outlined (cream border + navy drop shadow), like the buttons
## - the fill glides to the new value and the knob punches when it changes
## - an optional 0-100% readout sits on the right edge
## All visuals are custom-drawn so the motion is fully controllable.

const TRACK_COLOR := Color(0.137255, 0.196078, 0.282353, 1.0)
const FILL_COLOR := Color(0.345098, 0.345098, 0.572549, 1.0)
const FILL_OUTLINE := Color(1, 1, 1, 1)
const SHADOW_COLOR := Color(0.078431, 0.137255, 0.227451, 0.85)
const KNOB_COLOR := Color(1, 1, 1, 1)
const KNOB_OUTLINE := Color(0.078431, 0.137255, 0.227451, 1.0)

@export var show_value: bool = true:
	set(v):
		show_value = v
		if is_inside_tree():
			_refresh_value_label()
			queue_redraw()
@export var hover_scale: float = 1.05

var _display_ratio: float = 0.0
var _knob_scale: float = 1.0
var _outline_width: float = 2.0
var _hovered: bool = false
var _fill_tween: Tween
var _knob_tween: Tween
var _scale_tween: Tween
var _outline_tween: Tween

@onready var _value_label: Label = $ValueLabel

func _ready() -> void:
	_hide_default_grabber()
	_display_ratio = _target_ratio()
	_refresh_value_label()
	if Engine.is_editor_hint():
		return
	value_changed.connect(_on_value_changed)
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)

func _hide_default_grabber() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var blank := ImageTexture.create_from_image(img)
	add_theme_icon_override("grabber", blank)
	add_theme_icon_override("grabber_highlight", blank)
	add_theme_icon_override("grabber_disabled", blank)

func _target_ratio() -> float:
	var span := max_value - min_value
	if span <= 0.0:
		return 0.0
	return clampf((value - min_value) / span, 0.0, 1.0)

func _value_inset() -> float:
	return 64.0 if show_value else 0.0

func _refresh_value_label() -> void:
	if _value_label == null:
		return
	_value_label.visible = show_value
	_value_label.text = "%d%%" % roundi(_target_ratio() * 100.0)

func _on_value_changed(_v: float) -> void:
	_animate_fill_to(_target_ratio())
	_punch_knob()
	_refresh_value_label()

func _animate_fill_to(target: float) -> void:
	if _fill_tween and _fill_tween.is_running():
		_fill_tween.kill()
	_fill_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_fill_tween.tween_method(_set_display_ratio, _display_ratio, target, 0.22)

func _set_display_ratio(v: float) -> void:
	_display_ratio = v
	queue_redraw()

func _punch_knob() -> void:
	_tween_knob(1.5)

func _on_hover() -> void:
	if not editable:
		return
	_hovered = true
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
	_tween_knob(1.3)
	_tween_scale(hover_scale)
	_tween_outline(4.0)

func _on_unhover() -> void:
	_hovered = false
	_tween_knob(1.0)
	_tween_scale(1.0)
	_tween_outline(2.0)

func _tween_scale(target: float) -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(target, target), 0.25)

func _tween_outline(target: float) -> void:
	if _outline_tween and _outline_tween.is_running():
		_outline_tween.kill()
	_outline_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_outline_tween.tween_method(_set_outline_width, _outline_width, target, 0.2)

func _set_outline_width(v: float) -> void:
	_outline_width = v
	queue_redraw()

func _tween_knob(peak: float) -> void:
	var rest := 1.3 if _hovered else 1.0
	if _knob_tween and _knob_tween.is_running():
		_knob_tween.kill()
	_knob_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	if peak > rest:
		_knob_tween.tween_method(_set_knob_scale, _knob_scale, peak, 0.1)
		_knob_tween.tween_method(_set_knob_scale, peak, rest, 0.18)
	else:
		_knob_tween.tween_method(_set_knob_scale, _knob_scale, rest, 0.18)

func _set_knob_scale(v: float) -> void:
	_knob_scale = v
	queue_redraw()

func _draw() -> void:
	var sz := size
	var knob_r := clampf(min(sz.y, 34.0) * 0.5, 8.0, 18.0)
	var track_h := clampf(sz.y * 0.42, 10.0, 18.0)
	var track_x0 := knob_r
	var track_w := maxf(sz.x - knob_r * 2.0 - _value_inset(), 1.0)
	var cy := sz.y * 0.5
	var ratio := clampf(_display_ratio, 0.0, 1.0)
	var radius := int(track_h * 0.5)

	var track_box := StyleBoxFlat.new()
	track_box.bg_color = TRACK_COLOR
	track_box.set_corner_radius_all(radius)
	draw_style_box(track_box, Rect2(track_x0, cy - track_h * 0.5, track_w, track_h))

	var fill_w := maxf(track_w * ratio, track_h)
	var fill_box := StyleBoxFlat.new()
	fill_box.bg_color = FILL_COLOR
	fill_box.set_corner_radius_all(radius)
	fill_box.set_border_width_all(int(round(_outline_width)))
	fill_box.border_color = FILL_OUTLINE
	fill_box.shadow_color = SHADOW_COLOR
	fill_box.shadow_size = 2
	fill_box.shadow_offset = Vector2(2, 3)
	draw_style_box(fill_box, Rect2(track_x0, cy - track_h * 0.5, fill_w, track_h))

	var kx := track_x0 + track_w * ratio
	var r := knob_r * _knob_scale
	draw_circle(Vector2(kx + 2.0, cy + 3.0), r + 2.0, SHADOW_COLOR)
	draw_circle(Vector2(kx, cy), r + 2.0, KNOB_OUTLINE)
	draw_circle(Vector2(kx, cy), r, KNOB_COLOR)
