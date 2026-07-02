extends SceneTree

## Verifies Golden run upgrade Match3 invokes update ephemeral shop/move defaults.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Run Upgrade Invokes Test ---")
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
	print("--- Run Upgrade Invokes Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var store := engine.store

	var moves_params := store.create_object()
	moves_params.set_key("delta", 2)
	var moves_result = m3.invoke_function("AddDefaultMovesPerRoundDelta", moves_params)
	if not (moves_result is GnosisFunctionResult) or not moves_result.is_ok:
		print("[FAIL] AddDefaultMovesPerRoundDelta: %s" % moves_result.error)
		return false
	var eph_m3 := engine.state.root.get_node("Ephemeral").get_node("match3")
	if int(eph_m3.get_node("defaultMovesPerRound").value) != 12:
		print("[FAIL] defaultMovesPerRound not 12 after +2")
		return false

	var discount_params := store.create_object()
	discount_params.set_key("delta", 0.1)
	var discount_result = m3.invoke_function("AddShopDiscountPercentDelta", discount_params)
	if not (discount_result is GnosisFunctionResult) or not discount_result.is_ok:
		print("[FAIL] AddShopDiscountPercentDelta: %s" % discount_result.error)
		return false
	var shop := engine.state.root.get_node("Ephemeral").get_node("match3Shop")
	var discount := float(shop.get_node("shopDiscountPercent").value)
	if discount < 0.09:
		print("[FAIL] shopDiscountPercent=%s after +0.1" % discount)
		return false

	var bonus_params := store.create_object()
	bonus_params.set_key("delta", 3)
	var bonus_result = m3.invoke_function("AddRoundMovesBonus", bonus_params)
	if not (bonus_result is GnosisFunctionResult) or not bonus_result.is_ok:
		print("[FAIL] AddRoundMovesBonus: %s" % bonus_result.error)
		return false
	if int(eph_m3.get_node("pendingRoundMovesAdd").value) != 3:
		print("[FAIL] pendingRoundMovesAdd not 3 while not playing")
		return false

	print("[SUCCESS] Golden/move bonus invokes update ephemeral state")
	return true
