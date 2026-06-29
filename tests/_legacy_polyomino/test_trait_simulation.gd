extends SceneTree

const FallingBlockServiceScript = preload("res://game/services/falling_block_service.gd")
const UltravibeRegistryScript = preload("res://game/services/ultravibe_registry.gd")
const TraitTags := preload("res://game/services/falling_block_trait_tags.gd")

func _initialize() -> void:
	print("--- Running Trait Simulation Test ---")
	var ok := true
	ok = _test_spawn_cells_carry_full_variant_tags() and ok
	ok = _test_moss_expands_on_each_placement() and ok
	ok = _test_obsidian_survives_line_clear() and ok
	ok = _test_blightmoss_rises_vertically() and ok
	print("\n--- Trait Simulation Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _make_service() -> FallingBlockService:
	var service := FallingBlockServiceScript.new()
	var run_state := FallingBlockModels.RunState.new()
	var grid_state := FallingBlockModels.GridState.new()
	grid_state.width = 10
	grid_state.height = 20
	grid_state.hidden_rows = 0
	grid_state.ensure_cells()
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
	return service

func _test_spawn_cells_carry_full_variant_tags() -> bool:
	var service := _make_service()
	var tags := service._resolve_variant_tags("moss")
	if not tags.has("expansive"):
		print("[FAIL] moss variant tags missing expansive (got %s)" % str(tags))
		return false
	if not tags.has("color_green"):
		print("[FAIL] moss variant tags missing color_green (got %s)" % str(tags))
		return false
	print("[SUCCESS] variant tags include gameplay + color traits")
	return true

func _test_moss_expands_on_each_placement() -> bool:
	var service := _make_service()
	var grid := service._runtime_grid_state
	_seed_locked_cell(grid, 4, 4, "moss")
	FallingBlockEphemeral.get_fb(service.context).set_key("tagChanceExpansive", 100)
	var before := _count_variant_cells(grid, "moss")
	service._tag_sim.on_piece_placed("dummy_piece")
	var after_first := _count_variant_cells(grid, "moss")
	service._tag_sim.on_piece_placed("dummy_piece_2")
	var after_second := _count_variant_cells(grid, "moss")
	if after_first <= before:
		print("[FAIL] moss did not expand on first placement (%d -> %d)" % [before, after_first])
		return false
	if after_second <= after_first:
		print("[FAIL] moss did not expand again on second placement (%d -> %d)" % [after_first, after_second])
		return false
	print("[SUCCESS] moss expanded on consecutive placements (%d -> %d -> %d)" % [before, after_first, after_second])
	return true

func _test_obsidian_survives_line_clear() -> bool:
	var service := _make_service()
	var grid := service._runtime_grid_state
	var y := 0
	for x in range(grid.width):
		var variant := "obsidian" if x == 5 else "blue"
		_seed_locked_cell(grid, x, y, variant)
	var cleared := service._grid_system.clear_full_rows_and_collapse(grid)
	if cleared != 1:
		print("[FAIL] expected one cleared row, got %d" % cleared)
		return false
	var survivor: FallingBlockModels.CellState = grid.cells[5]
	if survivor == null or survivor.block_id.is_empty() or survivor.variant_id != "obsidian":
		print("[FAIL] obsidian block did not survive line clear")
		return false
	if not TraitTags.cell_has_tag(survivor, "eternal", service._get_variant_tags("obsidian")):
		print("[FAIL] surviving obsidian cell missing eternal trait resolution")
		return false
	print("[SUCCESS] obsidian survived a full line clear")
	return true

func _test_blightmoss_rises_vertically() -> bool:
	var service := _make_service()
	var grid := service._runtime_grid_state
	_seed_locked_cell(grid, 4, 4, "blightmoss")
	FallingBlockEphemeral.get_fb(service.context).set_key("tagChanceRising", 100)
	var before := _count_variant_cells(grid, "blightmoss")
	service._tag_sim.on_piece_placed("dummy_piece")
	var after := _count_variant_cells(grid, "blightmoss")
	if after <= before:
		print("[FAIL] blightmoss did not spread vertically (%d -> %d)" % [before, after])
		return false
	var spread_up := grid.cells[5 * grid.width + 4]
	var spread_down := grid.cells[3 * grid.width + 4]
	if (spread_up == null or spread_up.variant_id != "blightmoss") and (spread_down == null or spread_down.variant_id != "blightmoss"):
		print("[FAIL] blightmoss spread did not appear in vertical neighbors")
		return false
	print("[SUCCESS] blightmoss spread into vertical neighbors")
	return true

func _seed_locked_cell(grid: FallingBlockModels.GridState, x: int, y: int, variant_id: String) -> void:
	var cell := FallingBlockModels.CellState.new()
	cell.block_id = "seed_%d_%d" % [x, y]
	cell.piece_instance_id = "seed_piece"
	cell.ultravibe_id = "Square4"
	cell.variant_id = variant_id
	cell.is_locked = true
	cell.tags = ["color_red"]
	grid.cells[y * grid.width + x] = cell

func _count_variant_cells(grid: FallingBlockModels.GridState, variant_id: String) -> int:
	var count := 0
	for cell in grid.cells:
		if cell != null and cell.variant_id == variant_id and not cell.block_id.is_empty():
			count += 1
	return count
