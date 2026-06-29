extends SceneTree

## Full-stack integration boot test: instantiates main.tscn (UltravibeBootstrap),
## lets the engine boot + start a run, then verifies the deck->spawn->scoring pipeline.

var _bootstrap: Node = null
var _frames := 0
var _finished := false

func _initialize() -> void:
	print("--- Running Ultravibe Full Boot Test ---")
	var scene: PackedScene = load("res://main.tscn")
	if scene == null:
		push_error("Could not load main.tscn")
		quit(1)
		return
	_bootstrap = scene.instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	# Give the engine a few frames to boot, start the run, and spawn the first piece.
	if _frames < 8:
		return false
	if _finished:
		return true
	_finished = true
	var ok := _run_assertions()
	print("\n--- Ultravibe Full Boot Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run_assertions() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		push_error("[FAIL] Engine did not boot")
		return false
	print("[SUCCESS] Engine booted")

	# Configuration must have loaded ultravibes + variants from the manifest.
	var config_svc := engine.get_service("Configuration")
	if config_svc == null:
		push_error("[FAIL] Configuration service missing")
		ok = false

	var fb_service := engine.get_service("FallingBlock") as FallingBlockService
	if fb_service == null:
		push_error("[FAIL] FallingBlock service missing")
		return false

	var players := fb_service.get_players()
	if players.is_empty():
		push_error("[FAIL] No players registered")
		return false
	var player = players[0]
	if player.current_piece_instance_id.is_empty():
		push_error("[FAIL] No piece spawned after boot (deck->spawn pipeline)")
		ok = false
	else:
		print("[SUCCESS] First piece spawned: %s" % player.current_piece_instance_id)

	var ctx = fb_service.context
	var round_no := FallingBlockEphemeral.get_fb_int(ctx, "currentRound", 0)
	if round_no != 1:
		push_error("[FAIL] currentRound expected 1, got %d" % round_no)
		ok = false
	else:
		print("[SUCCESS] currentRound initialized to 1")

	var needed := FallingBlockEphemeral.get_fb_int(ctx, "roundLinesNeeded", 0)
	if needed <= 0:
		push_error("[FAIL] roundLinesNeeded not positive")
		ok = false
	else:
		print("[SUCCESS] roundLinesNeeded initialized to %d" % needed)

	# Grid must be sized.
	var grid := fb_service.get_grid_state()
	if grid == null or grid.width <= 0 or grid.cells.is_empty():
		push_error("[FAIL] Grid not initialized")
		ok = false
	else:
		print("[SUCCESS] Grid initialized: %dx%d" % [grid.width, grid.height])

	return ok
