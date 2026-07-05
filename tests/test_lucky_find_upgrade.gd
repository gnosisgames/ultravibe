extends SceneTree

## Lucky Find upgrade grants add +10% permanent chance per stack (max 2 each).

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Lucky Find Upgrade Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Lucky Find Upgrade Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	var upgrade = engine.get_service("Upgrade")
	if m3 == null or upgrade == null:
		print("[FAIL] Match3 or Upgrade service missing")
		return false

	m3.handle_run_started()
	var lucky = m3.get_lucky_find()
	if lucky == null:
		print("[FAIL] lucky find missing")
		return false
	if absf(lucky.snapshot().get("permanentChancePercent", 0.0) - 10.0) > 0.001:
		print("[FAIL] base lucky find should be 10%%, got %s" % lucky.snapshot().get("permanentChancePercent"))
		return false

	for i in range(2):
		var params := engine.store.create_object()
		params.set_key("categoryId", "itemUpgrades")
		params.set_key("upgradeId", "LuckyFindBoostI")
		var result = upgrade.invoke_function("AddUpgrade", params)
		if not _upgrade_add_succeeded(result):
			print("[FAIL] AddUpgrade LuckyFindBoostI #%d: %s" % [i + 1, str(result)])
			return false

	var expected := 30.0
	var actual := float(lucky.snapshot().get("permanentChancePercent", 0.0))
	if absf(actual - expected) > 0.001:
		print("[FAIL] after 2x LuckyFindBoostI expected %.0f%% got %.1f%%" % [expected, actual])
		return false

	m3.handle_run_started()
	actual = float(m3.get_lucky_find().snapshot().get("permanentChancePercent", 0.0))
	if absf(actual - expected) > 0.001:
		print("[FAIL] after run restart expected %.0f%% got %.1f%%" % [expected, actual])
		return false

	print("[SUCCESS] Lucky Find upgrades stack to %.0f%% (10 base + 20 bonus)" % actual)
	return true


func _upgrade_add_succeeded(result: Variant) -> bool:
	if result is GnosisFunctionResult:
		return result.is_ok
	if result is GnosisNode and result.is_valid():
		return bool(result.get_node("applied").value) if result.get_node("applied").is_valid() else true
	return result != null
