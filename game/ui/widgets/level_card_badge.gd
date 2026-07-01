class_name LevelCardBadge
extends PanelContainer

## Difficulty + required-score pill that overlaps the top edge of a level-select card.
## Skull count: 1 normal, 2 advanced, 3 boss. Boss rounds tint skulls/score with the
## level profile textColor (same accent as the HUD boss token).

const SKULL_ICON := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/skull-white.png"
const BADGE_BG := Color(0.929412, 0.941176, 0.972549, 1)
const BADGE_SHADOW := Color(0.72, 0.76, 0.84, 1)
const DEFAULT_ACCENT := Color(0.156863, 0.196078, 0.290196, 1)

const SKULL_SIZE := 30.0
const SKULL_GAP := 4
const SCORE_FONT_SIZE := 28
const BADGE_RADIUS := 18
const BADGE_PAD_H := 18
const BADGE_PAD_V := 8


static func build(
	skull_count: int,
	score_text: String,
	accent: Color,
	font: Font,
	overlap_height: float
) -> PanelContainer:
	var badge_script: GDScript = load("res://game/ui/widgets/level_card_badge.gd") as GDScript
	var badge: PanelContainer = badge_script.new() as PanelContainer
	if badge.has_method("configure"):
		badge.call("configure", maxi(1, skull_count), score_text, accent, font)
	if badge.has_method("set_overlap_height"):
		badge.call("set_overlap_height", overlap_height)
	return badge


func configure(skull_count: int, score_text: String, accent: Color, font: Font) -> void:
	for child in get_children():
		child.queue_free()

	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _badge_style())

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var skull_row := HBoxContainer.new()
	skull_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skull_row.alignment = BoxContainer.ALIGNMENT_CENTER
	skull_row.add_theme_constant_override("separation", SKULL_GAP)
	skull_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(skull_row)

	var skull_tex: Texture2D = load(SKULL_ICON)
	for _i in range(skull_count):
		var skull := TextureRect.new()
		skull.texture = skull_tex
		skull.custom_minimum_size = Vector2(SKULL_SIZE, SKULL_SIZE)
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skull.modulate = accent
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skull_row.add_child(skull)

	var score := Label.new()
	score.text = score_text
	score.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		score.add_theme_font_override("font", font)
	score.add_theme_font_size_override("font_size", SCORE_FONT_SIZE)
	score.add_theme_color_override("font_color", accent)
	vbox.add_child(score)


func set_overlap_height(height: float) -> void:
	set_meta("overlap_height", maxf(0.0, height))


func get_overlap_height() -> float:
	return float(get_meta("overlap_height", 0.0))


func _badge_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = BADGE_BG
	box.set_corner_radius_all(BADGE_RADIUS)
	box.content_margin_left = BADGE_PAD_H
	box.content_margin_right = BADGE_PAD_H
	box.content_margin_top = BADGE_PAD_V
	box.content_margin_bottom = BADGE_PAD_V
	box.shadow_color = BADGE_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 4)
	return box
