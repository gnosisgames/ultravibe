@tool
class_name BBCodeEffectTextCombine
extends RichTextLabel

@export var text_clean: String = "":
	set(new_text_clean):
		text_clean = new_text_clean
		_update_text()

@export var bbcode: String = "":
	set(new_bbcode):
		bbcode = new_bbcode
		_update_text()

func _ready() -> void:
	_update_text()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_text()

func _update_text() -> void:
	if not "%s" in bbcode:
		return
	text = bbcode % tr(text_clean)
