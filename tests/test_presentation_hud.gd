extends SceneTree

## Sprint 4 presentation/HUD parity: tooltip score previews, post-target sparkle
## escalation (replaces Unity ScoreFire), metrics busy gate, and reward lines.

const InventoryTooltipUiScript = preload("res://game/ui/inventory_tooltip_ui.gd")
const ScoreCalcTooltipArgsScript = preload("res://game/ui/score_calculation_tooltip_loc_args.gd")
const Match3HudScoreEscalationScript = preload("res://game/match3/view/match3_hud_score_escalation.gd")
const Match3DispatcherScript = preload("res://game/match3/view/match3_dispatcher.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Presentation HUD Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Presentation HUD Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	if not _check_tooltip_score_preview_args():
		return false
	if not _check_equipped_boon_tooltip_resolves_preview():
		return false
	if not _check_post_target_sparkle_escalation():
		return false
	if not _check_metrics_busy_wiring():
		return false
	if not _check_dynamic_round_reward_lines():
		return false
	if not _check_placeholder_sidebar_present():
		return false
	print("[SUCCESS] presentation HUD parity verified")
	return true


func _engine() -> GnosisEngine:
	return _bootstrap.engine


func _match3() -> Match3Service:
	return _engine().get_service("Match3") as Match3Service


func _check_tooltip_score_preview_args() -> bool:
	var engine := _engine()
	var config := engine.state.root.get_node("Persistent").get_node("configuration").get_node("boons")
	var entry := config.get_node("Clickbait")
	var args := ScoreCalcTooltipArgsScript.resolve_for_catalog_entry(engine, "boons", "Clickbait", entry)
	if not args.has("scoreCalculationValue1"):
		print("[FAIL] Clickbait missing scoreCalculationValue1 preview arg")
		return false
	var desc := InventoryTooltipUiScript.build_description(engine, entry, "boons", "")
	if desc.contains("${arg:"):
		print("[FAIL] tooltip description still has unresolved ${arg:...} tokens")
		return false
	if not desc.to_lower().contains("currently"):
		print("[FAIL] Clickbait description missing live preview clause")
		return false
	print("[OK] tooltip score preview args resolve in catalog descriptions")
	return true


func _check_equipped_boon_tooltip_resolves_preview() -> bool:
	var engine := _engine()
	var boon := engine.get_service("Boon")
	var activate := engine.store.create_object()
	activate.set_key("boonId", "Brainrot")
	boon.invoke_function("ActivateBoon", activate)
	var rows := preload("res://game/match3/boons/match3_boon_support.gd").get_active_boon_inventory_slot_rows(_match3())
	if rows.is_empty():
		print("[FAIL] Brainrot not equipped for HUD tooltip preview test")
		return false
	var presentation := InventoryTooltipUiScript.build_hud_presentation(engine, "boons", rows[0])
	var body := str(presentation.get("description", ""))
	if body.contains("${arg:"):
		print("[FAIL] equipped boon HUD tooltip has unresolved score preview tokens")
		return false
	print("[OK] equipped boon HUD tooltip resolves score preview")
	return true


func _check_post_target_sparkle_escalation() -> bool:
	var escalation := Match3HudScoreEscalationScript.new()
	escalation.reset_move_ramp(400, 500)
	if escalation.get_effect_intensity() > 0.001:
		print("[FAIL] sparkle escalation should start off before post-target bumps")
		return false
	escalation.update_from_step(600, 12, 4, 500)
	if escalation.get_effect_intensity() <= 0.001:
		print("[FAIL] sparkle escalation should ramp once banked score is past target")
		return false
	escalation.update_from_step(600, 20, 5, 500)
	var second := escalation.get_effect_intensity()
	escalation.update_from_step(600, 30, 6, 500)
	if escalation.get_effect_intensity() < second:
		print("[FAIL] sparkle escalation intensity should increase with post-target metric bumps")
		return false
	escalation.hide_effects()
	if escalation.get_effect_intensity() > 0.001:
		print("[FAIL] hide_effects should clear sparkle escalation")
		return false
	print("[OK] post-target sparkle escalation (Unity ScoreFire replacement)")
	return true


func _check_metrics_busy_wiring() -> bool:
	var dispatcher := Match3DispatcherScript.new()
	if not dispatcher.has_method("is_busy"):
		print("[FAIL] Match3Dispatcher missing is_busy")
		return false
	if dispatcher.is_busy():
		print("[FAIL] dispatcher should not start busy")
		return false
	var hud_scene := load("res://game/match3/view/match3_hud.tscn") as PackedScene
	if hud_scene == null:
		print("[FAIL] match3_hud scene missing")
		return false
	var hud := hud_scene.instantiate()
	if hud == null or not hud.has_method("begin_move_score_display"):
		print("[FAIL] match3_hud missing move score display API")
		return false
	if not hud.has_method("play_step_metrics_display"):
		print("[FAIL] match3_hud missing play_step_metrics_display")
		return false
	print("[OK] metrics queue wiring (dispatcher busy + HUD step display)")
	return true


func _check_dynamic_round_reward_lines() -> bool:
	var engine := _engine()
	var match3 := _match3()
	var boon := engine.get_service("Boon")
	var store := engine.store
	for boon_id in ["CookieTime", "PassiveIncome", "DoubleDown", "Sleeper"]:
		var activate := store.create_object()
		activate.set_key("boonId", boon_id)
		boon.invoke_function("ActivateBoon", activate)
	var m3_eph := engine.state.root.get_node("Ephemeral").get_node("match3")
	m3_eph.set_key("roundStartShuffles", 2)
	m3_eph.set_key("currentShuffles", 2)
	match3.call("_prepare_pending_round_reward_after_win")
	var payout := m3_eph.get_node("pendingRoundReward")
	if not payout.is_valid():
		print("[FAIL] pendingRoundReward missing after win prep")
		return false
	var steps := payout.get_node("steps")
	if not steps.is_valid() or steps.get_count() < 4:
		print("[FAIL] expected dynamic reward steps for equipped boons, got %d" % steps.get_count())
		return false
	var reasons: Dictionary = {}
	for i in range(steps.get_count()):
		var step := steps.get_node(i)
		var key := str(step.get_node("reasonKey").value).strip_edges()
		reasons[key] = true
	for required in [
		"match3__phrase__rewardCookieTime",
		"match3__phrase__rewardPassiveIncome",
		"match3__phrase__rewardDoubleDown",
		"match3__phrase__rewardSleeper",
	]:
		if not reasons.get(required, false):
			print("[FAIL] reward payout missing step %s" % required)
			return false
	print("[OK] dynamic round reward lines (CookieTime, PassiveIncome, DoubleDown, Sleeper)")
	return true


func _check_placeholder_sidebar_present() -> bool:
	var hud_scene := load("res://game/match3/view/match3_hud.tscn") as PackedScene
	var hud := hud_scene.instantiate()
	var placeholder := hud.find_child("PlaceholderButton", true, false)
	if placeholder == null:
		print("[FAIL] PlaceholderButton missing from match3_hud sidebar")
		return false
	if not placeholder.disabled:
		print("[FAIL] PlaceholderButton should stay disabled")
		return false
	if placeholder.focus_mode != Control.FOCUS_NONE:
		print("[FAIL] PlaceholderButton should not be focusable")
		return false
	if placeholder.mouse_filter != Control.MOUSE_FILTER_IGNORE:
		print("[FAIL] PlaceholderButton should ignore mouse input")
		return false
	var restart := hud.find_child("RestartHoldButton", true, false)
	if restart == null:
		print("[FAIL] RestartHoldButton missing from sidebar")
		return false
	print("[OK] sidebar placeholder present; quick restart wired on RestartHoldButton")
	return true
