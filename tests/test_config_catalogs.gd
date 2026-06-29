extends SceneTree

## Verifies the data-driven configuration manifest loaded expected UltraVibe catalogs.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Config Catalog Load Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	if _done:
		return true
	_done = true
	var ok := _check()
	print("--- Config Catalog Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	var cfg := m3.get_node("configuration", true)
	var ok := true
	for cat in ["items", "match3Boards", "consumables", "boons", "themes"]:
		var node := cfg.get_node(cat)
		var count := node.get_count() if node.is_valid() and node.get_type() == GnosisValueType.OBJECT else -1
		if count <= 0:
			print("[FAIL] catalog '%s' empty or missing (count=%d)" % [cat, count])
			ok = false
		else:
			print("[SUCCESS] catalog '%s': %d entries" % [cat, count])
	return ok
