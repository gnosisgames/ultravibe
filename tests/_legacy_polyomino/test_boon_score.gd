extends SceneTree

## Boon hook smoke check. Score-expression boons are data-driven, so the hook
## layer must preserve baseline score values unless a side-effect explicitly runs.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Boon Hook Smoke Test ---")
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
	print("--- Boon Hook Smoke Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var boon_score := FallingBlockBoonScore.new(fb)
	var base_pts := GnosisScalableValue.from_int(100)
	var base_multi := GnosisScalableValue.from_int(2)
	var result := boon_score.apply_on_line_clear(base_pts, base_multi, {"raw_lines": 1, "tags": {}})
	if not (result[0] as GnosisScalableValue).is_equal(base_pts):
		print("[FAIL] stub changed points")
		return false
	if not (result[1] as GnosisScalableValue).is_equal(base_multi):
		print("[FAIL] stub changed multi")
		return false
	print("[SUCCESS] boon hooks preserve baseline score values without equipped effects")
	return true
