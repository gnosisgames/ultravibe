extends SceneTree

## Verifies gamepad device ids resolve to deterministic player seats before
## gameplay input reaches downstream routers/services.

var _bootstrap: Node = null
var _frames := 0
var _done := false
var _processed_events: Array[GnosisEvent] = []

func _initialize() -> void:
	print("--- Gamepad Player Assignment Test ---")
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
	print("--- Gamepad Player Assignment Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	var input_adapter := _bootstrap.get_adapter(GnosisGodotInputAdapter) as GnosisGodotInputAdapter
	if game_ui == null or input_adapter == null:
		print("[FAIL] GameUI service or input adapter missing")
		return false

	game_ui.set_base_view("gameplay")
	_processed_events.clear()
	var sub = engine.event_bus.subscribe(
		GnosisInputService.FactInputActionProcessedEventId,
		func(ev): _record_gameplay_event(ev),
		0
	)

	var p1_result := input_adapter._emit_action("move_left", "performed", "gamepad", 0, "move_left")
	var p2_result := input_adapter._emit_action("move_left", "performed", "gamepad", 1, "move_left")
	var ok := true
	if not p1_result.is_ok or not p2_result.is_ok:
		print("[FAIL] gamepad actions were not accepted by Input service")
		ok = false
	elif _processed_events.size() != 2:
		print("[FAIL] expected 2 processed gamepad actions, got %d" % _processed_events.size())
		ok = false
	else:
		ok = _assert_player_event(0, "Player1", 0) and ok
		ok = _assert_player_event(1, "Player2", 1) and ok

	if sub and sub.has_method("dispose"):
		sub.dispose()
	if ok:
		print("[SUCCESS] gamepad devices resolve to distinct player seats")
	return ok

func _record_gameplay_event(event: GnosisEvent) -> void:
	if event == null or not event.data.is_valid():
		return
	if _read_string(event.data, "actionId") != "move_left":
		return
	if _read_string(event.data, "category") != "gameplay":
		return
	_processed_events.append(event)

func _assert_player_event(index: int, expected_player_id: String, expected_device_id: int) -> bool:
	var data := _processed_events[index].data
	var actual_player := _read_string(data, "playerId")
	var actual_device := int(_read_float(data, "deviceId", -1.0))
	if actual_player != expected_player_id:
		print("[FAIL] event %d expected player %s, got %s" % [index, expected_player_id, actual_player])
		return false
	if actual_device != expected_device_id:
		print("[FAIL] event %d expected device %d, got %d" % [index, expected_device_id, actual_device])
		return false
	return true

func _read_string(node: GnosisNode, key: String) -> String:
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return str(child.value)
	return ""

func _read_float(node: GnosisNode, key: String, fallback: float) -> float:
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return float(child.value)
	return fallback
