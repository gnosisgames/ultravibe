class_name ShaderIconRect
extends Control

## Draws a centered icon texture so canvas_item ShaderMaterials apply reliably.
## TextureRect often ignores custom materials depending on expand/stretch mode.

@export var icon_texture: Texture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_icon_texture(texture: Texture2D) -> void:
	icon_texture = texture
	queue_redraw()


func _draw() -> void:
	if icon_texture == null:
		return
	var tex_size: Vector2 = icon_texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale_factor: float = minf(size.x / tex_size.x, size.y / tex_size.y)
	var draw_size: Vector2 = tex_size * scale_factor
	var offset: Vector2 = (size - draw_size) * 0.5
	draw_texture_rect(icon_texture, Rect2(offset, draw_size), false)
