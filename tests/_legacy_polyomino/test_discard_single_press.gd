extends SceneTree

## Reproduction: a single "discard" press should consume exactly ONE discard.
## Drives the real GnosisGodotInputAdapter (both its _unhandled_input event path
## and its per-frame polling path) and counts how many discard inputs reach the
## FallingBlock service for one logical key press.

var _bootstrap: Node = null
var _frames := 0
var _phase := 0
var _engine: GnosisEngine = null
var _discard_count := 0
var _sub: RefCounted = null

func _initialize() -> void:
	print("--- Discard Single Press Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	match _phase:
		0:
			_setup()
			_phase = 1
		1:
			# Inject a real OS-style key-down for Q and let the node tree process it
			# naturally (Godot calls the adapter's _unhandled_input + its per-frame
			# polling). No manual adapter calls -> faithful to live behavior.
			_press_discard()
			_phase = 2
		2, 3:
			# A couple of held frames process naturally.
			_phase += 1
		4:
			_release_discard()
			_phase = 5
		5, 6:
			_phase += 1
		7:
			_report()
			return true
	return false

func _setup() -> void:
	_engine = _bootstrap.engine
	var host = _bootstrap
	if host.has_method("restart_ephemeral_run"):
		host.restart_ephemeral_run()
	var fb := _engine.get_service("FallingBlock") as FallingBlockService
	var eph := _engine.state.root.get_node("Ephemeral")
	if eph.is_valid():
		eph.set_key("playerCount", 1)
		var fbn := eph.get_node("fallingBlock")
		if fbn.is_valid():
			fbn.set_key("currentDiscards", 99.0)
			fbn.set_key("maxDiscards", 99.0)
			fbn.set_key("minDiscards", 0.0)
	fb.handle_run_started()
	var ui := _engine.get_service("GameUI") as GnosisGameUIService
	if ui:
		ui.set_base_view("gameplay")
	# Count discard inputs that actually reach the service.
	_sub = _engine.event_bus.subscribe(
			FallingBlockEvents.FACT_FALLING_BLOCK_INPUT_PROCESSED,
			func(ev: GnosisEvent):
				if ev and ev.data.is_valid():
					var n := ev.data.get_node(FallingBlockEvents.PAYLOAD_INPUT_TYPE)
					if n.is_valid() and str(n.value).to_lower() == "discard":
						_discard_count += 1,
			0
	)

func _press_discard() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.physical_keycode = KEY_Q
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _release_discard() -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.physical_keycode = KEY_Q
	ev.pressed = false
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _report() -> void:
	print("[result] discard inputs consumed for ONE press: %d" % _discard_count)
	if _discard_count == 1:
		print("--- Discard Single Press Test Passed ---")
		quit(0)
	else:
		print("--- Discard Single Press Test FAILED (expected 1) ---")
		quit(1)
