extends SceneTree

## Guards against accidental editor/runtime scene migration churn in main.tscn.
## A previous resave rewrote the scene header/resource ids, added unique node ids,
## changed CRT shader params, and dropped HUD exports, which broke UI input.

func _initialize() -> void:
	print("--- Scene Format Guard Test ---")
	var ok := true
	var text := FileAccess.get_file_as_string("res://main.tscn")
	if text.is_empty():
		print("[FAIL] Could not read main.tscn")
		ok = false

	ok = _expect(text, "path=\"res://game/match3/view/match3_hud.tscn\"", "main.tscn uses Match3 HUD scene instance") and ok
	ok = _expect(text, "[node name=\"GameArea\"", "GameArea node present") and ok
	ok = _expect(text, "parent=\"UI\"", "GameArea lives under UI CanvasLayer") and ok
	ok = _expect(text, "view_id = \"gameplay\"", "GameArea registered as gameplay view") and ok
	ok = _expect(text, "path=\"res://game/ui/gameplay_view.gd\"", "GameArea uses gameplay view script") and ok
	ok = _expect(text, "anchors_preset = 15", "GameArea uses full-rect preset") and ok
	ok = _expect(text, "shader_parameter/distort_intensity = 0.05", "CRT distortion stays at authored value") and ok
	ok = _expect(text, "shader_parameter/warp_amount = 0.12", "CRT warp stays at authored value") and ok
	ok = _expect(text, "shader_parameter/vignette_intensity = 0.3", "CRT vignette intensity stays at authored value") and ok
	ok = _expect(text, "shader_parameter/vignette_opacity = 0.35", "CRT vignette opacity stays at authored value") and ok
	ok = _expect(text, "visible = false", "Legacy GameArea backdrop stays hidden behind Match3 HUD") and ok

	print("--- Scene Format Guard Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _expect(text: String, needle: String, label: String) -> bool:
	if text.contains(needle):
		print("[SUCCESS] %s" % label)
		return true
	print("[FAIL] %s" % label)
	return false

func _reject(text: String, needle: String, label: String) -> bool:
	if not text.contains(needle):
		print("[SUCCESS] %s" % label)
		return true
	print("[FAIL] %s" % label)
	return false
