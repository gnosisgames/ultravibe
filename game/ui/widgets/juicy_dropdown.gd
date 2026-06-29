class_name JuicyDropdown
extends OptionButton

## OptionButton with extra juice: blue/cream rounded styleboxes, a
## hover scale-pop with SFX/haptics, an arrow that flips while open, and a
## fully themed popup so the opened menu matches the closed button.

const BG := Color(0.164706, 0.207843, 0.313725, 1.0)
const BG_HOVER := Color(0.345098, 0.345098, 0.572549, 1.0)
const BG_PRESSED := Color(0.184314, 0.388235, 0.65098, 1.0)
const OUTLINE := Color(0.992157, 0.894118, 0.72549, 1.0)
const OUTLINE_IDLE := Color(0.32, 0.5, 0.69, 1.0)
const CREAM := Color(0.992157, 0.894118, 0.72549, 1.0)
const POPUP_BG := Color(0.0980392, 0.156863, 0.227451, 1.0)
const FONT := preload("res://assets/fonts/Comic Lemon.otf")

var _scale_tween: Tween

func _ready() -> void:
	focus_mode = FOCUS_ALL
	flat = false
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_theme_font_override("font", FONT)
	add_theme_font_size_override("font_size", 24)
	add_theme_color_override("font_color", CREAM)
	add_theme_color_override("font_hover_color", Color.WHITE)
	add_theme_color_override("font_pressed_color", Color.WHITE)
	add_theme_color_override("font_focus_color", CREAM)
	add_theme_stylebox_override("normal", _box(BG, OUTLINE_IDLE, 2))
	add_theme_stylebox_override("hover", _box(BG_HOVER, OUTLINE, 3))
	add_theme_stylebox_override("pressed", _box(BG_PRESSED, OUTLINE, 3))
	add_theme_stylebox_override("focus", _box(BG_HOVER, OUTLINE, 3))
	add_theme_stylebox_override("disabled", _box(BG, OUTLINE_IDLE, 2))
	_style_popup()
	if Engine.is_editor_hint():
		return
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)
	item_selected.connect(_on_item_selected)
	var popup := get_popup()
	popup.about_to_popup.connect(_on_popup_opening)
	popup.popup_hide.connect(_on_popup_closing)

func _on_hover() -> void:
	if disabled:
		return
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
	_animate_scale(1.06)

func _on_unhover() -> void:
	_animate_scale(1.0)

func _animate_scale(target: float) -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(target, target), 0.18)

func _on_item_selected(_index: int) -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)
	UltraUiFx.vibrate(self)

func _on_popup_opening() -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)
	_punch()

func _on_popup_closing() -> void:
	_animate_scale(1.0 if has_focus() else 1.0)

func _punch() -> void:
	pivot_offset = size / 2.0
	if _scale_tween and _scale_tween.is_running():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_scale_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	_scale_tween.tween_property(self, "scale", Vector2(1.06, 1.06), 0.12)

func _box(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(14)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0.078431, 0.137255, 0.227451, 0.8)
	s.shadow_size = 0
	return s

func _style_popup() -> void:
	var popup := get_popup()
	var panel := StyleBoxFlat.new()
	panel.bg_color = POPUP_BG
	panel.border_color = OUTLINE
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(14)
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	panel.shadow_color = Color(0.078431, 0.137255, 0.227451, 0.85)
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 5)
	popup.add_theme_stylebox_override("panel", panel)

	var hover := StyleBoxFlat.new()
	hover.bg_color = BG_HOVER
	hover.set_corner_radius_all(10)
	hover.content_margin_left = 8
	hover.content_margin_right = 8
	popup.add_theme_stylebox_override("hover", hover)

	var separator := StyleBoxFlat.new()
	separator.bg_color = Color(0.32, 0.5, 0.69, 0.5)
	separator.content_margin_top = 1
	separator.content_margin_bottom = 1
	popup.add_theme_stylebox_override("separator", separator)

	popup.add_theme_font_override("font", FONT)
	popup.add_theme_font_size_override("font_size", 22)
	popup.add_theme_color_override("font_color", CREAM)
	popup.add_theme_color_override("font_hover_color", Color.WHITE)
	popup.add_theme_color_override("font_accelerator_color", CREAM)
	popup.add_theme_color_override("font_separator_color", CREAM)
	popup.add_theme_constant_override("v_separation", 6)
