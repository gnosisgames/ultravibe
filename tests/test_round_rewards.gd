extends SceneTree

## Verifies the round-advance reward cycle: on run start reward offers are rolled,
## forcing the objective past its target opens a pending selection, and claiming
## the selected offer grants it into the matching engine inventory.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Round Reward Cycle Test ---")
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
	print("--- Round Reward Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx = fb.context
	var ep: GnosisNode = ctx.state.root.get_node("Ephemeral")

	# 1. Offers were rolled on run start.
	var offers := ep.get_node("rewardOffers")
	var offer_count := offers.get_count() if offers.is_valid() and offers.get_type() == GnosisValueType.LIST else 0
	if offer_count <= 0:
		print("[FAIL] no reward offers rolled at run start")
		ok = false
	else:
		var first := offers.get_node(0)
		print("[SUCCESS] %d reward offers rolled (first: %s/%s)" % [
			offer_count,
			_s(first, "type"), _s(first, "itemId")])

	# 2. Snapshot total owned items across inventories before round advance.
	var before := _total_owned(engine, ctx)

	# 3. Force objective progress past the target to trigger a round advance.
	var round_before := FallingBlockEphemeral.get_fb_int(ctx, "currentRound", 1)
	var target := FallingBlockEphemeral.get_fb_int(ctx, "roundLinesNeeded", 0)
	var player = fb.get_players()[0]
	fb._apply_round_progress_after_line_clear(player, target, GnosisScalableValue.zero())

	var round_after := FallingBlockEphemeral.get_fb_int(ctx, "currentRound", 1)
	if round_after <= round_before:
		print("[FAIL] round did not advance (%d -> %d)" % [round_before, round_after])
		ok = false
	else:
		print("[SUCCESS] round advanced %d -> %d" % [round_before, round_after])

	# 4. Completing a round should auto-grant the highlighted inline reward.
	var selected_offer := offers.get_node(0)
	var selected_type := _s(selected_offer, "type")
	var selected_item := _s(selected_offer, "itemId")
	var after := _total_owned(engine, ctx)
	if after <= before:
		print("[FAIL] no reward granted on round advance (owned %d -> %d)" % [before, after])
		ok = false
	else:
		print("[SUCCESS] reward auto-granted on round advance (owned %d -> %d)" % [before, after])

	var pending := _bool(ep.get_node("rewardSelectionPending"))
	if pending:
		print("[FAIL] reward selection should not block gameplay after inline grant")
		ok = false

	if not _is_discovered(ctx, selected_type, selected_item):
		print("[FAIL] granted reward was not persisted as discovered (%s/%s)" % [selected_type, selected_item])
		ok = false
	else:
		print("[SUCCESS] granted reward persisted as discovered (%s/%s)" % [selected_type, selected_item])

	# 5. Offers were re-rolled for the next round.
	var offers2 := ep.get_node("rewardOffers")
	var offer_count2 := offers2.get_count() if offers2.is_valid() and offers2.get_type() == GnosisValueType.LIST else 0
	if offer_count2 <= 0:
		print("[FAIL] offers not refreshed after round advance")
		ok = false
	else:
		print("[SUCCESS] offers refreshed after round advance (%d)" % offer_count2)

	return ok

func _total_owned(engine: GnosisEngine, ctx) -> int:
	var ep: GnosisNode = ctx.state.root.get_node("Ephemeral")
	var total := 0
	for root_key in ["boons", "consumables", "abilities", "upgrades"]:
		var buckets := ep.get_node(root_key)
		if not buckets.is_valid() or buckets.get_type() != GnosisValueType.OBJECT:
			continue
		for bucket_key in buckets.get_keys():
			var bag := buckets.get_node(bucket_key)
			if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
				continue
			var list := bag.get_node("list")
			if list.is_valid() and list.get_type() == GnosisValueType.LIST:
				total += list.get_count()
	return total

func _s(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	return str(n.value) if n.is_valid() and n.value != null else ""

func _bool(node: GnosisNode) -> bool:
	return bool(node.value) if node.is_valid() and node.get_type() == GnosisValueType.BOOL else false

func _is_discovered(ctx, type_id: String, item_id: String) -> bool:
	var category := FallingBlockCollection.category_for_type(type_id)
	if category.is_empty() or item_id.strip_edges().is_empty():
		return false
	var node: GnosisNode = ctx.state.root.get_node("Persistent.collection.discovered.%s.%s" % [category, item_id])
	return node.is_valid() and node.get_type() == GnosisValueType.BOOL and bool(node.value)
