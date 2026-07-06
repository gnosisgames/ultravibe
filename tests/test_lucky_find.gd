extends SceneTree

## Lucky Find refill planner + pity curve smoke test.

var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Lucky Find Test ---")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _done:
		return true
	_done = true
	var ok := _check_planner() and _check_pity_curve() and _check_mega_chain()
	print("--- Lucky Find Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _check_planner() -> bool:
	var gameplay = load("res://game/match3/core/match3_gameplay.gd").new()
	var layout = load("res://game/match3/core/match3_board_layout.gd").new()
	var lucky_find = load("res://game/match3/core/match3_lucky_find.gd").new()
	gameplay.configure_rng(7)
	layout.width = 5
	layout.height = 5
	var points := {"orange": 10, "red": 10, "blue": 10}
	gameplay.load_level(layout, 500, 5, 3, points)
	gameplay.set_lucky_find(lucky_find)
	lucky_find.configure(100.0, 0.0, true)
	lucky_find.temporary_assist = 100.0

	# Two oranges with a gap — lucky refill should complete the line.
	for x in 3:
		gameplay.get_tile(x, 2).item_id = "orange"
	gameplay.get_tile(3, 2).item_id = ""

	var empty_cells: Array = [{"x": 3, "y": 2}]
	var plan: Dictionary = lucky_find.resolve_refill_plan(gameplay, empty_cells, gameplay.get_spawn_rng())
	if not bool(plan.get("active", false)):
		print("[FAIL] planner should activate at assist +100")
		return false
	if str(plan.get("mode", "")) != "help":
		print("[FAIL] planner should be help mode, got %s" % str(plan.get("mode")))
		return false
	var assignments: Dictionary = plan.get("assignments", {})
	if str(assignments.get("3,2", "")) != "orange":
		print("[FAIL] planner should pick orange for gap, got %s" % str(assignments))
		return false
	print("[SUCCESS] planner completes a waiting line")
	return true


func _check_pity_curve() -> bool:
	var lucky_find = load("res://game/match3/core/match3_lucky_find.gd").new()
	lucky_find.configure(10.0, 5.0, true)
	lucky_find.on_move_finished(0, false)
	if absf(lucky_find.temporary_assist - 15.0) > 0.001:
		print("[FAIL] pity increment expected 15, got %s" % lucky_find.temporary_assist)
		return false
	lucky_find.on_move_finished(0, true)
	if absf(lucky_find.temporary_assist - 10.0) > 0.001:
		print("[FAIL] lucky reset expected 10, got %s" % lucky_find.temporary_assist)
		return false
	print("[SUCCESS] pity increments and resets after lucky cascade")
	return true


func _check_mega_chain() -> bool:
	var gameplay = load("res://game/match3/core/match3_gameplay.gd").new()
	var layout = load("res://game/match3/core/match3_board_layout.gd").new()
	var lucky_find = load("res://game/match3/core/match3_lucky_find.gd").new()
	gameplay.configure_rng(11)
	layout.width = 5
	layout.height = 5
	var points := {"orange": 10, "red": 10, "blue": 10}
	gameplay.load_level(layout, 500, 5, 3, points)
	gameplay.set_lucky_find(lucky_find)
	lucky_find.configure(10.0, 0.0, true)
	lucky_find.begin_move()

	if lucky_find.move_lucky_help_count() != 0 or lucky_find.is_mega_chain_pending():
		print("[FAIL] begin_move should reset per-move chain state")
		return false

	for x in 3:
		gameplay.get_tile(x, 2).item_id = "orange"
	gameplay.get_tile(3, 2).item_id = ""
	var empty_cells: Array = [{"x": 3, "y": 2}]
	var rng: RandomNumberGenerator = gameplay.get_spawn_rng()

	lucky_find.temporary_assist = 100.0
	var first: Dictionary = lucky_find.resolve_refill_plan(gameplay, empty_cells, rng)
	if not bool(first.get("active", false)) or str(first.get("mode", "")) != "help":
		print("[FAIL] first lucky help should activate at assist +100")
		return false
	if lucky_find.move_lucky_help_count() != 1:
		print("[FAIL] successful help should increment move help count, got %d" % lucky_find.move_lucky_help_count())
		return false

	# Simulate next cascade refill in the same move: force mega-chain pending.
	lucky_find._mega_chain_pending = true
	lucky_find.temporary_assist = 5.0
	gameplay.get_tile(3, 2).item_id = ""
	var second: Dictionary = lucky_find.resolve_refill_plan(gameplay, empty_cells, rng)
	if not bool(second.get("active", false)):
		print("[FAIL] mega-chain pending should force another help refill")
		return false
	if str(second.get("mode", "")) != "help":
		print("[FAIL] mega-chain refill should be help mode, got %s" % str(second.get("mode")))
		return false
	if not bool(second.get("mega_chain", false)):
		print("[FAIL] mega-chain refill should be flagged as chained")
		return false
	if lucky_find.move_lucky_help_count() != 2:
		print("[FAIL] second chained help should increment count to 2, got %d" % lucky_find.move_lucky_help_count())
		return false

	lucky_find._move_lucky_help_count = 3
	lucky_find._mega_chain_pending = true
	lucky_find.temporary_assist = 0.0
	var capped: Dictionary = lucky_find.resolve_refill_plan(gameplay, empty_cells, rng)
	if bool(capped.get("active", false)) and str(capped.get("mode", "")) == "help":
		print("[FAIL] move should cap at 3 lucky help inserts")
		return false
	if lucky_find.is_mega_chain_pending():
		print("[FAIL] mega-chain pending should clear once cap is reached")
		return false

	print("[SUCCESS] mega-chain forces extra lucky helps up to cap")
	return true
