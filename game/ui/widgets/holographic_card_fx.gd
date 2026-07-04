class_name HolographicCardFx
extends RefCounted

## Slavrick foil / holographic card shader (https://github.com/Slavrick/GodotShaderFoilCardExample).
## Foil = rainbow/gradient shimmer overlay — NOT gold/silver/copper metal.
## For metallic finishes use MetallicToonFx (build_gold_settings, etc.).
##
##   HolographicCardFx.apply_to(icon, HolographicCardFx.build_holographic_foil_settings())

const SHADER := preload("res://assets/shaders/foil_card.gdshader")
const HolographicCardDriverScript = preload("res://game/ui/widgets/holographic_card_driver.gd")
const MetallicToonFxScript = preload("res://game/ui/widgets/metallic_toon_fx.gd")
const DRIVER_NAME := "HolographicCardDriver"

const RAINBOW_GRADIENT_PATH := "res://assets/textures/foil_card/rainbow_gradient.png"

# Demo defaults from GodotShaderFoilCardExample/main.tscn (card.gdshader materials).
const DEMO_FOIL_COLOR := Vector3(0.972549, 0.984314, 0.992157)
const DEMO_THRESHOLD := 0.5
const DEMO_FUZZINESS := 0.54
const DEMO_EFFECT_ALPHA := 0.325
const DEMO_NORMAL_STRENGTH := 3.16

static var _white_mask: ImageTexture
static var _noise_texture: NoiseTexture2D
static var _normal_map: NoiseTexture2D
static var _rainbow_gradient: Texture2D
static var _prismatic_gradient: GradientTexture1D
static var _foil_shimmer_gradient: GradientTexture1D


static func build_demo_foil_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := {
		"foilcolor": DEMO_FOIL_COLOR,
		"threshold": DEMO_THRESHOLD,
		"fuzziness": DEMO_FUZZINESS,
		"effect_alpha_mult": DEMO_EFFECT_ALPHA,
		"normal_strength": DEMO_NORMAL_STRENGTH,
		"period": 1.0,
		"scroll": 1.0,
		"direction": 0.5,
		"fov": 90.0,
		"cull_back": true,
		"inset": 0.0,
		"max_tilt": 1.0,
		"max_distance": 500.0,
		"gradient": _ensure_rainbow_gradient(),
		"normal_map": _ensure_demo_normal_map(),
		"noise": _ensure_noise_texture(),
		"foil_mask": _ensure_white_mask(),
	}
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_icon_foil_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_demo_foil_settings({
		"hud_icon_mode": true,
		"hud_tilt_scale": 0.32,
		"max_tilt": 0.35,
		"max_distance": 3200.0,
		"normal_strength": 0.85,
		"scroll": 0.38,
		"fov": 55.0,
		"inset": 0.0,
		"effect_alpha_mult": 0.44,
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_holographic_foil_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_foil_settings({
		"gradient": _ensure_rainbow_gradient(),
		"direction": 0.5,
		"scroll": 0.38,
		"effect_alpha_mult": 0.48,
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_foil_card_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_foil_settings({
		"gradient": _ensure_foil_shimmer_gradient(),
		"direction": 0.35,
		"scroll": 0.52,
		"effect_alpha_mult": 0.42,
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_prismatic_foil_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_foil_settings({
		"gradient": _ensure_prismatic_gradient(),
		"direction": 0.65,
		"scroll": 0.45,
		"period": 0.85,
		"effect_alpha_mult": 0.46,
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_gold_foil_settings(overrides: Dictionary = {}) -> Dictionary:
	return build_holographic_foil_settings(overrides)


static func apply_to(item: CanvasItem, settings: Dictionary = {}) -> ShaderMaterial:
	if item == null or not is_instance_valid(item):
		push_warning("[HolographicCardFx] apply_to ignored: invalid canvas item")
		return null
	MetallicToonFxScript._remove_driver(item)
	_remove_driver(item)
	var material := create_material(settings)
	item.use_parent_material = false
	item.material = material
	if item.has_method("queue_redraw"):
		item.call("queue_redraw")
	var track_mouse := not bool(settings.get("hud_icon_mode", false))
	if track_mouse:
		if item.is_inside_tree():
			attach_driver(item, material)
		else:
			var captured_item: CanvasItem = item
			var captured_material: ShaderMaterial = material
			item.tree_entered.connect(func() -> void:
				if captured_item != null and is_instance_valid(captured_item):
					attach_driver(captured_item, captured_material)
			, CONNECT_ONE_SHOT)
	return material


static func create_material(settings: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	_bind_demo_defaults(material)
	_apply_settings(material, settings)
	return material


static func attach_driver(anchor: CanvasItem, material: ShaderMaterial) -> Node:
	_remove_driver(anchor)
	var driver: Node = HolographicCardDriverScript.new()
	driver.name = DRIVER_NAME
	driver.anchor = anchor
	driver.shader_material = material
	driver.process_mode = Node.PROCESS_MODE_ALWAYS
	driver.set_process(true)
	anchor.add_child(driver)
	return driver


static func remove_from(anchor: CanvasItem) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	MetallicToonFxScript._remove_driver(anchor)
	_remove_driver(anchor)
	anchor.material = null


static func _remove_driver(anchor: CanvasItem) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var existing := anchor.get_node_or_null(DRIVER_NAME)
	if existing != null:
		existing.queue_free()


static func _apply_settings(material: ShaderMaterial, settings: Dictionary) -> void:
	if settings.has("foilcolor"):
		var foil: Variant = settings.foilcolor
		if foil is Color:
			material.set_shader_parameter("foilcolor", Vector3(foil.r, foil.g, foil.b))
		elif foil is Vector3:
			material.set_shader_parameter("foilcolor", foil)
	if settings.has("threshold"):
		material.set_shader_parameter("threshold", float(settings.threshold))
	if settings.has("fuzziness"):
		material.set_shader_parameter("fuzziness", float(settings.fuzziness))
	if settings.has("effect_alpha_mult"):
		material.set_shader_parameter("effect_alpha_mult", float(settings.effect_alpha_mult))
	if settings.has("normal_strength"):
		material.set_shader_parameter("normal_strength", float(settings.normal_strength))
	if settings.has("period"):
		material.set_shader_parameter("period", float(settings.period))
	if settings.has("scroll"):
		material.set_shader_parameter("scroll", float(settings.scroll))
	if settings.has("direction"):
		material.set_shader_parameter("direction", float(settings.direction))
	if settings.has("fov"):
		material.set_shader_parameter("fov", float(settings.fov))
	if settings.has("cull_back"):
		material.set_shader_parameter("cull_back", bool(settings.cull_back))
	if settings.has("inset"):
		material.set_shader_parameter("inset", float(settings.inset))
	if settings.has("max_tilt"):
		material.set_shader_parameter("max_tilt", float(settings.max_tilt))
	if settings.has("max_distance"):
		material.set_shader_parameter("max_distance", float(settings.max_distance))
	if settings.has("hud_icon_mode"):
		material.set_shader_parameter("hud_icon_mode", bool(settings.hud_icon_mode))
	if settings.has("hud_tilt_scale"):
		material.set_shader_parameter("hud_tilt_scale", float(settings.hud_tilt_scale))
	if settings.has("foil_mask") and settings.foil_mask is Texture2D:
		material.set_shader_parameter("foil_mask", settings.foil_mask)
	if settings.has("gradient") and settings.gradient is Texture2D:
		material.set_shader_parameter("gradient", settings.gradient)
	if settings.has("noise") and settings.noise is Texture2D:
		material.set_shader_parameter("noise", settings.noise)
	if settings.has("normal_map") and settings.normal_map is Texture2D:
		material.set_shader_parameter("normal_map", settings.normal_map)


static func _bind_demo_defaults(material: ShaderMaterial) -> void:
	material.set_shader_parameter("mouse_position", Vector2.ZERO)
	material.set_shader_parameter("sprite_position", Vector2.ZERO)
	material.set_shader_parameter("fov", 90.0)
	material.set_shader_parameter("cull_back", true)
	material.set_shader_parameter("inset", 0.0)
	material.set_shader_parameter("max_tilt", 1.0)
	material.set_shader_parameter("max_distance", 500.0)
	material.set_shader_parameter("foilcolor", DEMO_FOIL_COLOR)
	material.set_shader_parameter("threshold", DEMO_THRESHOLD)
	material.set_shader_parameter("fuzziness", DEMO_FUZZINESS)
	material.set_shader_parameter("effect_alpha_mult", DEMO_EFFECT_ALPHA)
	material.set_shader_parameter("normal_strength", DEMO_NORMAL_STRENGTH)
	material.set_shader_parameter("period", 1.0)
	material.set_shader_parameter("scroll", 1.0)
	material.set_shader_parameter("direction", 0.5)
	material.set_shader_parameter("gradient", _ensure_rainbow_gradient())
	material.set_shader_parameter("normal_map", _ensure_demo_normal_map())
	material.set_shader_parameter("noise", _ensure_noise_texture())
	material.set_shader_parameter("foil_mask", _ensure_white_mask())


static func _ensure_white_mask() -> ImageTexture:
	if _white_mask != null:
		return _white_mask
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white_mask = ImageTexture.create_from_image(image)
	return _white_mask


static func _ensure_demo_normal_map() -> NoiseTexture2D:
	if _normal_map != null:
		return _normal_map
	var noise := FastNoiseLite.new()
	noise.frequency = 0.0142
	_normal_map = NoiseTexture2D.new()
	_normal_map.noise = noise
	_normal_map.as_normal_map = true
	_normal_map.bump_strength = 3.4
	return _normal_map


static func _ensure_noise_texture() -> NoiseTexture2D:
	if _noise_texture != null:
		return _noise_texture
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	_noise_texture = NoiseTexture2D.new()
	_noise_texture.noise = noise
	_noise_texture.width = 128
	_noise_texture.height = 128
	_noise_texture.seamless = true
	return _noise_texture


static func _ensure_rainbow_gradient() -> Texture2D:
	if _rainbow_gradient != null:
		return _rainbow_gradient
	if ResourceLoader.exists(RAINBOW_GRADIENT_PATH):
		_rainbow_gradient = load(RAINBOW_GRADIENT_PATH) as Texture2D
	if _rainbow_gradient == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1.0, 0.2, 0.35))
		gradient.add_point(0.2, Color(1.0, 0.85, 0.15))
		gradient.add_point(0.45, Color(0.3, 1.0, 0.45))
		gradient.add_point(0.65, Color(0.2, 0.65, 1.0))
		gradient.add_point(0.85, Color(0.85, 0.3, 1.0))
		gradient.add_point(1.0, Color(1.0, 0.35, 0.55))
		var tex := GradientTexture1D.new()
		tex.gradient = gradient
		_rainbow_gradient = tex
	return _rainbow_gradient


static func _ensure_prismatic_gradient() -> GradientTexture1D:
	if _prismatic_gradient != null:
		return _prismatic_gradient
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 1.0, 1.0))
	gradient.add_point(0.532787, Color(0.0, 1.0, 0.0))
	gradient.add_point(1.0, Color(0.0, 1.0, 1.0))
	_prismatic_gradient = GradientTexture1D.new()
	_prismatic_gradient.gradient = gradient
	return _prismatic_gradient


static func _ensure_foil_shimmer_gradient() -> GradientTexture1D:
	if _foil_shimmer_gradient != null:
		return _foil_shimmer_gradient
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.329158, 0.329158, 0.329158))
	gradient.add_point(0.557377, Color.WHITE)
	gradient.add_point(0.762295, Color(0.505344, 0.505344, 0.505344))
	_foil_shimmer_gradient = GradientTexture1D.new()
	_foil_shimmer_gradient.gradient = gradient
	return _foil_shimmer_gradient

