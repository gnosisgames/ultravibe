class_name AutoTween
extends Node

signal show_started()
signal hide_started()
signal show_finished()
signal hide_finished()

enum ANIM_WHEN { MANUAL, READY, VISIBLE, TRIGGER }
enum ANIM_TYPE { FADE, SCALE }
enum SCALE_FROM { CENTER, TOP_LEFT, TOP_CENTER, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }

@export var target: Control
@export var autotween_trigger: AutoTween = null
@export var anim_when: ANIM_WHEN = ANIM_WHEN.READY
@export var start_delay: float = -1.0
@export var anim_type: ANIM_TYPE = ANIM_TYPE.SCALE
@export var scale_from: SCALE_FROM = SCALE_FROM.CENTER
@export var duration: float = 0.2
@export var auto_hide_after: float = -1.0
@export var change_visible: bool = false
@export var force_from: bool = false

var tween: Tween
var ignore_visibility_change: bool = false

func _ready() -> void:
	if not target:
		target = get_parent() as Control
	target.set_meta("auto_animate", self)
	if anim_type == ANIM_TYPE.SCALE:
		_set_pivot(scale_from)
	match anim_type:
		ANIM_TYPE.FADE:
			target.modulate.a = 0.0
		ANIM_TYPE.SCALE:
			target.scale = Vector2.ZERO
	if anim_when == ANIM_WHEN.READY:
		await target.ready
		show()
	elif anim_when == ANIM_WHEN.VISIBLE:
		target.visibility_changed.connect(_on_target_visibility_changed)
	elif anim_when == ANIM_WHEN.TRIGGER:
		if autotween_trigger:
			autotween_trigger.show_started.connect(show)
			autotween_trigger.hide_started.connect(hide)

func _set_pivot(pivot: SCALE_FROM) -> void:
	match pivot:
		SCALE_FROM.CENTER:
			target.pivot_offset = target.size / 2.0
		SCALE_FROM.TOP_LEFT:
			target.pivot_offset = Vector2.ZERO
		SCALE_FROM.TOP_CENTER:
			target.pivot_offset = Vector2(target.size.x / 2.0, 0.0)
		SCALE_FROM.TOP_RIGHT:
			target.pivot_offset = Vector2(target.size.x, 0.0)
		SCALE_FROM.BOTTOM_LEFT:
			target.pivot_offset = Vector2(0.0, target.size.y)
		SCALE_FROM.BOTTOM_CENTER:
			target.pivot_offset = Vector2(target.size.x / 2.0, target.size.y)
		SCALE_FROM.BOTTOM_RIGHT:
			target.pivot_offset = Vector2(target.size.x, target.size.y)

func show() -> void:
	show_started.emit()
	ignore_visibility_change = true
	_set_pivot(scale_from)
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if start_delay > 0.0:
		tween.tween_interval(start_delay)
	if change_visible:
		tween.tween_property(target, "visible", true, 0.01)
		tween.tween_property(self, "ignore_visibility_change", false, 0.01)
	if anim_type == ANIM_TYPE.SCALE:
		if force_from:
			tween.tween_property(target, "scale", Vector2.ONE, duration).from(Vector2.ZERO)
		else:
			tween.tween_property(target, "scale", Vector2.ONE, duration)
	elif anim_type == ANIM_TYPE.FADE:
		if force_from:
			tween.tween_property(target, "modulate:a", 1.0, duration).from(0.0)
		else:
			tween.tween_property(target, "modulate:a", 1.0, duration)
	tween.tween_callback(show_finished.emit)
	if auto_hide_after > 0.0:
		tween.tween_interval(auto_hide_after)
		tween.tween_callback(hide)

func hide(should_free: bool = false) -> void:
	hide_started.emit()
	if anim_when == ANIM_WHEN.VISIBLE:
		ignore_visibility_change = true
		target.visible = true
	_set_pivot(scale_from)
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	if anim_type == ANIM_TYPE.SCALE:
		tween.tween_property(target, "scale", Vector2.ZERO, duration)
	elif anim_type == ANIM_TYPE.FADE:
		tween.tween_property(target, "modulate:a", 0.0, duration)
	if change_visible:
		tween.tween_property(target, "visible", false, 0.01)
		tween.tween_property(self, "ignore_visibility_change", false, 0.01)
	tween.tween_callback(hide_finished.emit)
	if should_free:
		tween.tween_callback(target.queue_free)

func _on_target_visibility_changed() -> void:
	if ignore_visibility_change:
		return
	if target.visible:
		show()
	else:
		hide()
