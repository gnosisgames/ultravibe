extends SceneTree

## Sprint 8: cascade simulation budget on largest boards (headless gameplay).

const Models = preload("res://game/match3/core/match3_models.gd")
const BoardLayoutScript = preload("res://game/match3/core/match3_board_layout.gd")
const GameplayScript = preload("res://game/match3/core/match3_gameplay.gd")

const BOARD_IDS: Array[String] = ["grid10x10_dr", "hard2Split"]
const MOVE_BUDGET_USEC := 3_000_000 # 3s total for all boards + moves
const MAX_CASCADE_STEPS := 40

var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Match3 Cascade Perf Test ---")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Match3 Cascade Perf Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	var t0 := Time.get_ticks_usec()
	var points := {"red": 10, "orange": 10, "blue": 10, "green": 10, "purple": 10, "pink": 10}
	for board_id in BOARD_IDS:
		if not _stress_board(board_id, points):
			return false
	var elapsed_usec := Time.get_ticks_usec() - t0
	var ms := float(elapsed_usec) / 1000.0
	print("[INFO] cascade stress total: %.1f ms" % ms)
	if elapsed_usec > MOVE_BUDGET_USEC:
		print("[FAIL] cascade stress exceeded %.1f ms budget" % (float(MOVE_BUDGET_USEC) / 1000.0))
		return false
	print("[OK] cascade simulation within budget on %s" % ", ".join(BOARD_IDS))
	return true


func _stress_board(board_id: String, item_points: Dictionary) -> bool:
	var layout = _load_board(board_id)
	if layout == null:
		print("[FAIL] could not load board '%s'" % board_id)
		return false
	var gameplay: Match3Gameplay = GameplayScript.new()
	gameplay.configure_rng(424242)
	gameplay.load_level(layout, 999_999, 50, 6, item_points)
	if not gameplay.is_grid_allocated():
		print("[FAIL] grid not allocated for '%s'" % board_id)
		return false
	var moves := 0
	var max_steps := 0
	for y in gameplay.height:
		for x in gameplay.width - 1:
			if moves >= 12:
				break
			var a := Models.TileCoord.new(x, y)
			var b := Models.TileCoord.new(x + 1, y)
			var results: Array = gameplay.process_move(a, b, item_points)
			moves += 1
			max_steps = maxi(max_steps, results.size())
			if max_steps > MAX_CASCADE_STEPS:
				print("[FAIL] board '%s' cascade steps %d > %d" % [board_id, max_steps, MAX_CASCADE_STEPS])
				return false
		if moves >= 12:
			break
	print("[INFO] board '%s' (%dx%d): %d moves, max cascade steps %d" % [
		board_id, layout.width, layout.height, moves, max_steps
	])
	return true


func _load_board(board_id: String) -> Match3BoardLayout:
	var path := "res://data/Boards/%s.json" % board_id
	if not ResourceLoader.exists(path):
		for tier in ["Hard", "Normal", "Easy", "Boss"]:
			var alt := "res://data/Boards/%s/%s.json" % [tier, board_id]
			if ResourceLoader.exists(alt):
				path = alt
				break
	if not ResourceLoader.exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return null
	return BoardLayoutScript.from_json(data)
