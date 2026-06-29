@tool
class_name TooltipPopup
extends PanelContainer

## Shared tooltip popup for the whole app. The visual skin (dark navy panel,
## blue border, cream body card, white title) and the semantic accent palette
## live here so every tooltip — collection, reward slots, and any future
## screen / sibling game — looks identical. Consumers should call
## `set_content()` rather than styling the popup themselves.

enum PIVOT_SIDE { TOP, BOTTOM, LEFT, RIGHT }

## Default body width used when a consumer does not request one explicitly.
const DEFAULT_CONTENT_WIDTH := 300.0

## Semantic rich-text tags in localized strings -> accent colors. Mirrors Unity
## Rewired tooltip palette (game.unity semanticTags) so <money>, <move>, etc.
## render with the same accents as the Unity build.
const TAG_COLORS := {
	"money": "ecbe08",
	"multi": "cd2c58",
	"point": "346fda",
	"shuffle": "d58080",
	"chance": "2fa084",
	"move": "1591dc",
}

@export var text: String = "":
	set(new_text):
		text = new_text
		if description:
			description.text = new_text
@export var title_text: String = "":
	set(new_title_text):
		title_text = new_title_text
		var title_node := get_node_or_null("ContainerFree/Title") as RichTextLabel
		if title_node:
			title_node.text = new_title_text
			title_node.visible = title_text != ""
@export var auto_resize: bool = false
@export var appear_when_disabled: bool = true
@export var appear_auto: bool = false
@export var target: Button
@export var pivot_side: PIVOT_SIDE = PIVOT_SIDE.BOTTOM

var active: bool = true
var tween_tooltip: Tween
var title_label: RichTextLabel = null

@onready var description: RichTextLabel = $MarginContainer/VBoxContainer/Description

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	apply_standard_skin()
	show()
	scale = Vector2.ZERO
	if appear_auto and target:
		target.focus_entered.connect(appear)
		target.focus_exited.connect(disappear)
	_set_pivot_point()
	if auto_resize:
		await get_tree().process_frame
		description.autowrap_mode = TextServer.AUTOWRAP_OFF
		var diff := position + size
		size = Vector2.ZERO
		await get_tree().process_frame
		position = -size + diff

## Applies the canonical app-wide tooltip skin. Idempotent and safe to call
## more than once. Builds the outer panel, the cream body card, and the white
## title label that sits above the body.
func apply_standard_skin() -> void:
	if description == null:
		return

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.156863, 0.211765, 0.32549)
	panel.set_border_width_all(4)
	panel.border_color = Color(0.345098, 0.345098, 0.572549)
	panel.set_corner_radius_all(16)
	panel.content_margin_left = 16.0
	panel.content_margin_top = 12.0
	panel.content_margin_right = 16.0
	panel.content_margin_bottom = 16.0
	panel.shadow_color = Color(0.0784314, 0.137255, 0.227451, 0.6)
	panel.shadow_size = 4
	panel.shadow_offset = Vector2(3, 5)
	add_theme_stylebox_override("panel", panel)

	var body := StyleBoxFlat.new()
	body.bg_color = Color(0.972549, 0.956863, 0.921569)
	body.set_content_margin_all(12.0)
	body.corner_radius_top_right = 10
	body.corner_radius_bottom_right = 10
	body.corner_radius_bottom_left = 10
	description.add_theme_stylebox_override("normal", body)
	description.add_theme_color_override("default_color", Color(0.227451, 0.243137, 0.317647))
	description.bbcode_enabled = true

	var vbox := description.get_parent()
	if vbox and title_label == null:
		vbox.add_theme_constant_override("separation", 4)
		title_label = RichTextLabel.new()
		title_label.bbcode_enabled = true
		title_label.fit_content = true
		title_label.scroll_active = false
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_theme_color_override("default_color", Color(1, 1, 1))
		var title_font := description.get_theme_font("normal_font")
		if title_font:
			title_label.add_theme_font_override("normal_font", title_font)
		vbox.add_child(title_label)
		vbox.move_child(title_label, 0)

## Fills the tooltip with a title and a raw (un-formatted) description string.
## Semantic `<money>`/`<move>`/`<shuffle>`/`<multi>`/`<point>`/`<chance>` tags
## are converted to the shared accent colors automatically.
func set_content(title: String, description_raw: String, width: float = DEFAULT_CONTENT_WIDTH) -> void:
	if description == null:
		return
	description.fit_content = true
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(width, 0)
	title_text = ""
	if title_label:
		title_label.custom_minimum_size = Vector2(width, 0)
		title_label.visible = not title.strip_edges().is_empty()
		title_label.text = "[center][font_size=28]%s[/font_size][/center]" % title
	text = format_bbcode(description_raw)

## Converts the engine's semantic markup into bbcode with the shared palette.
static func format_bbcode(value: String) -> String:
	if value.strip_edges().is_empty():
		return ""
	var text_value := value
	var arg_re := RegEx.new()
	if arg_re.compile("\\$\\{arg:[^}]+\\}") == OK:
		text_value = arg_re.sub(text_value, "0", true)
	for tag in TAG_COLORS.keys():
		var color: String = TAG_COLORS[tag]
		text_value = text_value.replace("<%s>" % tag, "[color=#%s]" % color)
		text_value = text_value.replace("</%s>" % tag, "[/color]")
	return text_value

func _set_pivot_point() -> void:
	match pivot_side:
		PIVOT_SIDE.TOP:
			pivot_offset = Vector2(size.x / 2.0, 0.0)
		PIVOT_SIDE.BOTTOM:
			pivot_offset = Vector2(size.x / 2.0, size.y)
		PIVOT_SIDE.LEFT:
			pivot_offset = Vector2(0.0, size.y / 2.0)
		PIVOT_SIDE.RIGHT:
			pivot_offset = Vector2(size.x, size.y / 2.0)

func appear() -> void:
	if not active or description.text == "":
		return
	if target and target.disabled and not appear_when_disabled:
		return
	_set_pivot_point()
	if tween_tooltip and tween_tooltip.is_running():
		tween_tooltip.kill()
	tween_tooltip = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween_tooltip.tween_property(self, "scale:x", 1.0, 0.2)
	tween_tooltip.parallel().tween_property(self, "scale:y", 1.0, 0.15)

func disappear() -> void:
	if description.text == "":
		return
	_set_pivot_point()
	if tween_tooltip and tween_tooltip.is_running():
		tween_tooltip.kill()
	tween_tooltip = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween_tooltip.tween_property(self, "scale:x", 0.0, 0.25)
	tween_tooltip.parallel().tween_property(self, "scale:y", 0.0, 0.2)
