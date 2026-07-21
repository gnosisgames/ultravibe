class_name UltraUiPalette
extends RefCounted

## Shared Ultravibe blue UI palette.

const CREAM := Color(1, 1, 1, 1)
const NAVY_SHADOW := Color("313145")
const DARK_BLUE_BASE := Color("2a3550")
const BLUE_ACCENT := Color("3f80d6")
const BLUE_HOVER := Color("5a97e6")
const BLUE_PRESSED := Color("2f63ad")
const BLUE_SHADOW := Color("14233a")
## Matches RoundedSquareBtn hover/focus border — used for panel drop shadows.
const PURPLE_DARK := Color(0.180392, 0.160784, 0.321569, 1)
const PANEL_SHADOW := PURPLE_DARK
const PANEL_BG := Color(0.1, 0.16, 0.23, 0.96)
const PANEL_BORDER := Color("5180a0")
const PILL_DARK := Color(0.156863, 0.196078, 0.290196, 1)
const PILL_RADIUS := 14
const PILL_PAD_H := 12


static func stat_pill_style(vertical_pad: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PILL_DARK
	box.set_corner_radius_all(PILL_RADIUS)
	box.content_margin_left = PILL_PAD_H
	box.content_margin_right = PILL_PAD_H
	box.content_margin_top = vertical_pad
	box.content_margin_bottom = vertical_pad
	box.shadow_color = BLUE_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 4)
	return box
