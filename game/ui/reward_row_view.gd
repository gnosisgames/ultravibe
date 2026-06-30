class_name RewardRowView
extends PanelContainer

## Single round-reward row (Unity RoundRewardLineView parity): localized reason on
## the left, animated <c>$</c> glyphs on the right.

const ROW_FONT := preload("res://assets/fonts/Comic Lemon.otf")
const ROW_BG := Color(0.345098, 0.345098, 0.572549, 1)
const MONEY_COLOR := Color(0.937255, 0.74902, 0.0156863, 1)
const GLYPH_STAGGER_SEC := 0.055

var _reason_label: Label
var _money_label: Label

func _init() -> void:
	custom_minimum_size = Vector2(0, 64)
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_BG
	box.set_corner_radius_all(14)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 32)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(hbox)

	_reason_label = Label.new()
	_reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.add_theme_color_override("font_color", Color.WHITE)
	_reason_label.add_theme_font_override("font", ROW_FONT)
	_reason_label.add_theme_font_size_override("font_size", 28)
	hbox.add_child(_reason_label)

	_money_label = Label.new()
	_money_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_money_label.add_theme_color_override("font_color", MONEY_COLOR)
	_money_label.add_theme_font_override("font", ROW_FONT)
	_money_label.add_theme_font_size_override("font_size", 32)
	hbox.add_child(_money_label)


static func format_money_glyphs(amount: int) -> String:
	return "$".repeat(maxi(0, amount))


func reveal_line(reason: String, amount: int, animate_money: bool) -> void:
	if not is_inside_tree():
		await ready
	_reason_label.text = reason
	var glyphs := format_money_glyphs(amount)
	if not animate_money or glyphs.is_empty():
		_money_label.text = glyphs
		return
	_money_label.text = ""
	var tree := get_tree()
	if tree == null:
		_money_label.text = glyphs
		return
	var count := glyphs.length()
	for i in range(count):
		_money_label.text = glyphs.substr(0, i + 1)
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_BOP, -10.0)
		if i < count - 1:
			await tree.create_timer(GLYPH_STAGGER_SEC).timeout
