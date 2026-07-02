extends SceneTree

## Verifies Match3 ApplyEffect/RemoveEffect invoke wiring and gameplay flag sync.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Boss Match3 Effects Test ---")
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
	print("--- Boss Match3 Effects Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var store := engine.store

	var apply_params := store.create_object()
	apply_params.set_key("effectId", "reduce_first_destroyed_item_level_each_move")
	apply_params.set_key("roundsLifetime", 1)
	var apply_result = m3.invoke_function("ApplyEffect", apply_params)
	if not (apply_result is GnosisFunctionResult) or not apply_result.is_ok:
		print("[FAIL] ApplyEffect: %s" % (apply_result.error if apply_result is GnosisFunctionResult else apply_result))
		return false

	var eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	var active := eph.get_node("activeMatch3EffectIds")
	if not active.is_valid() or active.get_count() < 1:
		print("[FAIL] activeMatch3EffectIds missing after ApplyEffect")
		return false

	var gameplay = m3.get_gameplay()
	if not gameplay.reduce_first_destroyed_item_level_enabled:
		print("[FAIL] gameplay Harold flag not enabled after ApplyEffect")
		return false

	var remove_params := store.create_object()
	remove_params.set_key("effectId", "reduce_first_destroyed_item_level_each_move")
	var remove_result = m3.invoke_function("RemoveEffect", remove_params)
	if not (remove_result is GnosisFunctionResult) or not remove_result.is_ok:
		print("[FAIL] RemoveEffect: %s" % remove_result.error)
		return false
	if gameplay.reduce_first_destroyed_item_level_enabled:
		print("[FAIL] gameplay Harold flag still enabled after RemoveEffect")
		return false

	var restrict_params := store.create_object()
	restrict_params.set_key("effectId", "score_only_exact_three_match_lines")
	restrict_params.set_key("roundsLifetime", 1)
	var restrict_result = m3.invoke_function("ApplyEffect", restrict_params)
	if not (restrict_result is GnosisFunctionResult) or not restrict_result.is_ok:
		print("[FAIL] ApplyEffect score restriction: %s" % restrict_result.error)
		return false
	if not gameplay.score_restrict_exact_three:
		print("[FAIL] exact-three score restriction not synced to gameplay")
		return false

	print("[SUCCESS] ApplyEffect/RemoveEffect + gameplay effect flags wired")
	return true
