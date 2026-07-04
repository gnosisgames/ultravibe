extends SceneTree

## Renders boon icons with metallic toon (gold / silver / copper) via SubViewport.

const MetallicToonFxScript = preload("res://game/ui/widgets/metallic_toon_fx.gd")

const ICONS: Array = [
	["gold", "res://assets/icons/boons/Rizz.png", "build_gold_settings"],
	["silver", "res://assets/icons/boons/Brainrot.png", "build_silver_settings"],
	["copper", "res://assets/icons/boons/Slay.png", "build_copper_settings"],
]

var _frame := 0
var _vp: SubViewport


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	_vp = SubViewport.new()
	_vp.size = Vector2i(780, 320)
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.18, 0.12, 0.08, 1.0)
	backdrop.set_size(Vector2(780, 320))
	_vp.add_child(backdrop)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	row.position = Vector2(40, 40)
	backdrop.add_child(row)
	for entry in ICONS:
		var label: String = entry[0]
		var path: String = entry[1]
		var builder: String = entry[2]
		var box := VBoxContainer.new()
		row.add_child(box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(200, 200)
		icon.texture = load(path)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var settings: Dictionary
		match builder:
			"build_gold_settings":
				settings = MetallicToonFxScript.build_gold_settings()
			"build_silver_settings":
				settings = MetallicToonFxScript.build_silver_settings()
			_:
				settings = MetallicToonFxScript.build_copper_settings()
		MetallicToonFxScript.apply_to_icon(icon, settings)
		box.add_child(icon)
		var caption := Label.new()
		caption.text = label
		box.add_child(caption)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 12:
		return false
	var tex := _vp.get_texture()
	var img := tex.get_image()
	img.save_png("res://screenshots/_capture_metallic_icons_isolated.png")
	print("[OK] saved metallic icons %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
	return false
