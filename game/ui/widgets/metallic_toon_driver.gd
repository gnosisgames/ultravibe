class_name MetallicToonDriver
extends Node

## Drives metallic_toon_canvas light_direction from damped mouse vs icon center.

const MOUSE_INFLUENCE := 0.18

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
	var offset: Vector2 = (mouse - center) * MOUSE_INFLUENCE
	var light_dir: Vector3 = Vector3(offset.x, offset.y, 420.0)
	if light_dir.length_squared() < 1.0:
		light_dir = Vector3(-0.35, -0.55, 0.75)
	else:
		light_dir = light_dir.normalized()
	shader_material.set_shader_parameter("light_direction", light_dir)
