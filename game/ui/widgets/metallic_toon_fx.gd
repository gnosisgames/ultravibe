class_name MetallicToonFx
extends RefCounted

## Metallic toon FX based on Profesor Shader's Godot 4 demo (MIT).
## https://github.com/profesorshader/shader-anime-style-metal-aka-metallic-toon
##
##   MetallicToonFx.apply_to_icon(icon_control)           # 2D HUD (canvas shader)
##   MetallicToonFx.apply_to_mesh(mesh_instance_3d)       # 3D (spatial shader + scene light)

const CANVAS_SHADER := preload("res://assets/shaders/metallic_toon_canvas.gdshader")
const SPATIAL_SHADER := preload("res://assets/shaders/metallic_toon.gdshader")
const MetallicToonDriverScript = preload("res://game/ui/widgets/metallic_toon_driver.gd")
const HolographicCardFxScript = preload("res://game/ui/widgets/holographic_card_fx.gd")
const DRIVER_NAME := "MetallicToonDriver"

const TEXTURE_DIR := "res://assets/textures/metallic_toon/"
const NOISE_PATH := TEXTURE_DIR + "noise_warp.png"
const RAMP_GOLD_PATH := TEXTURE_DIR + "color-ramp-gold.png"
const RAMP_SILVER_PATH := TEXTURE_DIR + "color-ramp-silver.png"
const RAMP_IRON_PATH := TEXTURE_DIR + "color-ramp-iron.png"

static var _noise_tex: Texture2D
static var _ramp_gold: Texture2D
static var _ramp_silver: Texture2D
static var _ramp_iron: Texture2D


static func build_icon_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := _demo_defaults().duplicate(true)
	settings["noise_tex"] = _ensure_noise_tex()
	settings["hud_icon_mode"] = true
	settings["metal_blend"] = 0.45
	settings["metal_threshold"] = 0.55
	settings["metal_mask_sharpness"] = 2.0
	settings["noise_scl"] = 0.1
	settings["rim_str"] = 1.0
	settings["specular_size"] = 28.0
	settings["specular_strength"] = 0.55
	settings["specular_threshold"] = 0.62
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_gold_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_settings({
		"color_ramp": _ensure_ramp_gold(),
		"light_direction": Vector3(-0.42, -0.48, 0.78),
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_silver_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_settings({
		"color_ramp": _ensure_ramp_silver(),
		"light_direction": Vector3(-0.18, -0.62, 0.76),
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func build_copper_settings(overrides: Dictionary = {}) -> Dictionary:
	var settings := build_icon_settings({
		"color_ramp": _ensure_ramp_iron(),
		"light_direction": Vector3(-0.55, -0.28, 0.78),
		"metal_tint": Vector3(1.08, 0.82, 0.62),
	})
	for key in overrides.keys():
		settings[key] = overrides[key]
	return settings


static func apply_to_icon(item: CanvasItem, settings: Dictionary = {}) -> ShaderMaterial:
	if item == null or not is_instance_valid(item):
		push_warning("[MetallicToonFx] apply_to_icon ignored: invalid canvas item")
		return null
	HolographicCardFxScript._remove_driver(item)
	var material := create_canvas_material(settings)
	item.use_parent_material = false
	item.material = material
	if item.has_method("queue_redraw"):
		item.call("queue_redraw")
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


static func apply_to_mesh(mesh: MeshInstance3D, settings: Dictionary = {}) -> ShaderMaterial:
	if mesh == null or not is_instance_valid(mesh):
		push_warning("[MetallicToonFx] apply_to_mesh ignored: invalid mesh")
		return null
	var material := create_spatial_material(settings)
	mesh.material_override = material
	return material


static func create_canvas_material(settings: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = CANVAS_SHADER
	_bind_demo_defaults(material)
	_apply_settings(material, settings)
	return material


static func create_spatial_material(settings: Dictionary = {}) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SPATIAL_SHADER
	_bind_demo_defaults(material)
	_apply_settings(material, settings)
	return material


static func attach_driver(anchor: CanvasItem, material: ShaderMaterial) -> Node:
	_remove_driver(anchor)
	var driver: Node = MetallicToonDriverScript.new()
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
	_remove_driver(anchor)
	anchor.material = null


static func _remove_driver(anchor: CanvasItem) -> void:
	if anchor == null or not is_instance_valid(anchor):
		return
	var existing := anchor.get_node_or_null(DRIVER_NAME)
	if existing != null:
		existing.queue_free()


static func _demo_defaults() -> Dictionary:
	return {
		"base_color": Color.WHITE,
		"specular_color": Color.WHITE,
		"specular_size": 8.0,
		"specular_threshold": 0.5,
		"specular_strength": 1.0,
		"noise_pow": 2.0,
		"noise_scl": 0.1,
		"rim_pow": 4.0,
		"rim_str": 1.0,
	}


static func _apply_settings(material: ShaderMaterial, settings: Dictionary) -> void:
	if settings.has("base_color"):
		var base: Variant = settings.base_color
		if base is Color:
			material.set_shader_parameter("base_color", base)
	if settings.has("light_direction") and settings.light_direction is Vector3:
		material.set_shader_parameter("light_direction", settings.light_direction)
	if settings.has("specular_color"):
		var spec: Variant = settings.specular_color
		if spec is Color:
			material.set_shader_parameter("specular_color", Vector3(spec.r, spec.g, spec.b))
		elif spec is Vector3:
			material.set_shader_parameter("specular_color", spec)
	if settings.has("specular_size"):
		material.set_shader_parameter("specular_size", float(settings.specular_size))
	if settings.has("specular_threshold"):
		material.set_shader_parameter("specular_threshold", float(settings.specular_threshold))
	if settings.has("specular_strength"):
		material.set_shader_parameter("specular_strength", float(settings.specular_strength))
	if settings.has("noise_pow"):
		material.set_shader_parameter("noise_pow", float(settings.noise_pow))
	if settings.has("noise_scl"):
		material.set_shader_parameter("noise_scl", float(settings.noise_scl))
	if settings.has("rim_pow"):
		material.set_shader_parameter("rim_pow", float(settings.rim_pow))
	if settings.has("rim_str"):
		material.set_shader_parameter("rim_str", float(settings.rim_str))
	if settings.has("metal_blend"):
		material.set_shader_parameter("metal_blend", float(settings.metal_blend))
	if settings.has("metal_threshold"):
		material.set_shader_parameter("metal_threshold", float(settings.metal_threshold))
	if settings.has("metal_mask_sharpness"):
		material.set_shader_parameter("metal_mask_sharpness", float(settings.metal_mask_sharpness))
	if settings.has("hud_icon_mode"):
		material.set_shader_parameter("hud_icon_mode", bool(settings.hud_icon_mode))
	if settings.has("metal_tint"):
		var tint: Variant = settings.metal_tint
		if tint is Color:
			material.set_shader_parameter("metal_tint", Vector3(tint.r, tint.g, tint.b))
		elif tint is Vector3:
			material.set_shader_parameter("metal_tint", tint)
	if settings.has("color_ramp") and settings.color_ramp is Texture2D:
		material.set_shader_parameter("color_ramp", settings.color_ramp)
	if settings.has("noise_tex") and settings.noise_tex is Texture2D:
		material.set_shader_parameter("noise_tex", settings.noise_tex)


static func _bind_demo_defaults(material: ShaderMaterial) -> void:
	var defaults := _demo_defaults()
	material.set_shader_parameter("base_color", defaults.base_color)
	material.set_shader_parameter("light_direction", Vector3(-0.35, -0.55, 0.75))
	material.set_shader_parameter("specular_color", Vector3(1.0, 1.0, 1.0))
	material.set_shader_parameter("specular_size", defaults.specular_size)
	material.set_shader_parameter("specular_threshold", defaults.specular_threshold)
	material.set_shader_parameter("specular_strength", defaults.specular_strength)
	material.set_shader_parameter("noise_pow", defaults.noise_pow)
	material.set_shader_parameter("noise_scl", defaults.noise_scl)
	material.set_shader_parameter("rim_pow", defaults.rim_pow)
	material.set_shader_parameter("rim_str", defaults.rim_str)
	material.set_shader_parameter("metal_blend", 0.45)
	material.set_shader_parameter("metal_threshold", 0.55)
	material.set_shader_parameter("metal_mask_sharpness", 2.0)
	material.set_shader_parameter("hud_icon_mode", true)
	material.set_shader_parameter("metal_tint", Vector3(1.0, 1.0, 1.0))
	material.set_shader_parameter("color_ramp", _ensure_ramp_gold())
	material.set_shader_parameter("noise_tex", _ensure_noise_tex())


static func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("[MetallicToonFx] missing texture: %s" % path)
		return null
	return load(path) as Texture2D


static func _ensure_noise_tex() -> Texture2D:
	if _noise_tex == null:
		_noise_tex = _load_texture(NOISE_PATH)
	return _noise_tex


static func _ensure_ramp_gold() -> Texture2D:
	if _ramp_gold == null:
		_ramp_gold = _load_texture(RAMP_GOLD_PATH)
	return _ramp_gold


static func _ensure_ramp_silver() -> Texture2D:
	if _ramp_silver == null:
		_ramp_silver = _load_texture(RAMP_SILVER_PATH)
	return _ramp_silver


static func _ensure_ramp_iron() -> Texture2D:
	if _ramp_iron == null:
		_ramp_iron = _load_texture(RAMP_IRON_PATH)
	return _ramp_iron
