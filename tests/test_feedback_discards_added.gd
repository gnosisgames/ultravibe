extends SceneTree

## Verifies discardsAdded feedback fires when discards are granted.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Feedback Discards Added Test ---")
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
	print("--- Feedback Discards Added Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	if fb == null:
		print("[FAIL] FallingBlock service missing")
		return false

	var played: Array = []
	var sub = engine.event_bus.subscribe(
		"REQUEST_SOUND_PLAY",
		func(ev):
			if ev and ev.data.is_valid():
				var clip: GnosisNode = ev.data.get_node("clipId")
				if clip.is_valid():
					played.append(str(clip.value)),
		0
	)

	engine.start_run()
	var params := engine.store.create_object()
	params.set_key("amount", 1.0)
	var res = fb.invoke_function("AddDiscards", params)
	sub.call("dispose")

	if res == null or not (res is GnosisFunctionResult) or not res.is_ok:
		print("[FAIL] AddDiscards failed")
		return false
	if not played.has("trashcan_feedback"):
		print("[FAIL] discardsAdded did not play trashcan_feedback, got %s" % played)
		return false
	print("[SUCCESS] discardsAdded feedback audio")
	return true
