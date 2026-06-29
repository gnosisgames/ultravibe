extends SceneTree

## Verifies negative ultravibe chance ramps on line-clear intervals (Unity parity).

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Negative Chance Ramp Test ---")
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
	print("--- Negative Ramp Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx = fb.context
	fb.handle_run_started()

	var start_chance := FallingBlockEphemeral.get_fb_int(ctx, "negativeUltravibeChance", -1)
	if start_chance != 1:
		print("[FAIL] starting negative chance %d != 1" % start_chance)
		ok = false
	else:
		print("[SUCCESS] starting negative chance is 1%%")

	var player = fb.get_players()[0]
	fb._on_physical_lines_cleared(player, 5)
	var after_five := FallingBlockEphemeral.get_fb_int(ctx, "negativeUltravibeChance", -1)
	if after_five != 2:
		print("[FAIL] after 5 lines negative chance %d != 2" % after_five)
		ok = false
	else:
		print("[SUCCESS] after 5 lines negative chance is 2%%")

	fb._on_physical_lines_cleared(player, 10)
	var after_fifteen := FallingBlockEphemeral.get_fb_int(ctx, "negativeUltravibeChance", -1)
	if after_fifteen != 4:
		print("[FAIL] after 15 total lines negative chance %d != 4" % after_fifteen)
		ok = false
	else:
		print("[SUCCESS] after 15 total lines negative chance is 4%% (batched +2)")

	return ok
