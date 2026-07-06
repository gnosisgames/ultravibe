extends SceneTree

## Verifies EnableEndlessMode clears terminal run state after a winning run.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Endless Mode Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Endless Mode Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3") if engine else null
	if m3 == null:
		print("[FAIL] Match3 missing")
		return false
	m3.handle_run_started()
	var state := m3.get_node("match3", false)
	state.set_key("isRunComplete", true)
	state.set_key("isRunWon", true)
	state.set_key("runResult", "win")
	state.set_key("winningRound", 24)
	state.set_key("currentRound", 24)
	state.set_key("floorCount", 8)
	var params := engine.store.create_object()
	params.set_key("enabled", true)
	var result = m3.invoke_function("EnableEndlessMode", params)
	if not (result is GnosisFunctionResult) or not result.is_ok:
		print("[FAIL] EnableEndlessMode failed: %s" % (result.error if result is GnosisFunctionResult else result))
		return false
	if _node_bool(state, "endlessModeEnabled", false) != true:
		print("[FAIL] endlessModeEnabled not set")
		return false
	if _node_bool(state, "isRunWon", true):
		print("[FAIL] isRunWon should clear after endless")
		return false
	if _node_bool(state, "isRunComplete", true):
		print("[FAIL] isRunComplete should clear after endless")
		return false
	var progress := _node_str(state, "floorProgressText", "")
	if progress.is_empty():
		print("[FAIL] floorProgressText missing")
		return false
	var models = load("res://game/match3/core/match3_models.gd")
	if m3.get_current_status() != models.STATUS_LEVEL_SELECT_PANEL:
		print("[FAIL] endless should return to level select, status=%d" % m3.get_current_status())
		return false
	print("[SUCCESS] endless mode clears terminal state and opens level select")
	return true

func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)

func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)
