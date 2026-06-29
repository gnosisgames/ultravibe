extends SceneTree

## Verifies Animation.PlayFeedback routes to gameplay audio via FeedbackAudioAdapter.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Audio Feedback Test ---")
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
	print("--- Audio Feedback Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false
	var anim := engine.get_service("Animation") as GnosisAnimationService
	if anim == null:
		print("[FAIL] Animation service missing")
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

	var payload := engine.store.create_object()
	payload.set_key("id", "trashcan")
	var res = anim.play_feedback(payload)
	sub.call("dispose")

	if res == null or not res.is_ok:
		print("[FAIL] play_feedback failed")
		return false
	if not played.has("trashcan_feedback"):
		print("[FAIL] expected trashcan_feedback clip, got %s" % played)
		return false
	print("[SUCCESS] PlayFeedback plays mapped gameplay audio")
	return true
