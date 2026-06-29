extends SceneTree

## Verifies Unity-parity juice pitch math and that successful moves request move SFX.

const GameplayAudio = preload("res://game/services/falling_block_gameplay_audio.gd")

var _bootstrap: Node = null
var _frames := 0
var _phase := 0
var _sound_events: Array = []
var _sound_sub: RefCounted = null
var _fb: FallingBlockService = null
var _events_before_move := 0

func _initialize() -> void:
	print("--- Gameplay Audio Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _phase == 0:
		if _frames < 8:
			return false
		if not _test_juice_pitch():
			_finish(false)
			return true
		_phase = 1
		_setup_move_test()
		return false
	if _phase == 1:
		if _frames < 16:
			return false
		_send_move_input()
		_phase = 2
		return false
	if _phase == 2:
		if _frames < 18:
			return false
		_finish(_verify_move_sound())
		return true
	return true

func _finish(ok: bool) -> void:
	if _sound_sub and _sound_sub.has_method("dispose"):
		_sound_sub.dispose()
	print("--- Gameplay Audio Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _test_juice_pitch() -> bool:
	var p1 := GameplayAudio.compute_juice_pitch(1, GameplayAudio.PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE)
	if not is_equal_approx(p1, 1.0):
		print("[FAIL] streak 1 pitch expected 1.0 got %s" % p1)
		return false
	var p14 := GameplayAudio.compute_juice_pitch(14, GameplayAudio.PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE)
	if not is_equal_approx(p14, GameplayAudio.PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE):
		print("[FAIL] streak 14 pitch expected %s got %s" % [GameplayAudio.PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE, p14])
		return false
	print("[SUCCESS] juice pitch ramp")
	return true

func _setup_move_test() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	_fb = engine.get_service("FallingBlock") as FallingBlockService
	_sound_sub = engine.event_bus.subscribe(
		"REQUEST_SOUND_PLAY",
		func(ev):
			if ev and ev.data.is_valid():
				var clip: GnosisNode = ev.data.get_node("clipId")
				if clip.is_valid():
					_sound_events.append(str(clip.value)),
		0
	)
	engine.start_run()

func _send_move_input() -> void:
	if _fb == null or _fb.get_players().is_empty():
		return
	var player: FallingBlockModels.PlayerState = _fb.get_players()[0]
	if player == null or player.current_piece_instance_id.is_empty():
		return
	_events_before_move = _sound_events.size()
	var input := FallingBlockModels.InputEventData.new()
	input.player_id = player.player_id
	input.type = FallingBlockModels.InputType.MOVE_LEFT
	_fb.handle_input(input)

func _verify_move_sound() -> bool:
	if _fb == null:
		print("[FAIL] FallingBlock service missing")
		return false
	var player: FallingBlockModels.PlayerState = _fb.get_players()[0] if not _fb.get_players().is_empty() else null
	if player == null or player.current_piece_instance_id.is_empty():
		print("[FAIL] no active piece after run start")
		return false
	for i in range(_events_before_move, _sound_events.size()):
		if str(_sound_events[i]) == "move":
			print("[SUCCESS] move sound requested on successful move")
			return true
	print("[FAIL] successful move did not request move clip (events=%s)" % _sound_events)
	return false
