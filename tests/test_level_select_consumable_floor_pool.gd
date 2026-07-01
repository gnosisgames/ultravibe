extends SceneTree

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Level Select Consumable Test ---")
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
	print("--- Level Select Consumable Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3: Match3Service = engine.get_service("Match3") as Match3Service
	var consumable: GnosisConsumableService = engine.get_service("Consumable") as GnosisConsumableService
	if m3 == null or consumable == null:
		print("[FAIL] services missing")
		return false
	# Preview round metadata without loading the board grid (level select state).
	m3.handle_run_started()
	if m3.get_current_status() != Match3Models.STATUS_LEVEL_SELECT_PANEL:
		print("[FAIL] expected level select status")
		return false
	if m3.get_gameplay().grid.size() != 0:
		print("[FAIL] grid should be empty before PlayLevel")
		return false
	var store := engine.store
	var add := store.create_object()
	add.set_key("consumableId", "Chrysomania")
	add.set_key("bucketId", "default")
	consumable.invoke_function("AddConsumable", add)
	var consumed: bool = m3.try_consume_consumable_at_slot_presentation(0)
	if not consumed:
		print("[FAIL] consumable use on level select failed")
		return false
	var counts: Dictionary = m3.get_enhanced_floor_tile_counts()
	if int(counts.get("Gold", 0)) < 2:
		print("[FAIL] pool not updated: %s" % str(counts))
		return false
	print("[SUCCESS] consumable on level select updated pool without grid crash")
	return true
