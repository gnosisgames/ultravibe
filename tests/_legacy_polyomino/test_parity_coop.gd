extends SceneTree

## Parity: co-op split-lane row clearing and player runtime helpers.

const PlayerRuntime = preload("res://game/services/falling_block_player_runtime.gd")
const SpawnResolver = preload("res://game/services/falling_block_spawn_resolver.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Parity Co-op Test ---")
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
	print("--- Parity Co-op Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var fb := _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
	var ctx: GnosisContext = fb.context
	var eph := ctx.state.root.get_node("Ephemeral")
	eph.set_key("playerCount", 3)
	eph.set_key("mode", "coop")

	var min_x: Array = []
	var max_x: Array = []
	if not PlayerRuntime.try_get_lane_bounds(10, 3, 1, min_x, max_x):
		print("[FAIL] lane bounds for P1 in 3p co-op")
		ok = false
	elif min_x[0] != 3 or max_x[0] != 5:
		print("[FAIL] P1 lane expected x=3..5, got %d..%d" % [min_x[0], max_x[0]])
		ok = false
	else:
		print("[SUCCESS] P1 lane bounds 3..5 for 3-player co-op")

	var grid := fb.get_grid_state()
	# Fill only lane 1 segment on row 5 — should NOT clear in co-op mode.
	for x in range(min_x[0], max_x[0] + 1):
		var cell := FallingBlockModels.CellState.new()
		cell.block_id = "c_%d" % x
		cell.variant_id = "blue"
		cell.is_locked = true
		grid.cells[5 * grid.width + x] = cell

	if fb._coop.is_row_clearable_for_mode(grid, 5):
		print("[FAIL] partial lane row incorrectly clearable in co-op")
		ok = false
	else:
		print("[SUCCESS] partial lane row not clearable in co-op")

	# Fill all three lane segments on row 6.
	for lane in range(3):
		var bmin: Array = []
		var bmax: Array = []
		PlayerRuntime.try_get_lane_bounds(grid.width, 3, lane, bmin, bmax)
		for x in range(bmin[0], bmax[0] + 1):
			var cell := FallingBlockModels.CellState.new()
			cell.block_id = "full_%d_%d" % [lane, x]
			cell.variant_id = "blue"
			cell.is_locked = true
			grid.cells[6 * grid.width + x] = cell

	if not fb._coop.is_row_clearable_for_mode(grid, 6):
		print("[FAIL] full co-op row should be clearable")
		ok = false
	else:
		print("[SUCCESS] full co-op row clearable when all lanes filled")

	var player: FallingBlockModels.PlayerState = fb.get_players()[0]
	player.player_id = "P0"
	if not player.current_piece_instance_id.is_empty():
		fb._piece_lifecycle.clear_active_piece(grid, player)
	fb._spawn_piece_for_player(player, "Square4", "blue")
	var lane_min: Array = []
	var lane_max: Array = []
	PlayerRuntime.try_get_lane_bounds(grid.width, 3, 0, lane_min, lane_max)
	if not _active_piece_within_bounds(grid, player.current_piece_instance_id, lane_min[0], lane_max[0]):
		print("[FAIL] spawned co-op piece was not clamped into P0 lane")
		ok = false
	else:
		print("[SUCCESS] spawned co-op piece clamped into P0 lane")
	for _i in range(8):
		var input := FallingBlockModels.InputEventData.new()
		input.player_id = player.player_id
		input.type = FallingBlockModels.InputType.MOVE_RIGHT
		fb.handle_input(input)
	if not _active_piece_within_bounds(grid, player.current_piece_instance_id, lane_min[0], lane_max[0]):
		print("[FAIL] repeated move-right input escaped P0 co-op lane")
		ok = false
	else:
		print("[SUCCESS] repeated input kept active piece inside P0 lane")

	if PlayerRuntime.normalize_runtime_player_id("Player2") != "P1":
		print("[FAIL] Player2 should map to P1")
		ok = false
	else:
		print("[SUCCESS] Rewired-style player ids normalize to P0..P3")

	var p1_center := SpawnResolver.lane_center_x(grid, "P1", 3)
	if p1_center < min_x[0] or p1_center > max_x[0]:
		print("[FAIL] P1 lane center should fall inside lane bounds")
		ok = false
	else:
		print("[SUCCESS] lane-centered spawn helper resolves P1 center at x=%d" % p1_center)

	# Co-op widens the board (Unity parity): per-player base 10, capped at 32 total.
	var expected_widths := {1: 10, 2: 20, 3: 30, 4: 32}
	for count in expected_widths:
		var got := PlayerRuntime.adjust_grid_width_for_player_count(10, count)
		if got != expected_widths[count]:
			print("[FAIL] %dp board width expected %d, got %d" % [count, expected_widths[count], got])
			ok = false
		else:
			print("[SUCCESS] %dp board widened to %d columns" % [count, got])

	if not _test_per_player_queues(ctx):
		ok = false

	return ok

## Each player owns an independent next-piece queue while sharing the single
## deckEntries pool. Solo uses "P0", so the model is uniform everywhere.
func _test_per_player_queues(ctx: GnosisContext) -> bool:
	var ok := true
	var deck = _bootstrap.engine.get_service("Deck")
	if deck == null:
		print("[FAIL] Deck service missing for queue test")
		return false

	var fb_node := FallingBlockEphemeral.get_fb(ctx)
	var deck_entries := fb_node.get_node("deckEntries")
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST or deck_entries.get_count() <= 0:
		print("[FAIL] shared deckEntries should be a non-empty list")
		return false

	var size := FallingBlockDeckService.NEXT_PIECES_QUEUE_SIZE
	deck._ensure_next_pieces_queue_filled("P0", "test")
	deck._ensure_next_pieces_queue_filled("P1", "test")

	var queues := fb_node.get_node("nextPiecesQueues")
	if not queues.is_valid() or queues.get_type() != GnosisValueType.OBJECT:
		print("[FAIL] nextPiecesQueues should be an object keyed by player id")
		return false
	var q0 := queues.get_node("P0")
	var q1 := queues.get_node("P1")
	if not q0.is_valid() or q0.get_type() != GnosisValueType.LIST or q0.get_count() != size:
		print("[FAIL] P0 queue should hold %d previews" % size)
		ok = false
	elif not q1.is_valid() or q1.get_type() != GnosisValueType.LIST or q1.get_count() != size:
		print("[FAIL] P1 queue should hold %d previews" % size)
		ok = false
	else:
		print("[SUCCESS] per-player queues filled independently (P0/P1 each %d)" % size)

	# Independence: emptying P0 must not disturb P1.
	deck._set_player_queue("P0", ctx.store.create_list())
	var q0_after := fb_node.get_node("nextPiecesQueues").get_node("P0")
	var q1_after := fb_node.get_node("nextPiecesQueues").get_node("P1")
	if q0_after.get_count() != 0:
		print("[FAIL] P0 queue should be empty after reset")
		ok = false
	elif q1_after.get_count() != size:
		print("[FAIL] P1 queue must be unaffected by P0 reset, got %d" % q1_after.get_count())
		ok = false
	else:
		print("[SUCCESS] per-player queues are independent (P0 reset left P1 intact)")
	return ok

func _active_piece_within_bounds(
	grid: FallingBlockModels.GridState,
	piece_id: String,
	min_x: int,
	max_x: int
) -> bool:
	if piece_id.is_empty():
		return false
	var saw_piece := false
	for i in range(grid.cells.size()):
		var cell: FallingBlockModels.CellState = grid.cells[i]
		if cell == null or cell.piece_instance_id != piece_id or cell.is_locked:
			continue
		saw_piece = true
		var x := i % grid.width
		if x < min_x or x > max_x:
			return false
	return saw_piece
