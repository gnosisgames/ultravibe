extends SceneTree

## Floor-pool consumable on level select must not crash when the board view syncs.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Level Select Floor Consumable Dispatcher Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _check()
	print("--- Level Select Floor Consumable Dispatcher Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3: Match3Service = engine.get_service("Match3") as Match3Service
	var consumable: GnosisConsumableService = engine.get_service("Consumable") as GnosisConsumableService
	if m3 == null or consumable == null:
		print("[FAIL] services missing")
		return false
	m3.handle_run_started()
	var gameplay = m3.get_gameplay()
	if gameplay.grid.size() != 0:
		print("[FAIL] grid should stay empty before PlayLevel")
		return false
	var dispatcher := _bootstrap.get_tree().get_first_node_in_group("match3_dispatcher")
	if dispatcher == null:
		print("[FAIL] Match3Dispatcher missing")
		return false
	if dispatcher.has_method("bind_service"):
		dispatcher.bind_service(m3)
	var add := engine.store.create_object()
	add.set_key("consumableId", "Chrysomania")
	add.set_key("bucketId", "default")
	consumable.invoke_function("AddConsumable", add)
	if not m3.try_consume_consumable_at_slot_presentation(0):
		print("[FAIL] floor consumable use failed on level select")
		return false
	if int(m3.get_enhanced_floor_tile_counts().get("Gold", 0)) < 2:
		print("[FAIL] pool not updated after consumable: %s" % str(m3.get_enhanced_floor_tile_counts()))
		return false
	if dispatcher.has_method("bind_service"):
		dispatcher.bind_service(m3)
	print("[SUCCESS] floor consumable + dispatcher sync on empty grid")
	return true
