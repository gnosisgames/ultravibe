extends SceneTree

## Sprint 6 UI parity smoke tests: heartbeat, score fire, boon reorder invoke, rich tooltips.

const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")
const Match3HudScoreFireScript = preload("res://game/match3/view/match3_hud_score_fire.gd")
const Match3BoardGamepadScript = preload("res://game/match3/view/match3_board_gamepad.gd")
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Sprint 6 UI Test ---")
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
	print("--- Sprint 6 UI Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_heartbeat_config():
		return false
	if not _check_score_fire_ramp():
		return false
	if not _check_boon_reorder_invoke():
		return false
	if not _check_rich_tooltip_tags():
		return false
	if Match3BoardGamepadScript.new() == null:
		print("[FAIL] board gamepad helper missing")
		return false
	print("[SUCCESS] Sprint 6 UI parity helpers wired")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _check_heartbeat_config() -> bool:
	var match3 := _engine().get_service("Match3")
	if match3 == null:
		print("[FAIL] Match3 missing")
		return false
	if not match3.has_method("get_heartbeat_delay_after_move_complete_seconds"):
		print("[FAIL] heartbeat delay method missing")
		return false
	var delay := float(match3.get_heartbeat_delay_after_move_complete_seconds())
	if delay < 0.0 or delay > 3.0:
		print("[FAIL] heartbeat delay out of range: %s" % delay)
		return false
	var m3 := _engine().state.root.get_node("Ephemeral").get_node("match3")
	var audio := m3.get_node("audio")
	var clips := audio.get_node("heartbeatSfxClipIds")
	if not clips.is_valid() or clips.get_count() < 1:
		print("[FAIL] heartbeat clip ids missing in ephemeral")
		return false
	print("[OK] heartbeat audio config present (delay=%s)" % delay)
	return true


func _check_score_fire_ramp() -> bool:
	var fire := Match3HudScoreFireScript.new()
	fire.reset_move_ramp(1000, 500)
	fire.update_from_step(1000, 50, 2, 500)
	fire.update_from_step(1000, 80, 3, 500)
	fire.fade_toward_off(1.0)
	fire.hide_fire()
	print("[OK] score fire ramp helper")
	return true


func _check_boon_reorder_invoke() -> bool:
	var engine := _engine()
	var match3 := engine.get_service("Match3")
	var boon := engine.get_service("Boon")
	var store := engine.store
	var activate := store.create_object()
	activate.set_key("boonId", "Brainrot")
	var activate_result = boon.invoke_function("ActivateBoon", activate)
	if activate_result == null or not (activate_result is GnosisNode) or not activate_result.is_valid():
		print("[FAIL] could not activate boon for reorder test")
		return false
	var rows := SupportScript.get_active_boon_inventory_slot_rows(match3)
	if rows.is_empty():
		print("[FAIL] no equipped boons after activate")
		return false
	var params := store.create_object()
	params.set_key("bucketId", "default")
	var ids := store.create_list()
	for row in rows:
		var instance_id := str(row.get_node("instanceId").value).strip_edges()
		if instance_id.is_empty():
			instance_id = SupportScript.read_boon_catalog_id_from_inventory_entry(row)
		if instance_id.is_empty():
			print("[FAIL] could not resolve boon id for reorder")
			return false
		ids.add(instance_id)
	params.set_node("boonInstanceIds", ids)
	var result = boon.invoke_function("ReorderBoons", params)
	if result == null or not (result is GnosisNode):
		print("[FAIL] ReorderBoons failed")
		return false
	print("[OK] ReorderBoons invoke")
	return true


func _check_rich_tooltip_tags() -> bool:
	var engine := _engine()
	var config := engine.state.root.get_node("Persistent").get_node("configuration").get_node("boons")
	var entry := config.get_node("Brainrot")
	var tags := InventoryTooltipUiScript.build_tags(engine, entry.get_node("metadata"), entry)
	if tags.is_empty():
		print("[FAIL] expected metadata tags for Brainrot")
		return false
	var desc := InventoryTooltipUiScript.build_description(engine, entry, "boons", "")
	if desc.strip_edges().is_empty():
		print("[FAIL] rich description empty for Brainrot")
		return false
	print("[OK] rich inventory tooltip content (%d tags)" % tags.size())
	return true
