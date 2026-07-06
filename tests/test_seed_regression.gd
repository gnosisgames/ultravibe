extends SceneTree

## Sprint 8: golden-seed regression for round-action rewards, shop offers, lucky find.

const GOLDEN_SEED := 424242

const EXPECTED_ROUND_REWARDS := {
	1: "Chaomania",
	6: "Sapphiromania",
	12: "Rubymania",
	24: "Ploutomania",
}

const EXPECTED_SHOP_OFFERS: Array[Dictionary] = [
	{"sourceConfigId": "consumables", "itemId": "ItemUpgradeGrantBlueLevelUp"},
	{"sourceConfigId": "boons", "itemId": "Mainstream"},
	{"sourceConfigId": "boons", "itemId": "GlowUp"},
	{"sourceConfigId": "consumables", "itemId": "Doromania"},
	{"sourceConfigId": "boons", "itemId": "Block"},
	{"sourceConfigId": "consumables", "itemId": "ItemUpgradeGrantLuckyFindBoostI"},
]

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Seed Regression Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Seed Regression Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_round_action_rewards():
		return false
	if not _check_shop_offers():
		return false
	if not _check_lucky_find_plan():
		return false
	print("[SUCCESS] golden seed regression verified")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _set_golden_seed() -> void:
	var seed_svc = _engine().get_service("Seed")
	seed_svc.set_node("seed", GOLDEN_SEED, false)


func _check_round_action_rewards() -> bool:
	_set_golden_seed()
	var m3 = _engine().get_service("Match3")
	m3.handle_run_started()
	var state = m3.get_node("match3", false)
	for round_num in EXPECTED_ROUND_REWARDS.keys():
		state.set_key("nextLevel", round_num)
		m3.refresh_planned_floor_preview()
		var reward_id := _round_reward_for(state, round_num)
		var expected: String = EXPECTED_ROUND_REWARDS[round_num]
		if reward_id != expected:
			print("[FAIL] round %d reward expected '%s', got '%s'" % [round_num, expected, reward_id])
			return false
	print("[OK] round-action rewards match golden seed %d" % GOLDEN_SEED)
	return true


func _check_shop_offers() -> bool:
	_set_golden_seed()
	var engine := _engine()
	var m3 = engine.get_service("Match3")
	var shop = engine.get_service("Match3Shop")
	m3.handle_run_started()
	var state = m3.get_node("match3", false)
	state.set_key("nextLevel", 1)
	_set_golden_seed()
	shop.invoke_function("RebuildCoreShopOffers", engine.store.create_object())
	var shop_result = shop.invoke_function("GetCoreShop", engine.store.create_object())
	if not (shop_result is GnosisFunctionResult) or not shop_result.is_ok:
		print("[FAIL] GetCoreShop after rebuild")
		return false
	var offers = shop_result.payload.get_node("core.offers")
	if offers.get_count() != EXPECTED_SHOP_OFFERS.size():
		print("[FAIL] shop offer count expected %d, got %d" % [EXPECTED_SHOP_OFFERS.size(), offers.get_count()])
		return false
	for i in EXPECTED_SHOP_OFFERS.size():
		var o = offers.get_node(i)
		var source := str(o.get_node("sourceConfigId").value)
		var item_id := str(o.get_node("itemId").value)
		var expected: Dictionary = EXPECTED_SHOP_OFFERS[i]
		if source != str(expected["sourceConfigId"]) or item_id != str(expected["itemId"]):
			print("[FAIL] shop offer[%d] expected %s/%s, got %s/%s" % [
				i, expected["sourceConfigId"], expected["itemId"], source, item_id
			])
			return false
	print("[OK] core shop offers match golden seed %d" % GOLDEN_SEED)
	return true


func _check_lucky_find_plan() -> bool:
	var gameplay = load("res://game/match3/core/match3_gameplay.gd").new()
	var lucky_find = load("res://game/match3/core/match3_lucky_find.gd").new()
	gameplay.configure_rng(GOLDEN_SEED)
	var layout = load("res://game/match3/core/match3_board_layout.gd").new()
	layout.width = 5
	layout.height = 5
	gameplay.load_level(layout, 500, 5, 3, {"orange": 10, "red": 10, "blue": 10})
	gameplay.set_lucky_find(lucky_find)
	lucky_find.configure(100.0, 0.0, true)
	lucky_find.temporary_chance_percent = 100.0
	for x in 3:
		gameplay.get_tile(x, 2).item_id = "orange"
	gameplay.get_tile(3, 2).item_id = ""
	var plan: Dictionary = lucky_find.resolve_refill_plan(
		gameplay, [{"x": 3, "y": 2}], gameplay.get_spawn_rng()
	)
	var assignments: Dictionary = plan.get("assignments", {})
	if str(assignments.get("3,2", "")) != "orange":
		print("[FAIL] lucky find plan expected orange at 3,2, got %s" % str(assignments))
		return false
	print("[OK] lucky find refill plan matches golden seed %d" % GOLDEN_SEED)
	return true


func _round_reward_for(state: GnosisNode, round_num: int) -> String:
	var planned = state.get_node("plannedFloor")
	if not planned.is_valid():
		return ""
	var rounds = planned.get_node("rounds")
	if not rounds.is_valid():
		return ""
	for i in rounds.get_count():
		var row = rounds.get_node(i)
		if int(row.get_node("round").value) == round_num:
			return str(row.get_node("roundActionRewardConsumableId").value)
	return ""
