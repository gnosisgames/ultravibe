class_name Match3ItemTypeVisual
extends RefCounted

## Applies item-type presentation overlays (disabled debuff material parity).

const DISABLED_SHADER := preload("res://assets/shaders/disabled_block_type.gdshader")

static var _disabled_material: ShaderMaterial = null


static func apply(sprite: TextureRect, item_type_id: String) -> void:
	if sprite == null:
		return
	var type_id := str(item_type_id).strip_edges().to_lower()
	if type_id == "disabled":
		sprite.material = _disabled_material_instance()
		sprite.modulate = Color.WHITE
	else:
		sprite.material = null
		sprite.modulate = Color.WHITE


static func _disabled_material_instance() -> ShaderMaterial:
	if _disabled_material == null:
		_disabled_material = ShaderMaterial.new()
		_disabled_material.shader = DISABLED_SHADER
		_disabled_material.set_shader_parameter("greyscale_blend", 1.0)
		_disabled_material.set_shader_parameter("greyscale_luminosity", 0.28)
		_disabled_material.set_shader_parameter("tint_color", Color.WHITE)
	return _disabled_material
