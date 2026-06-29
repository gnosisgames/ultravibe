extends SceneTree

const FallingBlockServiceScript = preload("res://game/services/falling_block_service.gd")
const UltravibeRegistryScript = preload("res://game/services/ultravibe_registry.gd")

func _initialize() -> void:
	print("--- Running Ultravibe Falling Block Core Test ---")
	_test_registry_loads_shapes()
	_test_spawn_move_lock_and_clear()
	print("\n--- Ultravibe Core Test Passed ---")
	quit(0)

func _test_registry_loads_shapes() -> void:
	var registry := UltravibeRegistryScript.new()
	registry.load_shapes()
	var ids := registry.get_all_shape_ids()
	assert(ids.size() >= 10, "Expected at least 10 ultravibe shapes")
	var line4 := registry.get_shape("Line4")
	assert(line4 != null, "Line4 shape should exist")
	assert(line4.block_offsets.size() == 4, "Line4 should have 4 blocks")
	print("[SUCCESS] Ultravibe registry loaded %d shapes." % ids.size())

func _test_spawn_move_lock_and_clear() -> void:
	var service := FallingBlockServiceScript.new()
	var run_state := FallingBlockModels.RunState.new()
	var grid_state := FallingBlockModels.GridState.new()
	var player := FallingBlockModels.PlayerState.new()
	player.player_id = "Player1"
	var registry := UltravibeRegistryScript.new()
	registry.load_shapes()

	var config := GnosisEngineConfig.new()
	config.register_service("FallingBlock", GnosisLifetime.TRANSIENT, func(): return service)
	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	service.set_runtime_references(run_state, grid_state, [player], registry)
	service.handle_run_started()
	# This minimal harness has no Deck service to answer FACT_FALLING_BLOCK_SPAWN_NEEDED,
	# so drive the spawn directly (the full deck->spawn pipeline is covered by tests/test_full_boot.gd).
	service._spawn_piece_for_player(player, "Line4", "blue")
	assert(not player.current_piece_instance_id.is_empty(), "A piece should spawn on run start")

	var moved := false
	for _i in range(4):
		var input := FallingBlockModels.InputEventData.new()
		input.player_id = "Player1"
		input.type = FallingBlockModels.InputType.MOVE_LEFT
		service.handle_input(input)
		moved = true
	assert(moved, "Piece should accept horizontal input")

	# Run-start scoring init: round 1, fresh progress, a positive objective target.
	var ctx = service.context
	assert(FallingBlockEphemeral.get_fb_int(ctx, "currentRound", 0) == 1, "currentRound should reset to 1")
	assert(FallingBlockEphemeral.get_fb_int(ctx, "roundLinesCurrent", -1) == 0, "roundLinesCurrent should start at zero")
	assert(FallingBlockEphemeral.get_fb_int(ctx, "roundLinesNeeded", 0) == 5, "round 1 should need 5 lines")

	# Spawn guards block hard drops for MIN_SECONDS_AFTER_SPAWN_BEFORE_HARD_DROP (0.15s);
	# this synchronous test would otherwise be rejected, so advance wall-clock time.
	OS.delay_msec(200)

	# Hard drop to lock and attempt line interactions.
	var hard_drop := FallingBlockModels.InputEventData.new()
	hard_drop.player_id = "Player1"
	hard_drop.type = FallingBlockModels.InputType.HARD_DROP
	service.handle_input(hard_drop)
	assert(player.current_piece_instance_id.is_empty(), "Piece should lock after hard drop")

	print("[SUCCESS] Falling block spawn/move/lock loop works.")
