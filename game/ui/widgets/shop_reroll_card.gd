class_name ShopRerollCard
extends VBoxContainer

## Shuffle-style refresh control for the shop row: title, icon button, price below.

const JuicyFocus = preload("res://game/ui/widgets/juicy_focus.gd")

const REFRESH_ICON := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/refresh.png"
const BUTTON_SIZE := Vector2(120, 120)
const ICON_MAX := 72
const GOLD := Color(0.937255, 0.74902, 0.0156863, 1)
const WHITE := Color(1, 1, 1, 1)
const TITLE_COLOR := Color(0.929412, 0.941176, 0.972549, 1)
const BTN_GREEN := Color(0.298039, 0.686275, 0.313725, 1)
const BTN_GREEN_PRESSED := Color(0.219608, 0.556863, 0.235294, 1)
const BTN_GREEN_HOVER := Color(0.356863, 0.784314, 0.372549, 1)
const BTN_GREEN_SHADOW := Color(0.117647, 0.333333, 0.12549, 1)
const BTN_GREEN_BORDER := Color(0.45098, 0.901961, 0.470588, 1)
const DISABLED_FILL := Color(0.52, 0.52, 0.56, 1)
const DISABLED_SHADOW := Color(0.34, 0.34, 0.36, 1)

signal reroll_pressed

var _button: Button = null


func _init() -> void:
	custom_minimum_size = Vector2(ShopOfferCard.TILE_WIDTH, ShopOfferCard.TILE_HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 8)


func configure(font: Font, title: String, price_label: String, enabled: bool) -> void:
	for child in get_children():
		child.queue_free()

	var title_label := Label.new()
	title_label.text = title.strip_edges().to_upper()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		title_label.add_theme_font_override("font", font)
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", TITLE_COLOR if enabled else Color(0.72, 0.72, 0.76, 1))
	add_child(title_label)

	_button = Button.new()
	_button.disabled = not enabled
	_button.focus_mode = Control.FOCUS_ALL
	_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_button.custom_minimum_size = BUTTON_SIZE
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.text = ""
	_button.icon = load(REFRESH_ICON)
	_button.expand_icon = true
	_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_button.add_theme_constant_override("icon_max_width", ICON_MAX)
	_button.add_theme_color_override("icon_normal_color", WHITE)
	_button.add_theme_color_override("icon_hover_color", WHITE)
	_button.add_theme_color_override("icon_pressed_color", WHITE)
	_button.add_theme_color_override("icon_disabled_color", Color(0.78, 0.78, 0.82, 1))
	_apply_button_styles(_button, enabled)
	_button.pressed.connect(func() -> void:
		JuicyFocus.play_pressed(_button)
		reroll_pressed.emit()
	)
	JuicyFocus.wire(_button, enabled, enabled, BUTTON_SIZE.x, true, false)
	add_child(_button)

	var price := Label.new()
	price.text = price_label if not price_label.is_empty() else "$0"
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		price.add_theme_font_override("font", font)
	price.add_theme_font_size_override("font_size", 27)
	price.add_theme_color_override("font_color", GOLD if enabled else Color(0.72, 0.72, 0.76, 1))
	add_child(price)


func _apply_button_styles(btn: Button, enabled: bool) -> void:
	if enabled:
		btn.add_theme_stylebox_override("normal", _button_style(BTN_GREEN, BTN_GREEN_SHADOW))
		btn.add_theme_stylebox_override("hover", _button_style(BTN_GREEN_HOVER, BTN_GREEN_SHADOW, true))
		btn.add_theme_stylebox_override("pressed", _button_style(BTN_GREEN_PRESSED, BTN_GREEN_SHADOW))
		btn.add_theme_stylebox_override("focus", _button_style(BTN_GREEN_HOVER, BTN_GREEN_SHADOW, true))
	else:
		btn.add_theme_stylebox_override("normal", _button_style(DISABLED_FILL, DISABLED_SHADOW))
		btn.add_theme_stylebox_override("hover", _button_style(DISABLED_FILL, DISABLED_SHADOW))
		btn.add_theme_stylebox_override("pressed", _button_style(DISABLED_FILL, DISABLED_SHADOW))
		btn.add_theme_stylebox_override("focus", _button_style(DISABLED_FILL, DISABLED_SHADOW))


func _button_style(bg: Color, shadow: Color, outlined: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(16)
	box.corner_detail = 12
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	box.shadow_color = shadow
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 4)
	if outlined:
		box.set_border_width_all(4)
		box.border_color = BTN_GREEN_BORDER
	return box
