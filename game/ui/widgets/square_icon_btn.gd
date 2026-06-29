@tool
class_name SquareIconBtn
extends Button

enum SHORTCUT_SIDE { RIGHT, LEFT, ABSOLUTE }

@export var animate_hover: bool = true
@export var show_shortcut: bool = true:
	set(new_show_shortcut):
		show_shortcut = new_show_shortcut
		if is_inside_tree() and is_instance_valid(panel_container):
			panel_container.visible = show_shortcut
@export var shortcut_text: String = "KEY":
	set(new_val):
		shortcut_text = new_val
		if is_inside_tree() and is_instance_valid(label):
			label.text = shortcut_text

var tween: Tween

@onready var panel_container: PanelContainer = $PanelContainer
@onready var label: Label = $PanelContainer/Label

func _ready() -> void:
	if not show_shortcut:
		panel_container.hide()
	label.text = shortcut_text
	focus_entered.connect(hover)
	focus_exited.connect(unhover)
	mouse_entered.connect(grab_focus)
	mouse_exited.connect(release_focus)

func hover() -> void:
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -4.0)
	if not animate_hover:
		return
	pivot_offset = size / 2.0
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", 1.2, 0.25)
	tween.parallel().tween_property(self, "scale:y", 1.2, 0.35)
	tween.parallel().tween_property(self, "rotation_degrees", 5.0 * [-1.0, 1.0].pick_random(), 0.1)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func unhover() -> void:
	pivot_offset = size / 2.0
	if not animate_hover:
		return
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale:x", 1.0, 0.25)
	tween.parallel().tween_property(self, "scale:y", 1.0, 0.35)
	tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func _on_pressed() -> void:
	if disabled:
		return
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)
