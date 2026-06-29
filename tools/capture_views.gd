extends SceneTree

## Boots the real game and saves screenshots of the title, settings and gameplay
## screens to res://screenshots/_capture_*.png for visual verification.

var _bootstrap: Node = null
var _frames := 0
var _fb: FallingBlockService = null
var _stage := 0

func _initialize() -> void:
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _ui():
	return _bootstrap.engine.get_service("GameUI") if _bootstrap and _bootstrap.engine else null

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no image (headless?)")
		return
	img.save_png("res://screenshots/_capture_%s.png" % name)
	print("[SHOT] %s (%dx%d)" % [name, img.get_width(), img.get_height()])

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		_save("title")
		var ui = _ui()
		if ui and ui.has_method("set_base_view"):
			ui.set_base_view("settings")
	elif _frames == 45:
		_save("settings")
		var sv = _bootstrap.get_node_or_null("UI/SettingsView")
		if sv and sv.has_method("_show_tab"):
			sv._show_tab("language")
	elif _frames == 65:
		_save("settings_language")
		var ui = _ui()
		if ui and ui.has_method("set_base_view"):
			ui.set_base_view("gameplay")
		_fb = _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
	elif _frames > 65 and _frames < 150 and _fb and _frames % 8 == 0:
		var players := _fb.get_players()
		if not players.is_empty():
			var p: FallingBlockModels.PlayerState = players[0]
			if not p.current_piece_instance_id.is_empty():
				var hd := FallingBlockModels.InputEventData.new()
				hd.player_id = p.player_id
				hd.type = FallingBlockModels.InputType.HARD_DROP
				_fb.handle_input(hd)
	elif _frames == 160:
		_save("gameplay")
		_force_reward_screen()
	elif _frames == 185:
		_save("rewards")
		var ui = _ui()
		if ui and ui.has_method("set_base_view"):
			ui.set_base_view("collection")
	elif _frames == 210:
		_save("collection")
		quit(0)
	return false

func _force_reward_screen() -> void:
	if not _fb:
		return
	var needed := FallingBlockEphemeral.get_fb_int(_fb.context, "roundLinesNeeded", FallingBlockRoundLines.BASE_LINES_PER_ROUND)
	var players := _fb.get_players()
	if players.is_empty():
		return
	_fb._apply_round_progress_after_line_clear(players[0], needed, GnosisScalableValue.zero())
	var ui = _ui()
	if ui and ui.has_method("set_base_view"):
		ui.set_base_view("rewards")
