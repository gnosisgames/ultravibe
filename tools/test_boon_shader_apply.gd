extends SceneTree

## Headless sanity check: metallic + foil shaders compile and materials stick.

const HolographicCardFxScript = preload("res://game/ui/widgets/holographic_card_fx.gd")
const MetallicToonFxScript = preload("res://game/ui/widgets/metallic_toon_fx.gd")
const FoilShader = preload("res://assets/shaders/foil_card.gdshader")
const MetallicShader = preload("res://assets/shaders/metallic_toon_canvas.gdshader")
const ICON_PATH = "res://assets/icons/boons/Rizz.png"


func _initialize() -> void:
	var ok := true
	ok = _check_shader_load(MetallicShader, "metallic_toon_canvas") and ok
	ok = _check_shader_load(FoilShader, "foil_card") and ok
	ok = _check_metallic_on_icon() and ok
	ok = _check_foil_on_icon() and ok
	print("[test_boon_shader_apply] %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)


func _check_shader_load(shader: Shader, label: String) -> bool:
	if shader == null:
		print("[FAIL] %s shader is null" % label)
		return false
	var mat := ShaderMaterial.new()
	mat.shader = shader
	if mat.shader == null:
		print("[FAIL] %s shader failed to assign" % label)
		return false
	print("[OK] %s shader loaded" % label)
	return true


func _check_metallic_on_icon() -> bool:
	var icon := TextureRect.new()
	icon.texture = load(ICON_PATH)
	var mat := MetallicToonFxScript.apply_to_icon(icon, MetallicToonFxScript.build_gold_settings())
	if mat == null or icon.material == null:
		print("[FAIL] metallic material not applied")
		return false
	print("[OK] metallic material applied")
	return true


func _check_foil_on_icon() -> bool:
	var icon := TextureRect.new()
	icon.texture = load(ICON_PATH)
	var mat := HolographicCardFxScript.apply_to(icon, HolographicCardFxScript.build_holographic_foil_settings())
	if mat == null or icon.material == null:
		print("[FAIL] foil material not applied")
		return false
	print("[OK] foil material applied")
	return true
