extends SceneTree

## Verifies run restarts reset Ephemeral run data without wiping Persistent
## progression/settings data such as discovered items and input assignments.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Persistence Boundaries Test ---")
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
	print("--- Persistence Boundaries Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var input := engine.get_service("Input") as GnosisInputService
	var m3 = engine.get_service("Match3")
	if input == null or m3 == null:
		print("[FAIL] Input/Match3 services missing")
		return false

	FallingBlockCollection.mark_discovered(m3.context, "ability", "testAbility")
	var assignments := engine.store.create_object()
	var move_right := engine.store.create_object()
	move_right.set_key("keycode", KEY_L)
	move_right.set_key("physicalKeycode", KEY_L)
	move_right.set_key("displayName", "L")
	assignments.set_key("move_right", move_right)
	var assignment_result := input.update_assignments(assignments)
	if not assignment_result.is_ok:
		print("[FAIL] input assignment update failed: %s" % assignment_result.error)
		return false

	m3.handle_run_started()
	var params := engine.store.create_object()
	m3.invoke_function("PlayLevel", params)
	var gameplay = m3.get_gameplay()
	if gameplay:
		gameplay.current_score = 999

	_bootstrap.restart_ephemeral_run()
	var restarted = engine.get_service("Match3")
	if restarted == null:
		print("[FAIL] Match3 missing after restart")
		return false

	var ok := true
	if not _persistent_bool(engine, "Persistent.collection.discovered.abilities.testAbility"):
		print("[FAIL] discovered ability was wiped by run restart")
		ok = false
	if not engine.state.root.get_node("Persistent.input.assignments.move_right").is_valid():
		print("[FAIL] input assignment was wiped by run restart")
		ok = false

	var score := 0
	var restarted_gameplay = restarted.get_gameplay()
	if restarted_gameplay:
		score = restarted_gameplay.current_score
	var round_number: int = restarted.get_current_round()
	if score != 0:
		print("[FAIL] run score did not reset, got %d" % score)
		ok = false
	if round_number != 1:
		print("[FAIL] current round did not reset to 1, got %d" % round_number)
		ok = false

	if ok:
		print("[SUCCESS] persistent data survives while run state resets")
	return ok

func _persistent_bool(engine: GnosisEngine, path: String) -> bool:
	var node := engine.state.root.get_node(path)
	return node.is_valid() and node.get_type() == GnosisValueType.BOOL and bool(node.value)
