class_name GameplayBusySpinner
extends Control

## Circular spinner shown while match3 gameplay input is locked (cascades, HUD chain).

const SPIN_TEXTURE := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Cursors/busy_circle.png"

@export var spin_speed_hz: float = 1.0
@export var ramp_up_seconds: float = 0.35
@export var ramp_down_seconds: float = 0.12

var _icon: TextureRect = null
var _busy_requested := false
var _spin_blend := 0.0
var _spin_angle := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 28)
	_icon = TextureRect.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.modulate = Color(1, 1, 1, 0.92)
	var tex := load(SPIN_TEXTURE)
	if tex:
		_icon.texture = tex
	add_child(_icon)
	visible = false
	set_process(true)


func set_spinning(active: bool) -> void:
	_busy_requested = active
	if active:
		visible = true


func _process(delta: float) -> void:
	var target_blend := 1.0 if _busy_requested else 0.0
	var ramp_seconds := ramp_up_seconds if _busy_requested else ramp_down_seconds
	var ramp_step := 1.0 if ramp_seconds <= 0.0 else delta / ramp_seconds
	_spin_blend = move_toward(_spin_blend, target_blend, ramp_step)
	if _spin_blend <= 0.0:
		_spin_angle = 0.0
		if _icon:
			_icon.pivot_offset = _icon.size * 0.5
			_icon.rotation = 0.0
		visible = false
		return
	visible = true
	if _icon:
		_icon.pivot_offset = _icon.size * 0.5
		_spin_angle -= deg_to_rad(360.0 * spin_speed_hz * _spin_blend) * delta
		_icon.rotation = _spin_angle
