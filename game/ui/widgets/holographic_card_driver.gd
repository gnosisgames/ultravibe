class_name HolographicCardDriver
extends Node

## Feeds damped mouse position into foil_card.gdshader (HUD icons need subtle motion).

const MOUSE_INFLUENCE := 0.14

var anchor: CanvasItem = null
var shader_material: ShaderMaterial = null


func _process(_delta: float) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	if shader_material == null:
		return
	var center: Vector2 = anchor.get_global_rect().get_center()
	var mouse: Vector2
	if anchor is Control:
		mouse = (anchor as Control).get_global_mouse_position()
	else:
		var viewport := anchor.get_viewport()
		if viewport == null:
			return
		mouse = viewport.get_mouse_position()
	var damped_mouse := center + (mouse - center) * MOUSE_INFLUENCE
	shader_material.set_shader_parameter("mouse_position", damped_mouse)
	shader_material.set_shader_parameter("sprite_position", center)
