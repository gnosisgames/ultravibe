extends SceneTree

## Verifies Input.UpdateAssignments persists the assignment snapshot in state and
## the Godot input adapter applies keyboard bindings into InputMap.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Input Rebinding Test ---")
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
	print("--- Input Rebinding Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false
	var input := engine.get_service("Input") as GnosisInputService
	if input == null:
		print("[FAIL] Input service missing")
		return false

	var assignments := engine.store.create_object()
	var move_left := engine.store.create_object()
	move_left.set_key("keycode", KEY_J)
	move_left.set_key("physicalKeycode", KEY_J)
	move_left.set_key("displayName", "J")
	assignments.set_key("move_left", move_left)

	var result := input.update_assignments(assignments)
	if not result.is_ok:
		print("[FAIL] UpdateAssignments failed: %s" % result.error)
		return false

	var persisted := engine.state.root.get_node("Persistent.input.assignments.move_left")
	if not persisted.is_valid():
		print("[FAIL] assignment not stored under Persistent.input.assignments")
		return false

	if not _action_has_key("move_left", KEY_J):
		print("[FAIL] InputMap did not apply move_left -> J")
		return false

	print("[SUCCESS] assignment persisted and applied to InputMap")
	return true

func _action_has_key(action_name: String, keycode: int) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == keycode or key_event.physical_keycode == keycode:
				return true
	return false
