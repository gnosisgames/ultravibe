extends SceneTree

## Boots the real Ultravibe game, lets it render and play for a short while, then
## saves a screenshot of the rendered viewport to user:// (and the project dir).

var _bootstrap: Node = null
var _frames := 0
var _fb: FallingBlockService = null

func _initialize() -> void:
	print("--- Screenshot Capture ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_fb = _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
		# Dismiss the title overlay so the gameplay board is visible in the shot.
		var game_ui = _bootstrap.engine.get_service("GameUI")
		if game_ui and game_ui.has_method("set_base_view"):
			game_ui.set_base_view("gameplay")
	# Drive a few hard drops so the board has locked blocks in the shot.
	if _fb and _frames % 10 == 0 and _frames < 120:
		var players := _fb.get_players()
		if not players.is_empty():
			var p: FallingBlockModels.PlayerState = players[0]
			if not p.current_piece_instance_id.is_empty():
				var hd := FallingBlockModels.InputEventData.new()
				hd.player_id = p.player_id
				hd.type = FallingBlockModels.InputType.HARD_DROP
				_fb.handle_input(hd)
	if _frames < 140:
		return false
	_capture()
	quit(0)
	return true

func _capture() -> void:
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no rendered image available (headless/dummy renderer)")
		return
	var out_user := "user://ultravibe_screenshot.png"
	var out_proj := "res://ultravibe_screenshot.png"
	img.save_png(out_user)
	img.save_png(out_proj)
	print("[SUCCESS] screenshot saved to %s (%dx%d)" % [ProjectSettings.globalize_path(out_user), img.get_width(), img.get_height()])
	print("[INFO] project copy: %s" % ProjectSettings.globalize_path(out_proj))
