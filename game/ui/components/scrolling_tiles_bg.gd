@tool
class_name ScrollingTilesBg
extends ColorRect

## Feeds the owning rect's pixel size into the scrolling_tiles shader so the
## tiled pattern keeps square cells across window resolutions.

func _ready() -> void:
	resized.connect(_push_rect_size)
	_push_rect_size()

func _push_rect_size() -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("rect_size", size)
