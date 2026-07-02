extends SceneTree

## Verifies Match3.AddItemLevelDelta updates ephemeral item levels and score profile.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Item Level Upgrades Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _check()
	print("--- Item Level Upgrades Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var store := engine.store
	var params := store.create_object()
	params.set_key("itemId", "red")
	params.set_key("delta", 2)
	var result = m3.invoke_function("AddItemLevelDelta", params)
	if not (result is GnosisFunctionResult):
		print("[FAIL] expected GnosisFunctionResult, got %s" % typeof(result))
		return false
	if not result.is_ok:
		print("[FAIL] AddItemLevelDelta: %s" % result.error)
		return false

	var eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	var level_node := eph.get_node("itemLevels").get_node("red")
	var level := int(level_node.value) if level_node.is_valid() else -1
	if level != 3:
		print("[FAIL] red item level=%d (expected 3 after +2 from base 1)" % level)
		return false

	var stats := engine.state.root.get_node("Ephemeral").get_node("statistics").get_node("match3")
	var applied_node := stats.get_node("itemLevelUpgradesApplied")
	var applied := int(applied_node.value) if applied_node.is_valid() else -1
	if applied != 2:
		print("[FAIL] itemLevelUpgradesApplied=%d (expected 2)" % applied)
		return false

	var profile: Dictionary = m3.call("_resolve_item_score_profile", "red", "plain")
	var points := int(profile.get("points", -1))
	var multi := int(profile.get("multi", -1))
	# red.json: base 12/2, +4 per level above 1 -> level 3 => 20 points, 10 multi
	if points != 20 or multi != 10:
		print("[FAIL] red score profile points=%d multi=%d (expected 20/10)" % [points, multi])
		return false

	print("[SUCCESS] item level 3 -> red 20 pts / 10 multi, upgrades applied stat=2")
	return true
