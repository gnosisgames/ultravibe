extends SceneTree

## Verifies Match-3 in-progress run saves: write, continue restore, clear, invalid save.

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
	if _frames < 12:
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

	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 missing")
		return false

	GnosisRunSave.clear_run_save()
	if GnosisRunSave.has_continuable_save():
		print("[FAIL] save should be absent after clear")
		ok = false

	_setup_mid_run_state(engine, m3)
	if not GnosisRunSave.save_in_progress_run(engine):
		print("[FAIL] save_in_progress_run returned false")
		ok = false
	if not GnosisRunSave.has_continuable_save():
		print("[FAIL] continuable save missing after write")
		ok = false

	var gameplay = m3.get_gameplay()
	var saved_score: int = gameplay.current_score if gameplay else 0
	var saved_round: int = m3.get_current_round()
	var saved_tile: Variant = _first_item_tile(gameplay)

	if not _bootstrap.continue_saved_run():
		print("[FAIL] continue_saved_run returned false")
		ok = false

	var resumed = engine.get_service("Match3")
	if resumed == null:
		print("[FAIL] Match3 missing after continue")
		return false

	var resumed_gameplay = resumed.get_gameplay()
	var resumed_score: int = resumed_gameplay.current_score if resumed_gameplay else 0
	var resumed_round: int = resumed.get_current_round()
	if resumed_score != saved_score:
		print("[FAIL] score not restored, expected %d got %d" % [saved_score, resumed_score])
		ok = false
	if resumed_round != saved_round:
		print("[FAIL] round not restored, expected %d got %d" % [saved_round, resumed_round])
		ok = false
	var resumed_tile: Variant = _first_item_tile(resumed_gameplay)
	if saved_tile == null or resumed_tile == null:
		print("[FAIL] expected a tile with item in saved and resumed grids")
		ok = false
	elif str(resumed_tile.item_id) != str(saved_tile.item_id):
		print("[FAIL] grid tile item not restored")
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

func _setup_mid_run_state(engine: GnosisEngine, m3) -> void:
	m3.handle_run_started()
	var params := engine.store.create_object()
	m3.invoke_function("PlayLevel", params)
	var gameplay = m3.get_gameplay()
	if gameplay == null or not gameplay.is_grid_allocated():
		return
	gameplay.current_score = 2468
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile != null and not tile.item_id.is_empty():
				tile.item_id = "marker_%d_%d" % [x, y]
				return
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui:
		ui.set_base_view("gameplay")

func _first_item_tile(gameplay):
	if gameplay == null or not gameplay.is_grid_allocated():
		return null
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile != null and not tile.item_id.is_empty():
				return tile
	return null

func _write_invalid_save() -> void:
	var path := GnosisRunSave.get_default_path()
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"version": 999, "gameOver": false}, "\t"))
