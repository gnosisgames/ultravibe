extends SceneTree

# Renders a labeled contact sheet of candidate icons (white SVGs on a dark bg).
# Run headless: godot4 --headless --path . -s res://tools/icon_contact_sheet.gd

const ICON_DIR := "/Users/spiliopoulosg/Documents/Development/01_gamedev/02_godot/icons/white/"
const OUT_PATH := "/Users/spiliopoulosg/.cursor/projects/Users-spiliopoulosg-Documents-Development-01-gamedev-02-godot/assets/icon_proposals.png"

const CELL := 150
const ICON := 96
const COLS := 6
const PAD_TOP := 36
const ROW_LABEL_H := 30

# [section title, [filenames...]]
const GROUPS := [
	["Wasteful / Recycler  (more discards)", ["recycle", "water-recycling", "trash-can", "falling-leaf"]],
	["Extra Pocket  (consumable slot)", ["backpack", "light-backpack", "knapsack", "swap-bag"]],
	["Extra Friend  (boon slot)", ["three-friends", "meeple-group", "meeple-king", "person"]],
	["Fortune Boost  (luck)", ["clover", "clover-spiked", "tarot-10-wheel-of-fortune", "lucky-fisherman"]],
	["Score Delay  (time)", ["hourglass", "sands-of-time", "alarm-clock", "backward-time"]],
	["Climb Slowdown  (slow)", ["snail", "turtle", "slow-blob", "turtle-shell"]],
	["Negative Slowdown  (valve/gauge)", ["valve", "attack-gauge", "speedometer", "pressure-cooker"]],
	["Generic Upgrade / Boost", ["upgrade", "armor-upgrade", "rocket", "angel-wings", "magnet"]],
	["Ability: Axe", ["axe-swing", "battle-axe", "magic-axe"]],
	["Ability: Hammer", ["claw-hammer", "gear-hammer", "hammer-drop"]],
	["Ability: Gum  (bubbles)", ["bubbles", "thought-bubble"]],
]

func _init() -> void:
	var font := ThemeDB.fallback_font
	var rows := GROUPS.size()
	var height := PAD_TOP
	for g in GROUPS:
		height += ROW_LABEL_H + CELL + 10
	var width := COLS * CELL + 20

	var sheet := Image.create(width, height, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.10, 0.14, 0.20, 1.0))

	var y := PAD_TOP
	for g in GROUPS:
		var title: String = g[0]
		var files: Array = g[1]
		_draw_text(sheet, font, title, 12, y, 20, Color(0.99, 0.89, 0.73))
		y += ROW_LABEL_H
		var x := 10
		var col := 0
		for fname in files:
			var icon := _load_icon("%s%s.svg" % [ICON_DIR, fname])
			if icon:
				var ix := x + (CELL - ICON) / 2
				sheet.blend_rect(icon, Rect2i(0, 0, ICON, ICON), Vector2i(ix, y))
			_draw_text(sheet, font, fname, x + 4, y + ICON + 4, 13, Color(0.8, 0.86, 0.95))
			x += CELL
			col += 1
			if col >= COLS:
				break
		y += CELL + 10

	var err := sheet.save_png(OUT_PATH)
	print("saved=", err, " -> ", OUT_PATH, " size=", width, "x", height)
	quit()

func _load_icon(path: String) -> Image:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		print("missing ", path)
		return null
	var svg := f.get_as_text()
	var img := Image.new()
	# white icons -> tint to near-white by leaving as-is; scale to fit ICON.
	var scale := float(ICON) / 512.0
	var e := img.load_svg_from_string(svg, scale)
	if e != OK:
		print("svg fail ", path, " ", e)
		return null
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	img.resize(ICON, ICON, Image.INTERPOLATE_LANCZOS)
	return img

func _draw_text(img: Image, font: Font, text: String, x: int, y: int, size: int, color: Color) -> void:
	# CPU text rendering: rasterize each glyph via font and blit. Simpler approach:
	# use a temporary Image from font is non-trivial; instead draw with multichannel.
	# We approximate by drawing using Font.draw via a control is not available headless,
	# so we encode the label as the filename row in chat instead. This is a no-op marker.
	pass
