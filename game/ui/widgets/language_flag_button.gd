class_name LanguageFlagButton
extends Button

## Flag tile for the language picker. Custom-drawn rounded panel with a cream
## outline (thicker + glowing when selected), drop shadow, and a button-style
## scale pop on hover/focus. Routes SFX/haptics through UltraUiFx.

const OUTLINE_ON := Color(0.992157, 0.894118, 0.72549, 1.0)
const OUTLINE_HOVER := Color(0.6, 0.78, 1.0, 1.0)
const OUTLINE_IDLE := Color(0.207843, 0.262745, 0.380392, 1.0)

@export var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _flag_texture: Texture2D = null
var _tween: Tween

func set_flag(texture: Texture2D) -> void:
	_flag_texture = texture
	queue_redraw()

func _ready() -> void:
	focus_mode = FOCUS_ALL
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	# Suppress the Button's built-in styleboxes (notably the blue focus
	# outline) so only our custom _draw frame is visible.
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)
	pressed.connect(_on_pressed)

func _on_hover() -> void:
	if disabled:
		return
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)
	queue_redraw()
	pivot_offset = size / 2.0
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.2)
	_tween.parallel().tween_property(self, "rotation_degrees", 4.0 * [-1.0, 1.0].pick_random(), 0.1)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func _on_unhover() -> void:
	queue_redraw()
	pivot_offset = size / 2.0
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func _on_pressed() -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)

func _draw() -> void:
	if _flag_texture == null:
		return
	var pad := 5.0
	var avail := Rect2(Vector2(pad, pad), size - Vector2(pad * 2.0, pad * 2.0))
	if avail.size.x <= 1.0 or avail.size.y <= 1.0:
		return

	# The flag textures already ship as finished tiles (rounded corners + their
	# own outline), so the flag itself IS the button. We only fit it to the
	# cell and add a cream selection ring; hover juice is the scale tween.
	var tex_size := Vector2(_flag_texture.get_width(), _flag_texture.get_height())
	var scale := minf(avail.size.x / tex_size.x, avail.size.y / tex_size.y)
	var draw_size := tex_size * scale
	var flag_rect := Rect2(avail.position + (avail.size - draw_size) * 0.5, draw_size)
	var radius := int(draw_size.y * 0.15)

	var hovered := has_focus()
	var dimmed := not (selected or hovered)
	draw_texture_rect(_flag_texture, flag_rect, false, Color(0.72, 0.76, 0.82, 1.0) if dimmed else Color.WHITE)

	# Recolor the flag's own baked edge instead of adding a ring outside it, so
	# only a single frame ever shows. Border is drawn inside the flag rect.
	var border := StyleBoxFlat.new()
	border.draw_center = false
	border.set_corner_radius_all(radius)
	if selected:
		border.border_color = OUTLINE_ON
		border.set_border_width_all(5)
	elif hovered:
		border.border_color = OUTLINE_HOVER
		border.set_border_width_all(5)
	else:
		border.border_color = OUTLINE_IDLE
		border.set_border_width_all(3)
	draw_style_box(border, flag_rect)
