class_name MouseOffset
extends Node

@export var offset_strength: float = 10.0
@export var smoothing: float = 2.5
@export var enabled: bool = true

var _current_strength: float
var _target: Control

func _ready() -> void:
	_target = get_parent() as Control
	_current_strength = offset_strength

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_current_strength = 0.0
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_current_strength = offset_strength if enabled else 0.0

func _process(delta: float) -> void:
	if _target == null or not enabled:
		return
	var mouse := _target.get_global_mouse_position()
	var center := _target.get_viewport_rect().size / 2.0
	var offset := (mouse / center) - Vector2.ONE
	_target.position = _target.position.lerp(-offset * _current_strength, smoothing * delta)
