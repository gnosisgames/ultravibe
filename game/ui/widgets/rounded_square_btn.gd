@tool
class_name RoundedSquareBtn
extends Button

signal hovered()
signal unhovered()

@export var hover_animate: bool = true
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
	if disabled:
		return
	unhovered.emit()
	pivot_offset = size / 2.0
	if not hover_animate:
		return
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", 1.0, 0.25)
	tween.parallel().tween_property(self, "scale:y", 1.0, 0.35)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func _on_pressed() -> void:
	if not silent:
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)
