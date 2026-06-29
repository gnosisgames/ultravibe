extends SceneTree

## Parity: FallingBlock invocation surface (consumables/abilities/upgrades).

const PH = preload("res://tests/helpers/parity_harness.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Parity Invocations Test ---")
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
	print("--- Parity Invocations Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var fb := PH.get_falling_block(_bootstrap)
	var player: FallingBlockModels.PlayerState = fb.get_players()[0]
	if player.current_piece_instance_id.is_empty():
		fb._spawn_piece_for_player(player, "Line4", "blue")

	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "AddBaseDiscardsDelta", {"delta": 2}),
		"AddBaseDiscardsDelta"
	) and ok

	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "AddVariantLevelDelta", {"variantId": "blue", "delta": 1}),
		"AddVariantLevelDelta"
	) and ok

	var level := fb._resolve_variant_level("blue")
	if level < 2:
		print("[FAIL] variant level for blue expected >=2, got %d" % level)
		ok = false
	else:
		print("[SUCCESS] variant level blue=%d" % level)

	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "SetFallingPieceVariant", {"variantId": "red", "playerId": player.player_id}),
		"SetFallingPieceVariant"
	) and ok

	var grid := fb.get_grid_state()
	var has_red := false
	for cell in grid.cells:
		if cell != null and cell.piece_instance_id == player.current_piece_instance_id and cell.variant_id == "red":
			has_red = true
			break
	if not has_red:
		print("[FAIL] SetFallingPieceVariant did not recolor active piece")
		ok = false
	else:
		print("[SUCCESS] active piece recolored to red")

	PH.lock_row(grid, 5, "blue")
	PH.lock_row(grid, 10, "blue")
	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "ClearRowsAboveLowestNonEmptyColumnHeight", {}),
		"ClearRowsAboveLowestNonEmptyColumnHeight"
	) and ok

	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "ChangeFallSpeed", {"deltaLevels": -1}),
		"ChangeFallSpeed"
	) and ok

	PH.clear_grid(grid)
	for x in range(grid.width):
		if x != 4:
			PH.lock_cell(grid, x, 3, "blue")
	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "FillSingleGapsInNonEmptyRowsAndClear", {}),
		"FillSingleGapsInNonEmptyRowsAndClear"
	) and ok
	var row3_count := PH.count_locked_in_row(grid, 3)
	if row3_count != 0:
		print("[FAIL] gum single-gap row should clear, row 3 locked count=%d" % row3_count)
		ok = false
	else:
		print("[SUCCESS] gum filled the single gap and cleared the completed row")

	PH.clear_grid(grid)
	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "SpawnTrashLines", {
			"lineCount": 1,
			"variantId": "disabled",
			"minGaps": 1,
			"maxGaps": 1,
			"gapColumnStickProbability": 0.0,
		}),
		"SpawnTrashLines"
	) and ok
	var bottom_locked := PH.count_locked_in_row(grid, 0)
	if bottom_locked != grid.width - 1:
		print("[FAIL] trash line expected %d locked cells, got %d" % [grid.width - 1, bottom_locked])
		ok = false
	else:
		print("[SUCCESS] trash line spawned with one gap")

	PH.clear_grid(grid)
	PH.lock_cell(grid, grid.width - 1, 2, "orange")
	ok = PH.assert_fn_ok(
		PH.invoke_fb(fb, "MirrorRightHalfToLeftAndClear", {}),
		"MirrorRightHalfToLeftAndClear"
	) and ok
	var mirrored: FallingBlockModels.CellState = grid.cells[2 * grid.width]
	if mirrored == null or not mirrored.is_locked or mirrored.variant_id != "orange":
		print("[FAIL] mirror did not copy right edge block to left edge")
		ok = false
	else:
		print("[SUCCESS] mirror copied right half blocks onto the left half")

	return ok
