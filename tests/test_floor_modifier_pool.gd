extends SceneTree

## Verifies Match3 floor modifier pool + HUD count helper.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Floor Modifier Pool Test ---")
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
	print("--- Floor Modifier Pool Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var store := engine.store
	var params := store.create_object()
	params.set_key("floorTypeId", "Gold")
	params.set_key("count", 3)
	var result = m3.invoke_function("AddFloorModifierPoolDelta", params)
	if not (result is GnosisFunctionResult):
		print("[FAIL] expected GnosisFunctionResult, got %s" % typeof(result))
		return false
	if not result.is_ok:
		print("[FAIL] AddFloorModifierPoolDelta: %s" % result.error)
		return false
	var counts: Dictionary = m3.get_enhanced_floor_tile_counts()
	if int(counts.get("Gold", 0)) != 3:
		print("[FAIL] enhanced counts %s (expected Gold=3)" % str(counts))
		return false
	var eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	var pool := eph.get_node("floorModifierPool")
	if not pool.is_valid():
		print("[FAIL] Ephemeral.match3.floorModifierPool missing after commit")
		return false
	var gold_node := pool.get_node("Gold")
	var gold_count := int(gold_node.value) if gold_node.is_valid() else -1
	if gold_count != 3:
		print("[FAIL] pool Gold=%d (expected 3)" % gold_count)
		return false
	print("[SUCCESS] floor pool Gold=3, enhanced tile counts published")
	return true
