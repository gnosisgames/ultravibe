class_name Match3ItemTypeVisual
extends RefCounted

## Applies item-type presentation overlays (disabled debuff: true greyscale textures).

static var _greyscale_textures: Dictionary = {}


static func apply(sprite: TextureRect, item_type_id: String, source_texture: Texture2D = null) -> void:
	if sprite == null:
		return
	var tex := source_texture if source_texture != null else sprite.texture
	if tex != null and not sprite.has_meta("original_texture"):
		sprite.set_meta("original_texture", tex)
	elif tex == null and sprite.has_meta("original_texture"):
		tex = sprite.get_meta("original_texture") as Texture2D

	var type_id := str(item_type_id).strip_edges().to_lower()
	if type_id == "disabled":
		sprite.material = null
		sprite.modulate = Color.WHITE
		if tex != null:
			sprite.texture = greyscale_texture(tex)
	else:
		sprite.material = null
		sprite.modulate = Color.WHITE
		if sprite.has_meta("original_texture"):
			var original := sprite.get_meta("original_texture") as Texture2D
			if original != null:
				sprite.texture = original


static func greyscale_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var cache_key := _texture_cache_key(source)
	if _greyscale_textures.has(cache_key):
		return _greyscale_textures[cache_key]

	var img: Image = source.get_image()
	if img.is_empty():
		return source

	var converted: Image = img.duplicate()
	if converted.get_format() != Image.FORMAT_RGBA8:
		converted.convert(Image.FORMAT_RGBA8)

	var w: int = converted.get_width()
	var h: int = converted.get_height()
	for y in h:
		for x in w:
			var c: Color = converted.get_pixel(x, y)
			var lum := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			converted.set_pixel(x, y, Color(lum, lum, lum, c.a))

	var result := ImageTexture.create_from_image(converted)
	_greyscale_textures[cache_key] = result
	return result


static func _texture_cache_key(source: Texture2D) -> String:
	if source.resource_path != "":
		return source.resource_path
	return str(source.get_instance_id())
