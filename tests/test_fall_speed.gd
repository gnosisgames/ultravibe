extends SceneTree

## Verifies the gravity curve: starting seconds-per-cell matches the normal-difficulty
## guideline, and gravity gets faster (smaller seconds/cell) after lines are cleared.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Fall Speed / Gravity Curve Test ---")
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
	print("--- Fall Speed Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx = fb.context

	var starting := FallingBlockEphemeral.get_fb_float(ctx, "gravitySecondsPerCell", -1.0)
	var expected_start := FallingBlockGravityCurve.resolve_starting_seconds_per_cell("normal", 10)
	if absf(starting - expected_start) > 0.0001:
		print("[FAIL] starting gravity %f != expected %f" % [starting, expected_start])
		ok = false
	else:
		print("[SUCCESS] starting gravity %.4f s/cell (normal)" % starting)

	# Simulate clearing a large number of lines, then refresh gravity.
	var p = fb.get_players()[0]
	fb._on_physical_lines_cleared(p, 60)
	var after := FallingBlockEphemeral.get_fb_float(ctx, "gravitySecondsPerCell", -1.0)
	if after >= starting:
		print("[FAIL] gravity did not speed up after clears (%.4f -> %.4f)" % [starting, after])
		ok = false
	else:
		print("[SUCCESS] gravity sped up after 60 lines (%.4f -> %.4f s/cell)" % [starting, after])

	# Tick interval should reflect the (faster) gravity.
	var tick := fb._get_gravity_tick_interval_seconds()
	if absf(tick - after) > 0.0001:
		print("[FAIL] tick interval %.4f != gravity %.4f" % [tick, after])
		ok = false
	else:
		print("[SUCCESS] tick interval tracks gravity (%.4f s)" % tick)

	return ok
