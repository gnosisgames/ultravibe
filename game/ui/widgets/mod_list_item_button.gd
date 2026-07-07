class_name ModListItemButton
extends Button

## Mod picker row styled like Settings tab buttons (RoundedSquareBtn palette).

signal mod_focused(mod_id: String)

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

const TEXT_WHITE := Color(1, 1, 1, 1)
const BG_NORMAL := Color(0.345098, 0.345098, 0.572549, 1)
const BG_PRESSED := Color(0.278431, 0.278431, 0.439216, 1)
const BG_HOVER := Color(0.415686, 0.415686, 0.658824, 1)
const BORDER_FOCUS := Color(0.180392, 0.160784, 0.321569, 1)
const SHADOW := Color(0.0784314, 0.137255, 0.227451, 1)
const TEXT_DIMMED := Color(0.62, 0.66, 0.74, 1)
const STATUS_DOT_RADIUS := 5.0
const STATUS_DOT_CENTER_X := 12.0
const STATUS_ACTIVE := Color(0.42, 0.9, 0.58, 1)
const STATUS_DISABLED := Color(0.55, 0.58, 0.66, 0.95)

var mod_id: String = ""
var _inactive: bool = false
var _tween: Tween

func configure(id: String, title: String, version: String, inactive: bool) -> void:
	mod_id = id
	_inactive = inactive
	var label := title if not title.is_empty() else id
	if not version.is_empty():
		label = "%s  v%s" % [label, version]
	text = label
	clip_text = true
	disabled = false
	tooltip_text = label
	_update_font_colors()
	queue_redraw()

func _ready() -> void:
	toggle_mode = true
	focus_mode = FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 56)
	add_theme_font_override("font", UI_FONT)
	add_theme_font_size_override("font_size", 24)
	_apply_styles()
	_update_font_colors()
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)
	pressed.connect(_on_pressed)

func _apply_styles() -> void:
	add_theme_stylebox_override("normal", _make_style(BG_NORMAL))
	add_theme_stylebox_override("pressed", _make_style(BG_PRESSED))
	add_theme_stylebox_override("hover", _make_style(BG_HOVER, 4))
	add_theme_stylebox_override("focus", _make_style(BG_NORMAL, 4))
	add_theme_stylebox_override("disabled", _make_style(Color(0.38, 0.38, 0.38, 1)))

func _make_style(bg: Color, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.content_margin_left = 24.0
	style.content_margin_right = 6.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.set_corner_radius_all(16)
	style.corner_detail = 12
	style.shadow_color = SHADOW
	style.shadow_size = 1
	style.shadow_offset = Vector2(3, 4)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = BORDER_FOCUS
	return style

func _update_font_colors() -> void:
	var color := TEXT_DIMMED if _inactive else TEXT_WHITE
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_hover_color", color)
	add_theme_color_override("font_pressed_color", color)
	add_theme_color_override("font_focus_color", color)

func _draw() -> void:
	_draw_status_dot()

func _draw_status_dot() -> void:
	var center := Vector2(STATUS_DOT_CENTER_X, size.y * 0.5)
	if _inactive:
		draw_arc(center, STATUS_DOT_RADIUS, 0.0, TAU, 24, STATUS_DISABLED, 2.0, true)
	else:
		draw_circle(center, STATUS_DOT_RADIUS, STATUS_ACTIVE)
		draw_circle(center, STATUS_DOT_RADIUS * 0.42, Color(1, 1, 1, 0.28))

func _on_focus_entered() -> void:
	if mod_id.is_empty():
		return
	mod_focused.emit(mod_id)
	_play_hover_juice()

func _on_focus_exited() -> void:
	_play_unhover_juice()

func _on_pressed() -> void:
	if mod_id.is_empty():
		return
	mod_focused.emit(mod_id)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)

func _play_hover_juice() -> void:
	if disabled:
		return
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	var scale_ratio := clampf(128.0 / maxf(size.x, 1.0), 0.5, 1.0)
	var scale_target := 1.0 + 0.06 * scale_ratio
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(scale_target, scale_target), 0.18)
	_tween.parallel().tween_property(self, "rotation_degrees", 2.5 * scale_ratio * [-1.0, 1.0].pick_random(), 0.1)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func _play_unhover_juice() -> void:
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func set_selected_state(is_selected: bool) -> void:
	button_pressed = is_selected
	if is_selected and is_inside_tree():
		_play_selected_pulse()

func _play_selected_pulse() -> void:
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.14)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
