class_name ParityHarness
extends RefCounted

## Deterministic helpers for parity tests: boot engine, seed grid, invoke mechanics.

static func boot_main(scene_tree: SceneTree, wait_frames: int = 8) -> Node:
	var bootstrap: Node = load("res://main.tscn").instantiate()
	scene_tree.root.add_child(bootstrap)
	for _i in range(wait_frames):
		await scene_tree.process_frame
	return bootstrap

static func get_falling_block(bootstrap: Node) -> FallingBlockService:
	return bootstrap.engine.get_service("FallingBlock") as FallingBlockService

static func lock_row(grid: FallingBlockModels.GridState, y: int, variant_id: String = "blue") -> void:
	for x in range(grid.width):
		var cell := FallingBlockModels.CellState.new()
		cell.block_id = "%d_%d" % [x, y]
		cell.piece_instance_id = "test_row_%d" % y
		cell.ultravibe_id = "Square4"
		cell.variant_id = variant_id
		cell.is_locked = true
		grid.cells[y * grid.width + x] = cell

static func lock_cell(grid: FallingBlockModels.GridState, x: int, y: int, variant_id: String = "blue") -> void:
	var cell := FallingBlockModels.CellState.new()
	cell.block_id = "%d_%d" % [x, y]
	cell.piece_instance_id = "test_cell_%d_%d" % [x, y]
	cell.ultravibe_id = "Square4"
	cell.variant_id = variant_id
	cell.is_locked = true
	grid.cells[y * grid.width + x] = cell

static func clear_grid(grid: FallingBlockModels.GridState) -> void:
	for i in range(grid.cells.size()):
		grid.cells[i] = FallingBlockModels.CellState.new()

static func count_locked_cells(grid: FallingBlockModels.GridState) -> int:
	var n: int = 0
	for cell in grid.cells:
		if cell != null and cell.is_locked and not cell.block_id.is_empty():
			n += 1
	return n

static func count_locked_in_row(grid: FallingBlockModels.GridState, y: int) -> int:
	var n := 0
	for x in range(grid.width):
		var cell: FallingBlockModels.CellState = grid.cells[y * grid.width + x]
		if cell != null and cell.is_locked and not cell.block_id.is_empty():
			n += 1
	return n

static func invoke_fb(fb: FallingBlockService, function_name: String, params: Dictionary = {}) -> GnosisFunctionResult:
	var node := fb.context.store.create_object()
	for k in params.keys():
		node.set_key(k, params[k])
	var result = fb.invoke_function(function_name, node)
	return result if result is GnosisFunctionResult else GnosisFunctionResult.fail("Not a GnosisFunctionResult")

static func assert_fn_ok(result: GnosisFunctionResult, label: String) -> bool:
	if result == null or not (result is GnosisFunctionResult):
		print("[FAIL] %s: null result" % label)
		return false
	if not result.is_ok:
		print("[FAIL] %s: %s" % [label, result.error if result.has_method("get") else "failed"])
		return false
	print("[SUCCESS] %s" % label)
	return true
