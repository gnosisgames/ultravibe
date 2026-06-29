extends SceneTree

## Parity: boss native effects alter gameplay state.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Parity Boss Effects Test ---")
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
	print("--- Parity Boss Effects Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var fb := _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
	var player: FallingBlockModels.PlayerState = fb.get_players()[0]
	if player.current_piece_instance_id.is_empty():
		fb._spawn_piece_for_player(player, "Line4", "blue")
	var params := fb.context.store.create_object()
	params.set_key("effectId", "ReduceGravitySpeed")
	params.set_key("fallSpeedDelta", -2)
	var apply_res = fb.invoke_function("ApplyEffect", params)
	if apply_res == null or not (apply_res is GnosisFunctionResult) or not apply_res.is_ok:
		print("[FAIL] ApplyEffect ReduceGravitySpeed failed")
		ok = false
	else:
		var offset := FallingBlockEphemeral.get_fb_int(fb.context, "gravityLevelOffset", 0)
		if offset >= 0:
			print("[FAIL] ReduceGravitySpeed expected negative gravityLevelOffset, got %d" % offset)
			ok = false
		else:
			print("[SUCCESS] ReduceGravitySpeed applied offset=%d" % offset)

	params = fb.context.store.create_object()
	params.set_key("effectId", "ReduceGravitySpeed")
	var remove_res = fb.invoke_function("RemoveEffect", params)
	if remove_res == null or not (remove_res is GnosisFunctionResult) or not remove_res.is_ok:
		print("[FAIL] RemoveEffect ReduceGravitySpeed failed")
		ok = false
	else:
		var offset_after := FallingBlockEphemeral.get_fb_int(fb.context, "gravityLevelOffset", 0)
		if offset_after != 0:
			print("[FAIL] RemoveEffect did not restore gravity offset (got %d)" % offset_after)
			ok = false
		else:
			print("[SUCCESS] ReduceGravitySpeed removed, offset restored")

	params = fb.context.store.create_object()
	params.set_key("effectId", "InvertControls")
	apply_res = fb.invoke_function("ApplyEffect", params)
	if fb._boss_fx and not fb._boss_fx.should_invert_horizontal():
		print("[FAIL] InvertControls not active after ApplyEffect")
		ok = false
	else:
		print("[SUCCESS] InvertControls active")

	var direct_rotation_before := player.current_piece_rotation
	var direct_input := FallingBlockModels.InputEventData.new()
	direct_input.player_id = player.player_id
	direct_input.type = FallingBlockModels.InputType.ROTATE_CW
	fb.handle_input(direct_input)
	if player.current_piece_rotation == direct_rotation_before:
		print("[FAIL] direct rotate did not rotate active piece before denial check")
		ok = false
	else:
		print("[SUCCESS] direct rotate changed active piece rotation")

	params = fb.context.store.create_object()
	params.set_key("effectId", "DisableRotation")
	apply_res = fb.invoke_function("ApplyEffect", params)
	if apply_res == null or not (apply_res is GnosisFunctionResult) or not apply_res.is_ok:
		var err: String = apply_res.error if apply_res is GnosisFunctionResult else "null"
		print("[FAIL] ApplyEffect DisableRotation failed: %s" % err)
		ok = false
	else:
		var rule_svc := fb.context.engine.get_service("Rule") as GnosisRuleService
		var rules := rule_svc.get_node("rules", false)
		var has_rotation_rule := false
		if rules.is_valid() and rules.get_type() == GnosisValueType.LIST:
			for val in rules.value:
				var entry := GnosisNode.new(val, fb.context.store)
				var iid := str(entry.get_node("instanceId").value) if entry.get_node("instanceId").is_valid() else ""
				if iid == "bossEffect_disablerotation":
					has_rotation_rule = true
					break
		if not has_rotation_rule:
			print("[FAIL] DisableRotation rule not registered")
			ok = false
		else:
			print("[SUCCESS] DisableRotation rule registered")

	var denied_rotation_before := player.current_piece_rotation
	fb.publish_input_from_adapter(player.player_id, FallingBlockModels.InputType.ROTATE_CW)
	if player.current_piece_rotation != denied_rotation_before:
		print("[FAIL] DisableRotation rule did not block event-bus rotation input")
		ok = false
	else:
		print("[SUCCESS] DisableRotation blocked event-bus rotation input")

	params = fb.context.store.create_object()
	params.set_key("effectId", "ReplaceBaseColorWithNegativeOnSpawn")
	params.set_key("baseColor", "red")
	apply_res = fb.invoke_function("ApplyEffect", params)
	if apply_res == null or not (apply_res is GnosisFunctionResult) or not apply_res.is_ok:
		print("[FAIL] ApplyEffect ReplaceBaseColorWithNegativeOnSpawn failed")
		ok = false
	else:
		fb._piece_lifecycle.clear_active_piece(fb.get_grid_state(), player)
		fb._spawn_piece_for_player(player, "Square4", "red")
		var saw_negative := false
		for cell in fb.get_grid_state().cells:
			if cell != null and cell.piece_instance_id == player.current_piece_instance_id and not cell.is_locked:
				if fb._is_negative_variant(cell.variant_id):
					saw_negative = true
				elif cell.variant_id == "red":
					print("[FAIL] red spawn was not replaced by a negative variant")
					ok = false
					break
		if saw_negative:
			print("[SUCCESS] base-color spawn was replaced by a negative variant")
		elif ok:
			print("[FAIL] no active negative cells found after spawn replacement")
			ok = false

	return ok
