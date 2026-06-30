extends SceneTree

## Verifies Match3 catalogs and core swap/match logic.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Match3 Core Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _check_catalogs() and _check_progression_boot() and _check_shop() \
		and _check_round_action_rewards() and _check_skip_level() and _check_gameplay()
	print("--- Match3 Core Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check_catalogs() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var cfg = m3.get_node("configuration", true)
	var ok := true
	for cat in ["items", "match3Boards", "consumables", "boons"]:
		var node = cfg.get_node(cat)
		var count = node.get_count() if node.is_valid() and node.get_type() == GnosisValueType.OBJECT else -1
		if count <= 0:
			print("[FAIL] catalog '%s' empty or missing (count=%d)" % [cat, count])
			ok = false
		else:
			print("[SUCCESS] catalog '%s': %d entries" % [cat, count])
	return ok


func _check_progression_boot() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing for progression")
		return false
	m3.handle_run_started()
	var state = m3.get_node("match3", false)
	var board_id := _node_str(state, "boardId", "")
	var width := _node_int(state, "width", 0)
	var height := _node_int(state, "height", 0)
	var target := _node_int(state, "targetScore", 0)
	var moves := _node_int(state, "currentMoves", 0)
	if board_id.is_empty() or width <= 0 or height <= 0 or target <= 0 or moves <= 0:
		print("[FAIL] progression boot invalid board='%s' size=%dx%d target=%d moves=%d" % [
			board_id, width, height, target, moves
		])
		return false
	print("[SUCCESS] progression boot board='%s' size=%dx%d target=%d moves=%d" % [
		board_id, width, height, target, moves
	])
	return true


func _check_shop() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var shop = engine.get_service("Match3Shop")
	if shop == null:
		print("[FAIL] Match3Shop service missing")
		return false
	var result = shop.invoke_function("GetCoreShop", GnosisNode.new(null))
	if not (result is GnosisFunctionResult) or not result.is_ok:
		print("[FAIL] GetCoreShop failed")
		return false
	var offers = result.payload.get_node("core.offers")
	if not offers.is_valid() or offers.get_count() <= 0:
		print("[FAIL] core shop offers missing")
		return false
	print("[SUCCESS] core shop offers: %d" % offers.get_count())
	return true


func _check_round_action_rewards() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing for round-action rewards")
		return false
	m3.handle_run_started()
	var state = m3.get_node("match3", false)
	var planned := state.get_node("plannedFloor")
	if not planned.is_valid():
		print("[FAIL] plannedFloor missing after run start")
		return false
	var rounds := planned.get_node("rounds")
	if not rounds.is_valid() or rounds.get_count() < 1:
		print("[FAIL] plannedFloor rounds missing")
		return false
	var current := rounds.get_node(0)
	var reward_id := _node_str(current, "roundActionRewardConsumableId", "")
	if reward_id.is_empty():
		print("[FAIL] roundActionRewardConsumableId not resolved for queued round")
		return false
	print("[SUCCESS] round-action reward locked: %s" % reward_id)
	return true


func _check_skip_level() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing for skip level")
		return false
	var state = m3.get_node("match3", false)
	var next_level_before := _node_int(state, "nextLevel", 1)
	# Boss rounds are the last round in each floor (round 3, 6, 9, ...).
	var boss_round := ((next_level_before - 1) / 3 + 1) * 3
	state.set_key("nextLevel", boss_round)
	var boss_skip = m3.invoke_function("SkipLevel", GnosisNode.new(null))
	if not (boss_skip is GnosisFunctionResult) or not boss_skip.is_ok:
		print("[FAIL] SkipLevel invoke failed on boss round")
		return false
	if _node_bool(boss_skip.payload, "success", true):
		print("[FAIL] SkipLevel should fail on boss round")
		return false
	state.set_key("nextLevel", 1)
	var skip = m3.invoke_function("SkipLevel", GnosisNode.new(null))
	if not (skip is GnosisFunctionResult) or not skip.is_ok:
		print("[FAIL] SkipLevel invoke failed")
		return false
	if not _node_bool(skip.payload, "success", false):
		print("[FAIL] SkipLevel should succeed on skippable round 1, reason=%s" % _node_str(skip.payload, "reason"))
		return false
	print("[SUCCESS] SkipLevel rejects boss and advances skippable round")
	return true


func _check_gameplay() -> bool:
	var gameplay = load("res://game/match3/core/match3_gameplay.gd").new()
	var layout = load("res://game/match3/core/match3_board_layout.gd").new()
	var models = load("res://game/match3/core/match3_models.gd")
	gameplay.configure_rng(42)
	layout.width = 5
	layout.height = 5
	var points := {"orange": 10, "red": 10, "blue": 10}
	gameplay.load_level(layout, 500, 5, 3, points)
	if gameplay.width != 5 or gameplay.height != 5:
		print("[FAIL] board dimensions")
		return false
	for x in 3:
		gameplay.get_tile(x, 0).item_id = "orange"
	gameplay.get_tile(3, 0).item_id = "red"
	gameplay.get_tile(4, 0).item_id = "orange"
	var a = models.TileCoord.new(3, 0)
	var b = models.TileCoord.new(4, 0)
	var results = gameplay.process_move(a, b, points)
	if results.is_empty():
		print("[FAIL] swap should produce matches")
		return false
	print("[SUCCESS] process_move produced %d step(s), score=%d" % [results.size(), gameplay.current_score])
	return true


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)


func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)


func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)
