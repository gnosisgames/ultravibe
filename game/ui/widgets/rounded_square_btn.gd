@tool
class_name RoundedSquareBtn
extends Button

const ThemeUiScript := preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/widgets/gnosis_theme_ui.gd")

signal hovered()
signal unhovered()

@export var hover_animate: bool = true
@export var destructive: bool = false
@export var accent: bool = false
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
var _theme_id: String = "__unset__"

@onready var icon_texturerect: TextureRect = $Icon
@onready var rich_text_label: RichTextLabel = $RichTextLabel
@onready var tooltip_popup: PanelContainer = %TooltipPopup

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	focus_mode = FOCUS_ALL
	icon_texturerect.visible = show_icon
	%TooltipPopup.text = text_tooltip
	focus_entered.connect(hover)
	focus_exited.connect(unhover)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)
	_apply_theme_styles(true)


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	if what == NOTIFICATION_DISABLED:
		_reset_hover_visual(true)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_apply_theme_styles()

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


func _apply_theme_styles(force: bool = false) -> void:
	var theme_service = ThemeUiScript.resolve_theme_service(self)
	var theme_id: String = str(theme_service.get_current_theme_id()) if theme_service else ""
	if not force and theme_id == _theme_id and not destructive and not accent:
		return
	_theme_id = theme_id

	if destructive:
		_apply_destructive_theme_styles()
		return
	if accent:
		_apply_accent_theme_styles(theme_service)
		return

	var bg := ThemeUiScript.button_normal_bg(theme_service, theme_id)
	var neon := ThemeUiScript.button_active_color(theme_service)
	var shadow := ThemeUiScript.button_shadow_color(theme_service)
	var normal_border := ThemeUiScript.button_normal_border_color(theme_service, theme_id)
	var focus_border := neon.lightened(0.45)
	var normal_border_width := 2 if normal_border.a > 0.0 else 0

	add_theme_stylebox_override("normal", _build_style(bg, shadow, normal_border_width, normal_border))
	add_theme_stylebox_override("pressed", _build_style(neon, shadow))
	add_theme_stylebox_override("hover", _build_style(neon, shadow))
	add_theme_stylebox_override("disabled", _build_style(bg.darkened(0.28), shadow.darkened(0.22)))
	add_theme_stylebox_override("focus", _build_style(neon, shadow, 4, focus_border))


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


func _apply_accent_theme_styles(theme_service) -> void:
	var neon := ThemeUiScript.button_active_color(theme_service)
	var shadow := ThemeUiScript.button_shadow_color(theme_service)
	var normal := neon.darkened(0.10)
	var hover := neon.lightened(0.10)
	var pressed := neon.darkened(0.24)
	var border := neon.lightened(0.22)
	var focus_border := Color.WHITE.lerp(neon, 0.4).lightened(0.15)
	add_theme_stylebox_override("normal", _build_style(normal, shadow, 2, border))
	add_theme_stylebox_override("hover", _build_style(hover, shadow, 2, border.lightened(0.1)))
	add_theme_stylebox_override("pressed", _build_style(pressed, shadow, 2, border.darkened(0.06)))
	var status_bg := ThemeUiScript.tray_bg_color(theme_service).lightened(0.10)
	var status_border := border.darkened(0.42)
	add_theme_stylebox_override(
		"disabled",
		_build_style(status_bg, shadow.darkened(0.28), 2, status_border)
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
