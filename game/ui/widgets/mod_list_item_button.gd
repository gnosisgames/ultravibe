class_name ModListItemButton
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/widgets/gnosis_mod_list_item.gd"

## Ultravibe mod row: Comic Lemon font + UltraUiFx juice.

const UI_FONT := preload("res://assets/fonts/Comic Lemon.otf")

func _resolve_font() -> Font:
	return UI_FONT

func _on_list_hover() -> void:
	if disabled:
		return
	UltraUiFx.vibrate(self)
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_HOVER, -6.0)

func _on_list_pressed() -> void:
	UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED)

func _play_hover_juice() -> void:
	if disabled:
		return
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	var scale_ratio := clampf(128.0 / maxf(size.x, 1.0), 0.5, 1.0)
	var scale_target := 1.0 + 0.06 * scale_ratio
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(scale_target, scale_target), 0.18)
	_tween.parallel().tween_property(self, "rotation_degrees", 2.5 * scale_ratio * [-1.0, 1.0].pick_random(), 0.1)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1).set_delay(0.1)

func _play_unhover_juice() -> void:
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.2)
	_tween.parallel().tween_property(self, "rotation_degrees", 0.0, 0.1)

func _play_selected_pulse() -> void:
	pivot_offset = size * 0.5
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.14)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
