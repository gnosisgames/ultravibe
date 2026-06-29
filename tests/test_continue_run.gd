extends SceneTree

## Verifies in-progress run saves: write, continue restore, clear, and invalid-save handling.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Continue Run Test ---")
	GnosisRunSave.clear_run_save()
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
	print("--- Continue Run Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var fb := engine.get_service("FallingBlock") as FallingBlockService
	if fb == null:
		print("[FAIL] FallingBlock missing")
		return false

	GnosisRunSave.clear_run_save()
	if GnosisRunSave.has_continuable_save():
		print("[FAIL] save should be absent after clear")
		ok = false

	_setup_mid_run_state(engine, fb)
	if not GnosisRunSave.save_in_progress_run(engine):
		print("[FAIL] save_in_progress_run returned false")
		ok = false
	if not GnosisRunSave.has_continuable_save():
		print("[FAIL] continuable save missing after write")
		ok = false

	var saved_score := FallingBlockEphemeral.get_fb_scalable(fb.context, "runTotalScore")
	var saved_round := FallingBlockEphemeral.get_fb_int(fb.context, "currentRound", 0)
	var saved_elapsed := fb.get_run_elapsed_seconds()
	var saved_counter := fb.get_piece_instance_counter()
	var saved_cell := _first_non_empty_cell(fb.get_grid_state())

	if not _bootstrap.continue_saved_run():
		print("[FAIL] continue_saved_run returned false")
		ok = false

	var resumed_fb := engine.get_service("FallingBlock") as FallingBlockService
	if resumed_fb == null:
		print("[FAIL] FallingBlock missing after continue")
		return false

	var resumed_score := FallingBlockEphemeral.get_fb_scalable(resumed_fb.context, "runTotalScore")
	var resumed_round := FallingBlockEphemeral.get_fb_int(resumed_fb.context, "currentRound", 0)
	if resumed_score.coefficient != saved_score.coefficient \
			or resumed_score.suffix_index != saved_score.suffix_index:
		print("[FAIL] score not restored")
		ok = false
	if resumed_round != saved_round:
		print("[FAIL] round not restored, expected %d got %d" % [saved_round, resumed_round])
		ok = false
	if not is_equal_approx(resumed_fb.get_run_elapsed_seconds(), saved_elapsed):
		print("[FAIL] elapsed seconds not restored")
		ok = false
	if resumed_fb.get_piece_instance_counter() != saved_counter:
		print("[FAIL] piece counter not restored")
		ok = false
	var resumed_cell := _first_non_empty_cell(resumed_fb.get_grid_state())
	if resumed_cell == null or saved_cell == null:
		print("[FAIL] expected a locked cell in saved and resumed grids")
		ok = false
	elif str(resumed_cell.variant_id) != str(saved_cell.variant_id):
		print("[FAIL] grid cell variant not restored")
		ok = false

	GnosisRunSave.clear_run_save()
	if GnosisRunSave.has_continuable_save():
		print("[FAIL] save should clear")
		ok = false

	_write_invalid_save()
	if GnosisRunSave.has_continuable_save():
		print("[FAIL] invalid save should be ignored and deleted")
		ok = false
	if FileAccess.file_exists(GnosisRunSave.get_default_path()):
		print("[FAIL] invalid save file should be deleted")
		ok = false

	if ok:
		print("[SUCCESS] continue run save/load/clear behavior verified")
	return ok

func _setup_mid_run_state(engine: GnosisEngine, fb: FallingBlockService) -> void:
	var run_state := FallingBlockModels.RunState.new()
	var grid_state := FallingBlockModels.GridState.new()
	var player := FallingBlockModels.PlayerState.new()
	player.player_id = "Player1"
	var registry := UltravibeRegistry.new()
	registry.load_shapes()
	fb.set_runtime_references(run_state, grid_state, [player], registry)
	fb.handle_run_started()
	FallingBlockEphemeral.set_fb_scalable(fb.context, "runTotalScore", GnosisScalableValue.from_int(4321))
	FallingBlockEphemeral.set_fb_int(fb.context, "currentRound", 3)
	fb.set_piece_instance_counter(7)
	fb.debug_set_run_elapsed_seconds(42.0)
	var grid := fb.get_grid_state()
	if grid == null:
		return
	grid.ensure_cells()
	var cell := grid.cells[grid.width * 2 + 4] as FallingBlockModels.CellState
	if cell:
		cell.block_id = "test-block"
		cell.variant_id = "blue"
		cell.ultravibe_id = "mono"
		cell.is_locked = true
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui:
		ui.set_base_view("gameplay")

func _first_non_empty_cell(grid: FallingBlockModels.GridState):
	if grid == null:
		return null
	for cell in grid.cells:
		if cell != null and not str(cell.block_id).is_empty():
			return cell
	return null

func _write_invalid_save() -> void:
	var path := GnosisRunSave.get_default_path()
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 999, "gameOver": false}, "\t"))
