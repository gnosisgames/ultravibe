class_name UltravibeHoldRestartProgress
extends GnosisHoldRestartProgress

## Ultravibe skin for the hold-to-restart corner panel (static purple HUD chrome).

const PANEL_BG := Color(0.345098, 0.345098, 0.572549, 1)
const PANEL_BORDER := Color(0.180392, 0.160784, 0.321569, 1)
const PANEL_SHADOW := PANEL_BORDER
const TRACK_COLOR := Color(0.180392, 0.160784, 0.321569, 0.85)


func _apply_panel_style() -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.border_color = PANEL_BORDER
	box.shadow_color = PANEL_SHADOW
	box.set_border_width_all(3)
	box.set_corner_radius_all(PANEL_RADIUS)
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 7)
	box.content_margin_left = int(PANEL_PADDING)
	box.content_margin_top = int(PANEL_PADDING)
	box.content_margin_right = int(PANEL_PADDING)
	box.content_margin_bottom = int(PANEL_PADDING)
	add_theme_stylebox_override("panel", box)
	_track_color = TRACK_COLOR
	if _ring:
		_ring.queue_redraw()


func _refresh_theme_if_needed() -> void:
	pass
