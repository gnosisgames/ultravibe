extends SceneTree

## Verifies simplified line scoring and lines-based round objectives.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Line Scoring / Round Lines Test ---")
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
	print("--- Line Scoring Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx = fb.context
	fb.handle_run_started()

	if FallingBlockLineScoring.score_for_lines(1) != 100:
		print("[FAIL] single-line score")
		ok = false
	elif FallingBlockLineScoring.score_for_lines(4) != 1000:
		print("[FAIL] quad-line score")
		ok = false
	elif FallingBlockLineScoring.score_for_lines(6) != 5000:
		print("[FAIL] penta+ line score")
		ok = false
	else:
		print("[SUCCESS] fixed line score table")

	var target_r1 := FallingBlockRoundLines.target_lines_for_round(1)
	var target_r5 := FallingBlockRoundLines.target_lines_for_round(5)
	if target_r1 != 5 or target_r5 != 9:
		print("[FAIL] round targets %d / %d" % [target_r1, target_r5])
		ok = false
	else:
		print("[SUCCESS] round targets 5 then +1 per round")

	var player = fb.get_players()[0]
	fb._on_physical_lines_cleared(player, 2)
	var score := FallingBlockEphemeral.get_fb_scalable(ctx, "runTotalScore").to_int()
	var progress := FallingBlockEphemeral.get_fb_int(ctx, "roundLinesCurrent", 0)
	if score != 250 or progress != 2:
		print("[FAIL] double clear score/progress %d / %d" % [score, progress])
		ok = false
	else:
		print("[SUCCESS] double clear -> 250 score and 2 lines progress")

	return ok
