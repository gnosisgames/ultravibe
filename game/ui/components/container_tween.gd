class_name ContainerTween
extends Container

signal show_started()
signal hide_started()
signal show_finished()
signal hide_finished()

enum ANIM_WHEN { MANUAL, READY }
enum ANIM_TYPE { SCALE, SLIDE_IN_LEFT, SLIDE_IN_RIGHT }
enum ORDER { START_TOP, START_BOTTOM }
enum SCALE_FROM { CENTER, TOP_LEFT, TOP_CENTER, TOP_RIGHT, BOTTOM_LEFT, BOTTOM_CENTER, BOTTOM_RIGHT }

@export var target: Container
@export var anim_when: ANIM_WHEN = ANIM_WHEN.READY
@export var anim_type: ANIM_TYPE = ANIM_TYPE.SCALE
@export var order_type: ORDER = ORDER.START_TOP
@export var scale_from: SCALE_FROM = SCALE_FROM.CENTER
@export var duration: float = 0.2
@export var delay_appear: float = 0.0
@export var delay_between_elements: float = 0.075
@export var change_visible: bool = false

var tween: Tween

func _ready() -> void:
	if not target:
		target = self
	target.set_meta("container_tween", self)
	match anim_type:
		ANIM_TYPE.SCALE:
			for c: Control in target.get_children():
				c.scale = Vector2.ZERO
				c.modulate.a = 0.0
		ANIM_TYPE.SLIDE_IN_LEFT, ANIM_TYPE.SLIDE_IN_RIGHT:
			for c: Control in target.get_children():
				c.modulate.a = 0.0
	if anim_type == ANIM_TYPE.SCALE:
		for c: Control in target.get_children():
			_set_pivot(c, scale_from)
	if anim_when == ANIM_WHEN.READY:
		appear.call_deferred()

func _set_pivot(control: Control, pivot: SCALE_FROM) -> void:
	match pivot:
		SCALE_FROM.CENTER:
			control.pivot_offset = control.size / 2.0
		SCALE_FROM.TOP_LEFT:
			control.pivot_offset = Vector2.ZERO
		SCALE_FROM.TOP_CENTER:
			control.pivot_offset = Vector2(control.size.x / 2.0, 0.0)
		SCALE_FROM.TOP_RIGHT:
			control.pivot_offset = Vector2(control.size.x, 0.0)
		SCALE_FROM.BOTTOM_LEFT:
			control.pivot_offset = Vector2(0.0, control.size.y)
		SCALE_FROM.BOTTOM_CENTER:
			control.pivot_offset = Vector2(control.size.x / 2.0, control.size.y)
		SCALE_FROM.BOTTOM_RIGHT:
			control.pivot_offset = Vector2(control.size.x, control.size.y)

func appear() -> void:
	await get_tree().process_frame
	show_started.emit()
	for c: Control in target.get_children():
		_set_pivot(c, scale_from)
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.set_parallel(true)
	if delay_appear > 0.0:
		tween.tween_interval(delay_appear)
		tween.chain().tween_interval(0.01)
	var children: Array = target.get_children()
	if order_type == ORDER.START_BOTTOM:
		children.reverse()
	var idx := 0
	for c: Control in children:
		if anim_type == ANIM_TYPE.SCALE:
			tween.tween_property(c, "scale", Vector2.ONE, duration).from(Vector2.ZERO).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 1.0, 0.01).set_delay(delay_between_elements * idx)
		elif anim_type == ANIM_TYPE.SLIDE_IN_LEFT:
			tween.tween_property(c, "position:x", c.position.x, duration).from(c.position.x - c.size.x).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 1.0, 0.05).set_delay(delay_between_elements * idx)
		elif anim_type == ANIM_TYPE.SLIDE_IN_RIGHT:
			tween.tween_property(c, "position:x", c.position.x, duration).from(c.position.x + c.size.x).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 1.0, 0.05).set_delay(delay_between_elements * idx)
		idx += 1
	tween.chain().tween_callback(show_finished.emit)

func disappear() -> void:
	await get_tree().process_frame
	hide_started.emit()
	for c: Control in target.get_children():
		_set_pivot(c, scale_from)
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.set_parallel(true)
	var children: Array = target.get_children()
	if order_type == ORDER.START_BOTTOM:
		children.reverse()
	var idx := 0
	for c: Control in children:
		if anim_type == ANIM_TYPE.SCALE:
			tween.tween_property(c, "scale", Vector2.ZERO, duration).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 0.0, 0.01).set_delay(delay_between_elements * idx + duration)
		elif anim_type == ANIM_TYPE.SLIDE_IN_LEFT:
			tween.tween_property(c, "position:x", -c.size.x, duration).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 1.0, duration * 0.9).set_delay(delay_between_elements * idx)
		elif anim_type == ANIM_TYPE.SLIDE_IN_RIGHT:
			tween.tween_property(c, "position:x", c.size.x, duration).set_delay(delay_between_elements * idx)
			tween.tween_property(c, "modulate:a", 1.0, duration * 0.9).set_delay(delay_between_elements * idx)
		idx += 1
	tween.chain().tween_callback(hide_finished.emit)
