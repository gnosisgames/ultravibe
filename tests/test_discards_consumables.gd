extends SceneTree

## Verifies Sprint D wiring: discard input consumes a charge and swaps the active
## piece; AddDiscards grants charges; consumable use consumes the selected slot and
## increments the run consumable stat.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Discards / Consumables Test ---")
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
	print("--- Discards/Consumables Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx: GnosisContext = fb.context
	var player = fb.get_players()[0]

	# Ensure an active piece exists.
	if player.current_piece_instance_id.is_empty():
		fb._spawn_piece_for_player(player, "Line4", "blue")
	var piece_before: String = player.current_piece_instance_id

	# Discard: consumes 1 charge and swaps the active piece.
	var discards_before := FallingBlockEphemeral.get_fb_float(ctx, "currentDiscards", 0.0)
	var input := FallingBlockModels.InputEventData.new()
	input.player_id = player.player_id
	input.type = FallingBlockModels.InputType.DISCARD
	fb.handle_input(input)
	var discards_after := FallingBlockEphemeral.get_fb_float(ctx, "currentDiscards", 0.0)
	var piece_after: String = player.current_piece_instance_id
	if not is_equal_approx(discards_after, discards_before - 1.0):
		print("[FAIL] discard didn't consume a charge (%f -> %f)" % [discards_before, discards_after])
		ok = false
	elif piece_after == piece_before or piece_after.is_empty():
		print("[FAIL] discard didn't swap the active piece (%s -> %s)" % [piece_before, piece_after])
		ok = false
	else:
		print("[SUCCESS] discard consumed 1 charge and swapped piece (%s -> %s)" % [piece_before, piece_after])

	# AddDiscards grants a charge (clamped to max).
	fb._add_discards(2.0)
	var discards_added := FallingBlockEphemeral.get_fb_float(ctx, "currentDiscards", 0.0)
	if not is_equal_approx(discards_added, discards_after + 2.0):
		print("[FAIL] AddDiscards expected %f, got %f" % [discards_after + 2.0, discards_added])
		ok = false
	else:
		print("[SUCCESS] AddDiscards granted 2 charges (now %f)" % discards_added)

	# Consumable use: add one, use it, verify the run stat increments.
	var add := ctx.store.create_object()
	add.set_key("consumableId", "ladder")
	add.set_key("bucketId", "default")
	var add_res = fb.call_service("Consumable", "AddConsumable", add)
	if add_res == null:
		# Fall back to any configured consumable id from the catalog.
		var cfg := fb.get_node("configuration", true).get_node("consumables")
		if cfg.is_valid() and cfg.get_type() == GnosisValueType.OBJECT and not cfg.get_keys().is_empty():
			var first_id: String = str(cfg.get_keys()[0])
			add.set_key("consumableId", first_id)
			add_res = fb.call_service("Consumable", "AddConsumable", add)

	var used_before := _stat(ctx, "consumables.used.total")
	var use := FallingBlockModels.InputEventData.new()
	use.player_id = player.player_id
	use.type = FallingBlockModels.InputType.USE_CONSUMABLE
	fb.handle_input(use)
	var used_after := _stat(ctx, "consumables.used.total")
	if used_after <= used_before:
		print("[FAIL] consumable use did not increment run stat (%d -> %d)" % [used_before, used_after])
		ok = false
	else:
		print("[SUCCESS] consumable used, run stat %d -> %d" % [used_before, used_after])

	return ok

func _stat(ctx: GnosisContext, key: String) -> int:
	var ep: GnosisNode = ctx.state.root.get_node("Ephemeral")
	var node := ep.get_at_path("statistics." + key)
	if node.is_valid() and node.value != null:
		return int(round(float(node.value)))
	return 0
