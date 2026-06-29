extends SceneTree

const FallingBlockServiceScript = preload("res://game/services/falling_block_service.gd")

func _initialize() -> void:
	print("--- Lock Delay Feel Test ---")
	var ok := _run()
	print("--- Lock Delay Feel Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _run() -> bool:
	var service := FallingBlockServiceScript.new()
	var run_state := FallingBlockModels.RunState.new()
	var grid_state := FallingBlockModels.GridState.new()
	var player := FallingBlockModels.PlayerState.new()
	player.player_id = "Player1"
	service.set_runtime_references(run_state, grid_state, [player])
	_seed_grounded_piece(grid_state, player)

	player.is_on_ground = true
	player.lock_delay_expires_at_unscaled_time = Time.get_ticks_msec() / 1000.0 + 0.1
	for _i in range(FallingBlockServiceScript.MAX_LOCK_DELAY_REFRESHES_PER_PIECE):
		service._refresh_lock_delay_after_move(player)

	if player.lock_delay_refresh_count != FallingBlockServiceScript.MAX_LOCK_DELAY_REFRESHES_PER_PIECE:
		print("[FAIL] refresh count did not reach cap")
		return false

	var capped_expiry := player.lock_delay_expires_at_unscaled_time
	service._refresh_lock_delay_after_move(player)
	if player.lock_delay_refresh_count != FallingBlockServiceScript.MAX_LOCK_DELAY_REFRESHES_PER_PIECE:
		print("[FAIL] refresh count exceeded cap")
		return false
	if player.lock_delay_expires_at_unscaled_time != capped_expiry:
		print("[FAIL] lock delay expiry changed after cap")
		return false

	print("[SUCCESS] lock delay refreshes are capped per piece")
	return true

func _seed_grounded_piece(grid_state: FallingBlockModels.GridState, player: FallingBlockModels.PlayerState) -> void:
	grid_state.width = 10
	grid_state.height = 24
	grid_state.hidden_rows = 4
	grid_state.ensure_cells()
	player.current_piece_instance_id = "test_piece"
	player.current_piece_origin = Vector2i(4, 0)
	var cell := FallingBlockModels.CellState.new()
	cell.block_id = "test_block"
	cell.piece_instance_id = player.current_piece_instance_id
	cell.ultravibe_id = "Mono1"
	cell.variant_id = "blue"
	cell.is_locked = false
	grid_state.cells[4] = cell
