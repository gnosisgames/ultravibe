@tool
class_name RoundedSquareBtn
extends Button

signal hovered()
signal unhovered()

## Ultravibe menu purple — scene/tscn styles use these; never synced from gameplay theme.
const UI_NORMAL := Color(0.345098, 0.345098, 0.572549, 1.0)
const UI_PRESSED := Color(0.278431, 0.278431, 0.439216, 1.0)
const UI_SHADOW := Color(0.08, 0.04, 0.12, 1.0)
const UI_FOCUS_BORDER := Color(0.180392, 0.160784, 0.321569, 1.0)

@export var hover_animate: bool = true
@export var interactive: bool = true
@export var destructive: bool = false
@export var accent: bool = false
## When true, keep scene-authored style overrides (e.g. gameplay HUD shuffle pink).
@export var use_fixed_styles: bool = false
@export var text_tooltip: String = "":
	set(new_text):
		text_tooltip = new_text
		if is_inside_tree() and has_node("%TooltipPopup"):
			%TooltipPopup.text = text_tooltip
@export var show_icon: bool = false
@export var scale_w_width: bool = true

var tween: Tween
var silent: bool = false
var width_full_rot: float = 128.0

@onready var icon_texturerect: TextureRect = $Icon
@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var tooltip_popup: PanelContainer = %TooltipPopup

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not interactive:
		focus_mode = FOCUS_NONE
		mouse_filter = MOUSE_FILTER_IGNORE
		hover_animate = false
		tooltip_text = ""
		if has_node("%TooltipPopup"):
			var popup: TooltipPopup = %TooltipPopup
			popup.active = false
			popup.appear_auto = false
			popup.appear_when_disabled = false
		_apply_variant_styles()
		return
	focus_mode = FOCUS_ALL
	icon_texturerect.visible = show_icon
	%TooltipPopup.text = text_tooltip
	focus_entered.connect(hover)
	focus_exited.connect(unhover)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)
	_apply_variant_styles()


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == NOTIFICATION_DISABLED:
		_reset_hover_visual(true)


func grab_focus_silent() -> void:
	silent = true
	grab_focus()
	set_deferred("silent", false)

func hover() -> void:
	if disabled:
		return
	hovered.emit()
	UltraUiFx.vibrate(self)
	if not silent:
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	if not hover_animate:
		return
	pivot_offset = size / 2.0
	var scale_ratio := clampf(width_full_rot / size.x, 0.5, 1.0)
	var scale_target := 1.0 + 0.2 * scale_ratio
	if not scale_w_width:
		scale_target = 1.2
		scale_ratio = 1.0
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", scale_target, 0.2)
	tween.parallel().tween_property(self, "scale:y", scale_target, 0.35)
	tween.parallel().tween_property(self, "rotation_degrees", 5.0 * scale_ratio * [-1.0, 1.0].pick_random(), 0.1)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func unhover() -> void:
	if not disabled:
		unhovered.emit()
	if not hover_animate:
		_reset_hover_visual(true)
		return
	if tween and tween.is_running():
		tween.kill()
	pivot_offset = size / 2.0
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)


func _reset_hover_visual(instant: bool = false) -> void:
	if tween and tween.is_running():
		tween.kill()
		tween = null
	if instant:
		scale = Vector2.ONE
		rotation_degrees = 0.0
		pivot_offset = Vector2.ZERO
		return
	pivot_offset = size / 2.0
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func _on_pressed() -> void:
	if not silent:
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)


func _apply_variant_styles() -> void:
	if use_fixed_styles:
		return
	if destructive:
		_apply_destructive_theme_styles()
	elif accent:
		_apply_accent_theme_styles()


## Engine profiles view refreshes tab chrome after clearing overrides.
func _apply_theme_styles(_force: bool = false) -> void:
	_apply_variant_styles()


func _apply_destructive_theme_styles() -> void:
	var normal := Color(0.58, 0.14, 0.16, 1.0)
	var hover := Color(0.72, 0.18, 0.20, 1.0)
	var pressed := Color(0.46, 0.10, 0.12, 1.0)
	var shadow := Color(0.18, 0.05, 0.07, 1.0)
	var border := Color(0.88, 0.28, 0.30, 1.0)
	var focus_border := Color(0.98, 0.52, 0.52, 1.0)
	add_theme_stylebox_override("normal", _build_style(normal, shadow, 2, border))
	add_theme_stylebox_override("hover", _build_style(hover, shadow, 2, border.lightened(0.12)))
	add_theme_stylebox_override("pressed", _build_style(pressed, shadow, 2, border.darkened(0.08)))
	add_theme_stylebox_override(
		"disabled",
		_build_style(normal.darkened(0.28), shadow.darkened(0.22), 2, border.darkened(0.25))
	)
	add_theme_stylebox_override("focus", _build_style(hover, shadow, 3, focus_border))
	var label := Color.WHITE
	add_theme_color_override("font_color", label)
	add_theme_color_override("font_hover_color", label)
	add_theme_color_override("font_pressed_color", label)
	add_theme_color_override("font_focus_color", label)
	add_theme_color_override("font_hover_pressed_color", label)
	add_theme_color_override("font_disabled_color", Color(0.72, 0.72, 0.72, 1))
	add_theme_color_override("icon_normal_color", label)
	add_theme_color_override("icon_hover_color", label)
	add_theme_color_override("icon_pressed_color", label)
	add_theme_color_override("icon_focus_color", label)
	add_theme_color_override("icon_disabled_color", Color(0.55, 0.55, 0.55, 1))


func _apply_accent_theme_styles() -> void:
	var normal := UI_NORMAL
	var hover := UI_PRESSED.lightened(0.08)
	var pressed := UI_PRESSED
	var shadow := UI_SHADOW
	var border := UI_FOCUS_BORDER
	var focus_border := Color.WHITE.lerp(UI_NORMAL, 0.35).lightened(0.12)
	add_theme_stylebox_override("normal", _build_style(normal, shadow, 2, border))
	add_theme_stylebox_override("hover", _build_style(hover, shadow, 2, border.lightened(0.1)))
	add_theme_stylebox_override("pressed", _build_style(pressed, shadow, 2, border.darkened(0.06)))
	add_theme_stylebox_override(
		"disabled",
		_build_style(normal.darkened(0.28), shadow.darkened(0.22), 2, border.darkened(0.25))
	)
	add_theme_stylebox_override("focus", _build_style(hover, shadow, 3, focus_border))
	var label := Color.WHITE
	add_theme_color_override("font_color", label)
	add_theme_color_override("font_hover_color", label)
	add_theme_color_override("font_pressed_color", label)
	add_theme_color_override("font_focus_color", label)
	add_theme_color_override("font_hover_pressed_color", label)
	add_theme_color_override("font_disabled_color", Color(0.70, 0.78, 0.88, 1))


func _build_style(
	bg: Color,
	shadow: Color,
	border_width: int = 0,
	border_color: Color = Color.TRANSPARENT
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.bg_color = bg
	style.set_corner_radius_all(16)
	style.corner_detail = 12
	style.shadow_color = shadow
	style.shadow_size = 1
	style.shadow_offset = Vector2(3, 4)
	if border_width > 0:
		style.set_border_width_all(border_width)
		style.border_color = border_color
	return style
