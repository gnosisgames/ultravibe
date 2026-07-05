extends SceneTree

## Boots the real game, starts a Match3 run, opens the level-select panel and
## saves a screenshot to res://screenshots/_capture_level_select.png.

var _host: Node = null
var _frames := 0

func _initialize() -> void:
	_host = load("res://main.tscn").instantiate()
	root.add_child(_host)

func _engine():
	return _host.engine if _host else null

func _ui():
	var eng = _engine()
	return eng.get_service("GameUI") if eng else null

func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no image (headless?)")
		return
	img.save_png("res://screenshots/_capture_%s.png" % name)
	print("[SHOT] %s (%dx%d)" % [name, img.get_width(), img.get_height()])

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 25:
		_start_run()
	elif _frames == 55:
		_save("level_select")
		_play_level()
	elif _frames == 90:
		_save("playing")
		_transition("shopPanel")
	elif _frames == 125:
		_save("planning_shop")
		_transition("rewardPanel")
	elif _frames == 160:
		_save("reward")
		quit(0)
	return false

func _start_run() -> void:
	GnosisRunSave.clear_run_save()
	if _host and _host.has_method("restart_ephemeral_run"):
		_host.restart_ephemeral_run()
	var eng = _engine()
	if eng == null:
		return
	var ephemeral: GnosisNode = eng.state.root.get_node("Ephemeral")
	if ephemeral.is_valid():
		ephemeral.set_key("playerCount", 1)
		ephemeral.set_key("mode", "solo")
	var match3 = eng.get_service("Match3")
	if match3:
		match3.handle_run_started()
	if _host and _host.has_method("resync_match3_board_view"):
		_host.resync_match3_board_view()
	var ui = _ui()
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "play", "slide_up")

func _play_level() -> void:
	var eng = _engine()
	var match3 = eng.get_service("Match3") if eng else null
	if eng == null or match3 == null:
		return
	var params: GnosisNode = eng.store.create_object()
	params.set_key("doubleDown", false)
	match3.invoke_function("PlayLevel", params)

func _transition(state: String) -> void:
	var eng = _engine()
	var match3 = eng.get_service("Match3") if eng else null
	if eng == null or match3 == null:
		return
	var params: GnosisNode = eng.store.create_object()
	params.set_key("gameStatus", state)
	match3.invoke_function("TransitionToState", params)
