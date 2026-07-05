extends SceneTree

## Shop stays hidden until at least one round is played (skip alone must not unlock it).

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Shop Available After Skip Test ---")
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
	print("--- Shop Available After Skip Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var host = _bootstrap
	if host.has_method("restart_ephemeral_run"):
		host.restart_ephemeral_run()
	var engine: GnosisEngine = host.engine
	var m3: Match3Service = engine.get_service("Match3") as Match3Service
	if m3 == null:
		print("[FAIL] Match3 missing")
		return false
	m3.handle_run_started()
	if m3.is_shop_available():
		print("[FAIL] shop should be hidden on fresh run")
		return false
	var skip = m3.invoke_function("SkipLevel", engine.store.create_object())
	if skip == null or not skip.is_ok or not _payload_bool(skip.payload, "success", false):
		print("[FAIL] SkipLevel failed: %s" % str(skip))
		return false
	if m3.is_shop_available():
		print("[FAIL] shop should stay hidden after skip-only progression")
		return false
	if m3.get_statistic_int("match3.rounds.played", 0) != 0:
		print("[FAIL] skip should not increment rounds.played")
		return false
	var play = m3.invoke_function("PlayLevel", engine.store.create_object())
	if play == null or not play.is_ok or not _payload_bool(play.payload, "success", true):
		print("[FAIL] PlayLevel failed: %s" % str(play))
		return false
	if m3.get_statistic_int("match3.rounds.played", 0) < 1:
		print("[FAIL] PlayLevel should increment rounds.played")
		return false
	if not m3.is_shop_available():
		print("[FAIL] shop should unlock after first played round")
		return false
	print("[SUCCESS] shop gated on rounds.played, not skip")
	return true

func _payload_bool(payload: GnosisNode, key: String, default_value: bool) -> bool:
	if payload == null or not payload.is_valid():
		return default_value
	var child := payload.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)
