extends SceneTree

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Play Level + Floor Pool Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _check()
	print("--- Play Level + Floor Pool Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3: Match3Service = engine.get_service("Match3") as Match3Service
	if m3 == null:
		print("[FAIL] Match3 missing")
		return false
	var store := engine.store
	# Seed pool with Gold tiles (mania consumable parity).
	var delta := store.create_object()
	delta.set_key("floorTypeId", "Random")
	delta.set_key("count", 4)
	var add_result: Variant = m3.invoke_function("AddFloorModifierPoolDelta", delta)
	if add_result is GnosisFunctionResult and not add_result.is_ok:
		print("[FAIL] pool delta: %s" % add_result.error)
		return false
	# Start the round (applies pool layout to board).
	var play: Variant = m3.invoke_function("PlayLevel", null)
	if play is GnosisFunctionResult and not play.is_ok:
		print("[FAIL] PlayLevel: %s" % play.error)
		return false
	var counts: Dictionary = m3.get_enhanced_floor_tile_counts()
	print("[INFO] enhanced counts after PlayLevel: ", counts)
	var gameplay = m3.get_gameplay()
	var floor_cells := 0
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile and not tile.cell_floor_type_id.is_empty():
				floor_cells += 1
	print("[INFO] board cells with floor type: ", floor_cells)
	print("[SUCCESS] PlayLevel with floor pool completed")
	return true
