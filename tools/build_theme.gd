extends SceneTree

## One-off tool: builds the Ultravibe UI theme (pixel font + rounded blue
## buttons / sliders / panels / dropdowns) and saves it to
## res://assets/ui/ultravibe_theme.tres. Run with:
##   godot --path <project> --headless --script res://tools/build_theme.gd

const FONT_PATH := "res://assets/fonts/boldpixels.ttf"
const OUT_PATH := "res://assets/ui/ultravibe_theme.tres"

const BLUE := Color("3f80d6")
const BLUE_HOVER := Color("5a97e6")
const BLUE_PRESSED := Color("2f63ad")
const WHITE := Color("f2f6ff")
const PANEL_BG := Color(0.1, 0.16, 0.23, 0.96)
const PANEL_BORDER := Color(0.32, 0.47, 0.63, 1.0)
const TRACK := Color(0.86, 0.9, 0.98, 1.0)
const TRACK_BG := Color(0.2, 0.28, 0.38, 1.0)

func _make_box(bg: Color, border: Color, radius: int, border_w: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(border_w)
	box.border_color = border
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18.0
	box.content_margin_right = 18.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 12.0
	return box

func _initialize() -> void:
	var theme := Theme.new()
	var font := load(FONT_PATH)
	if font:
		theme.default_font = font
	theme.default_font_size = 24

	# --- Buttons (also OptionButton inherits Button styles when set) ---
	var btn_types := ["Button", "OptionButton"]
	for t in btn_types:
		theme.set_stylebox("normal", t, _make_box(BLUE, WHITE, 10, 3))
		theme.set_stylebox("hover", t, _make_box(BLUE_HOVER, WHITE, 10, 3))
		theme.set_stylebox("pressed", t, _make_box(BLUE_PRESSED, WHITE, 10, 3))
		theme.set_stylebox("focus", t, _make_box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.5), 10, 2))
		theme.set_stylebox("disabled", t, _make_box(Color(0.3, 0.34, 0.4, 0.8), Color(0.5, 0.55, 0.62), 10, 2))
		theme.set_color("font_color", t, WHITE)
		theme.set_color("font_hover_color", t, Color.WHITE)
		theme.set_color("font_pressed_color", t, Color(0.9, 0.94, 1.0))
		theme.set_font("font", t, font)
		theme.set_font_size("font_size", t, 24)

	# --- Labels ---
	theme.set_color("font_color", "Label", WHITE)
	theme.set_font("font", "Label", font)
	theme.set_font_size("font_size", "Label", 24)

	# --- Panels ---
	var panel_box := _make_box(PANEL_BG, PANEL_BORDER, 16, 2)
	panel_box.content_margin_left = 32.0
	panel_box.content_margin_right = 32.0
	panel_box.content_margin_top = 26.0
	panel_box.content_margin_bottom = 26.0
	theme.set_stylebox("panel", "Panel", panel_box)
	theme.set_stylebox("panel", "PanelContainer", panel_box)

	# --- HSlider: white rounded track + blue fill (thickness via content margins) ---
	var track := _make_box(TRACK, Color(0.55, 0.62, 0.72, 1), 10, 1)
	track.content_margin_left = 4.0
	track.content_margin_right = 4.0
	track.content_margin_top = 9.0
	track.content_margin_bottom = 9.0
	var fill := _make_box(BLUE, Color(0, 0, 0, 0), 10, 0)
	fill.content_margin_left = 4.0
	fill.content_margin_right = 4.0
	fill.content_margin_top = 9.0
	fill.content_margin_bottom = 9.0
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	theme.set_constant("grabber_offset", "HSlider", 0)

	# --- OptionButton popup readability ---
	theme.set_stylebox("panel", "PopupMenu", _make_box(PANEL_BG, PANEL_BORDER, 10, 2))
	theme.set_color("font_color", "PopupMenu", WHITE)
	theme.set_font("font", "PopupMenu", font)

	var err := ResourceSaver.save(theme, OUT_PATH)
	if err == OK:
		print("[OK] theme saved -> %s" % OUT_PATH)
	else:
		print("[ERR] save failed: %d" % err)
	quit(0 if err == OK else 1)
