class_name LevelCardToken
extends PanelContainer

## Round / boss token pill overlapping the bottom edge of a level-select card.
## Normal/advanced show -N-; boss rounds show the starting letter with boss accent color.

const TOKEN_BG := Color(0.929412, 0.941176, 0.972549, 1)
const TOKEN_SHADOW := Color(0.72, 0.76, 0.84, 1)
const DEFAULT_ACCENT := Color(0.156863, 0.196078, 0.290196, 1)

const TOKEN_FONT_SIZE := 24
const TOKEN_RADIUS := 14
const TOKEN_PAD_H := 22
const TOKEN_PAD_V := 6


static func build(display_text: String, accent: Color, font: Font, boss_font: Font = null) -> PanelContainer:
	var token_script: GDScript = load("res://game/ui/widgets/level_card_token.gd") as GDScript
	var token: PanelContainer = token_script.new() as PanelContainer
	if token.has_method("configure"):
		token.call("configure", display_text, accent, font, boss_font)
	return token


func configure(display_text: String, accent: Color, font: Font, boss_font: Font = null) -> void:
	for child in get_children():
		child.queue_free()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _token_style())

	var label := Label.new()
	label.text = display_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label_font := boss_font if boss_font != null else font
	if label_font:
		label.add_theme_font_override("font", label_font)
	label.add_theme_font_size_override("font_size", TOKEN_FONT_SIZE)
	label.add_theme_color_override("font_color", accent)
	add_child(label)


func _token_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = TOKEN_BG
	box.set_corner_radius_all(TOKEN_RADIUS)
	box.content_margin_left = TOKEN_PAD_H
	box.content_margin_right = TOKEN_PAD_H
	box.content_margin_top = TOKEN_PAD_V
	box.content_margin_bottom = TOKEN_PAD_V
	box.shadow_color = TOKEN_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 4)
	return box
