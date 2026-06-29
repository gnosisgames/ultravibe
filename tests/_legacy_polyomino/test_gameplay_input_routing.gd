extends SceneTree

## Verifies gameplay input is routed through GnosisInputService and gated by
## GameUI context: emitting a gameplay action reaches the FallingBlock service
## while gameplay is foremost, and is denied while a pause overlay is active.

var _bootstrap: Node = null
var _frames := 0
var _done := false
var _routed_inputs: Array = []

func _initialize() -> void:
	print("--- Gameplay Input Routing Test ---")
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
	print("--- Gameplay Input Routing Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _emit(input_service: GnosisInputService, store: GnosisStore, action_id: String, phase: String = "performed", player_id: String = "Player1") -> bool:
	var payload := store.create_object()
	payload.set_key("actionId", action_id)
	payload.set_key("playerId", player_id)
	payload.set_key("phase", phase)
	payload.set_key("category", "gameplay")
	var res = input_service.emit_action(payload)
	return res != null and res.is_ok

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var store := engine.store
	var input_service := engine.get_service("Input") as GnosisInputService
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	var router := _find_router(_bootstrap)
	if input_service == null or game_ui == null:
		print("[FAIL] Input/GameUI service missing")
		return false
	if router == null:
		print("[FAIL] GameplayInputRouter missing")
		return false

	var sub = engine.event_bus.subscribe(
		FallingBlockEvents.REQUEST_FALLING_BLOCK_INPUT,
		func(ev): _routed_inputs.append(ev),
		0
	)

	# 1) Gameplay foremost -> action should route to FallingBlock.
	game_ui.set_base_view("gameplay")
	_routed_inputs.clear()
	var emitted_live := _emit(input_service, store, "move_left")
	if not emitted_live:
		print("[FAIL] emit_action denied while gameplay live")
		ok = false
	elif _routed_inputs.size() != 1:
		print("[FAIL] expected 1 routed input while live, got %d" % _routed_inputs.size())
		ok = false
	else:
		print("[SUCCESS] gameplay action routed while live")

	# 2) Held movement repeats after its initial delay and stops on cancel.
	if _force_repeat_due(router, "Player1", "move_left"):
		router._process(0.0)
	if _routed_inputs.size() < 2:
		print("[FAIL] held move_left did not repeat")
		ok = false
	else:
		print("[SUCCESS] held move_left repeats")
	var count_after_repeat := _routed_inputs.size()
	_emit(input_service, store, "move_left", "canceled")
	if _force_repeat_due(router, "Player1", "move_left"):
		router._process(0.0)
	if _routed_inputs.size() != count_after_repeat:
		print("[FAIL] canceled move_left kept repeating")
		ok = false
	else:
		print("[SUCCESS] held move_left stops on cancel")

	# 2b) Co-op: two controllers hold the same action; one releasing must NOT
	# cancel the other's repeat (regression: shared per-action held state let one
	# player's release leave the other stuck, or one press clobber the other).
	_emit(input_service, store, "move_right", "performed", "Player1")
	_emit(input_service, store, "move_right", "performed", "Player2")
	var p1_key := "Player1/move_right"
	var p2_key := "Player2/move_right"
	if not router._held_actions.has(p1_key) or not router._held_actions.has(p2_key):
		print("[FAIL] both players should have independent held move_right state")
		ok = false
	else:
		print("[SUCCESS] each player holds independent move_right state")
	_emit(input_service, store, "move_right", "canceled", "Player1")
	if router._held_actions.has(p1_key):
		print("[FAIL] Player1 release did not clear its held state")
		ok = false
	elif not router._held_actions.has(p2_key):
		print("[FAIL] Player1 release wrongly cleared Player2's held state")
		ok = false
	else:
		print("[SUCCESS] one player's release leaves the other's repeat intact")
	_emit(input_service, store, "move_right", "canceled", "Player2")

	# 3) Pause overlay active -> action should be gated (denied + not routed).
	var pause_params := store.create_object()
	pause_params.set_key("viewId", "pause")
	pause_params.set_key("overlayStateId", "open")
	game_ui.invoke_function("PushViewAdditive", pause_params)
	_routed_inputs.clear()
	var emitted_paused := _emit(input_service, store, "move_left")
	if emitted_paused:
		print("[FAIL] emit_action allowed while paused")
		ok = false
	elif _routed_inputs.size() != 0:
		print("[FAIL] input routed while paused")
		ok = false
	else:
		print("[SUCCESS] gameplay action gated while paused")

	# 4) Resume -> routing works again.
	game_ui.try_set_view_overlay_state("pause", "")
	_routed_inputs.clear()
	if not _emit(input_service, store, "rotate_cw"):
		print("[FAIL] emit_action denied after resume")
		ok = false
	elif _routed_inputs.size() != 1:
		print("[FAIL] expected routing after resume")
		ok = false
	else:
		print("[SUCCESS] routing restored after resume")

	if sub and sub.has_method("dispose"):
		sub.dispose()
	return ok

func _force_repeat_due(router: UltravibeGameplayInputRouter, player_id: String, action_id: String) -> bool:
	var key := "%s/%s" % [player_id, action_id]
	if not router._held_actions.has(key):
		return false
	var state: Dictionary = router._held_actions[key]
	state["nextAt"] = 0.0
	router._held_actions[key] = state
	return true

func _find_router(node: Node) -> UltravibeGameplayInputRouter:
	if node is UltravibeGameplayInputRouter:
		return node as UltravibeGameplayInputRouter
	for child in node.get_children():
		var found := _find_router(child)
		if found:
			return found
	return null
