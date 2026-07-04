extends SceneTree

## Renders starter boons with three foil/holographic variants via SubViewport.

const HolographicCardFxScript = preload("res://game/ui/widgets/holographic_card_fx.gd")

const ICONS: Array = [
	["holographic", "res://assets/icons/boons/Rizz.png", "build_holographic_foil_settings"],
	["foil", "res://assets/icons/boons/Brainrot.png", "build_foil_card_settings"],
	["prismatic", "res://assets/icons/boons/Slay.png", "build_prismatic_foil_settings"],
]

var _frame := 0
var _vp: SubViewport
var _saved := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	_vp = SubViewport.new()
	_vp.size = Vector2i(780, 320)
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
		var box := VBoxContainer.new()
		row.add_child(box)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(200, 200)
		icon.texture = load(entry[1])
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var settings: Dictionary
		match entry[2]:
			"build_holographic_foil_settings":
				settings = HolographicCardFxScript.build_holographic_foil_settings()
			"build_foil_card_settings":
				settings = HolographicCardFxScript.build_foil_card_settings()
			_:
				settings = HolographicCardFxScript.build_prismatic_foil_settings()
		HolographicCardFxScript.apply_to(icon, settings)
		box.add_child(icon)
		var caption := Label.new()
		caption.text = entry[0]
		box.add_child(caption)


func _process(_delta: float) -> bool:
	if _saved:
		return false
	_frame += 1
	if _frame < 12:
		return false
	var tex := _vp.get_texture()
	if tex == null:
		return false
	var img := tex.get_image()
	if img == null or img.is_empty():
		return false
	_saved = true
	img.save_png("res://screenshots/_capture_foil_icons_isolated.png")
	print("[OK] saved foil icons %dx%d" % [img.get_width(), img.get_height()])
	quit(0)
	return false
