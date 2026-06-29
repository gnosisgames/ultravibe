extends SceneTree

## Verifies the run-over flow: FallingBlock publishes game over with a summary,
## GameUI navigates to the game_over view, and Play Again starts fresh gameplay.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Game Over Flow Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Game Over Flow Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var ui := engine.get_service("GameUI") as GnosisGameUIService
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	if ui == null or fb == null:
		print("[FAIL] GameUI/FallingBlock missing")
		return false

	ui.set_base_view("gameplay")
	FallingBlockEphemeral.set_fb_scalable(fb.context, "runTotalScore", GnosisScalableValue.from_float(1250.0))
	FallingBlockEphemeral.set_fb_int(fb.context, "currentRound", 4)
	FallingBlockEphemeral.set_fb_int(fb.context, "roundLinesCurrent", 7)
	FallingBlockEphemeral.set_fb_int(fb.context, "roundLinesNeeded", 16)
	fb.debug_set_run_elapsed_seconds(83.0)

	var players := fb.get_players()
	if players.is_empty():
		print("[FAIL] no players")
		return false
	fb._publish_game_over(players[0])

	# Game over is now an additive overlay over the (still-rendered) gameplay
	# board, like the pause menu, rather than a full base-view swap.
	if ui.get_base_view_id() != "gameplay":
		print("[FAIL] expected gameplay to stay the base view, got %s" % ui.get_base_view_id())
		ok = false
	elif ui.get_active_overlay_state_for_view("game_over").is_empty():
		print("[FAIL] expected game_over overlay to be active")
		ok = false
	else:
		print("[SUCCESS] GameUI opened game_over as an overlay above gameplay")

	if _label_text("ScoreValue") != "1.25K":
		print("[FAIL] score label expected 1.25K, got %s" % _label_text("ScoreValue"))
		ok = false
	if _label_text("RoundValue") != "4":
		print("[FAIL] round label expected 4, got %s" % _label_text("RoundValue"))
		ok = false
	if _label_text("TimeValue") != "01:23":
		print("[FAIL] time label expected 01:23, got %s" % _label_text("TimeValue"))
		ok = false
	if ok:
		print("[SUCCESS] Game over summary labels populated")

	var play_again := _find_button(_bootstrap, "PlayAgainButton")
	if play_again == null:
		print("[FAIL] PlayAgainButton missing")
		return false
	# Headless test runs in one frame; skip the post-game-over input lockout.
	var go_view := _find_game_over_view(_bootstrap)
	if go_view:
		go_view._on_action_cooldown_finished()
	play_again.emit_signal("pressed")
	if ui.get_base_view_id() != "gameplay":
		print("[FAIL] Play Again did not return to gameplay")
		ok = false
	elif not ui.get_active_overlay_state_for_view("game_over").is_empty():
		print("[FAIL] Play Again did not dismiss the game_over overlay")
		ok = false
	else:
		print("[SUCCESS] Play Again dismisses the overlay and restarts gameplay")

	return ok

func _label_text(name: String) -> String:
	var label := _find_label(_bootstrap, name)
	return label.text if label else ""

func _find_label(node: Node, name: String) -> Label:
	if node is Label and node.name == name:
		return node as Label
	for child in node.get_children():
		var found := _find_label(child, name)
		if found:
			return found
	return null

func _find_button(node: Node, name: String) -> Button:
	if node is Button and node.name == name:
		return node as Button
	for child in node.get_children():
		var found := _find_button(child, name)
		if found:
			return found
	return null

func _find_game_over_view(node: Node) -> UltravibeGameOverView:
	if node is UltravibeGameOverView:
		return node as UltravibeGameOverView
	for child in node.get_children():
		var found := _find_game_over_view(child)
		if found:
			return found
	return null
