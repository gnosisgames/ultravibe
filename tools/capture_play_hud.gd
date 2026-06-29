extends SceneTree

## Captures gameplay PlayHud screenshots for single-player and 3-player co-op.

var _bootstrap: Node = null
var _frames := 0
var _phase := 0

func _initialize() -> void:
	print("--- Play HUD Screenshot ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	var eng: GnosisEngine = _bootstrap.engine
	var ui := eng.get_service("GameUI") as GnosisGameUIService if eng else null
	match _phase:
		0:
			if ui:
				ui.set_base_view("gameplay")
			_phase = 1
		1:
			if _frames < 30:
				return false
			_capture("play_hud_sp.png")
			var eph := eng.state.root.get_node("Ephemeral")
			if eph.is_valid():
				eph.set_key("playerCount", 3)
				eph.set_key("mode", "coop")
			_phase = 2
		2:
			if _frames < 50:
				return false
			_capture("play_hud_coop3.png")
			print("--- Play HUD Screenshot Done ---")
			quit(0)
	return false

func _capture(filename: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no image for %s" % filename)
		return
	var path := "res://%s" % filename
	img.save_png(path)
	print("[SUCCESS] saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
