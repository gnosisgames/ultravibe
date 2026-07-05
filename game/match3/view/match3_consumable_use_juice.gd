class_name Match3ConsumableUseJuice
extends RefCounted

## Consumable bar juice: boon-style pop, floating localized "Use" label, shrink + sparkle poof.

const SparklesScene := preload("res://game/match3/view/match3_sparkles.tscn")
const TuningScript := preload("res://game/match3/view/match3_animation_tuning.gd")
const Match3GameSpeedScript := preload("res://game/match3/core/match3_game_speed.gd")
const BoardFloatJuiceScript := preload("res://game/match3/view/match3_board_float_juice.gd")
const ConsumableDbgScript := preload("res://game/match3/debug/match3_consumable_debug.gd")

const DISPLAY_USE := "Use"
const SCALE_BUMP := 0.09
const MAX_TWIST_DEG := 10.0
const POOF_AT_SCALE := 0.5


static func run_two_phase(host: Node, slot: Control, effect_text: String, service) -> void:
	ConsumableDbgScript.phase("Juice.run_two_phase", "start %s" % ConsumableDbgScript.slot_snapshot(slot), service)
	if host == null or not is_instance_valid(host) or host.get_tree() == null:
		ConsumableDbgScript.fatal("Juice.run_two_phase", "invalid host")
		return
	if slot == null or not is_instance_valid(slot):
		ConsumableDbgScript.fatal("Juice.run_two_phase", "invalid slot at start")
		return
	_prepare_slot(slot)
	await host.get_tree().process_frame
	ConsumableDbgScript.phase("Juice.run_two_phase", "after process_frame %s" % ConsumableDbgScript.slot_snapshot(slot), service)
	_spawn_effect_floating_text(host, slot, effect_text)
	await _pop_phase(host, slot, service)
	ConsumableDbgScript.phase("Juice.run_two_phase", "after pop_phase %s" % ConsumableDbgScript.slot_snapshot(slot), service)
	var gap := TuningScript.consumable_use_remove_gap(service)
	if gap > 0.0:
		await host.get_tree().create_timer(gap).timeout
	await _remove_phase(host, slot, service)
	ConsumableDbgScript.phase("Juice.run_two_phase", "after remove_phase valid=%s" % str(is_instance_valid(slot)), service)
	if is_instance_valid(slot):
		slot.queue_free()


static func _prepare_slot(slot: Control) -> void:
	slot.pivot_offset = Vector2(slot.size.x * 0.5, slot.size.y * 0.5)
	slot.rotation = 0.0
	slot.scale = Vector2.ONE
	for child in slot.get_children():
		if child is Button:
			child.disabled = true
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _pop_phase(host: Node, slot: Control, service) -> void:
	if not is_instance_valid(slot):
		return
	var total := TuningScript.consumable_use_pop_duration(service)
	var twist_peak := deg_to_rad(randf_range(-MAX_TWIST_DEG, MAX_TWIST_DEG))
	var elapsed := 0.0
	while elapsed < total:
		if not is_instance_valid(slot):
			return
		await host.get_tree().process_frame
		elapsed += host.get_process_delta_time()
		var t := clampf(elapsed / maxf(total, 0.0001), 0.0, 1.0)
		var wave := sin(PI * t)
		slot.scale = Vector2.ONE * (1.0 + SCALE_BUMP * wave)
		slot.rotation = twist_peak * wave
	if is_instance_valid(slot):
		slot.scale = Vector2.ONE
		slot.rotation = 0.0


static func _remove_phase(host: Node, slot: Control, service) -> void:
	if not is_instance_valid(slot):
		return
	var total := TuningScript.consumable_use_remove_duration(service)
	var twist_peak := deg_to_rad(randf_range(-MAX_TWIST_DEG, MAX_TWIST_DEG))
	var poof_spawned := false
	var passed_peak := false
	var elapsed := 0.0
	while elapsed < total:
		if not is_instance_valid(slot):
			return
		await host.get_tree().process_frame
		elapsed += host.get_process_delta_time()
		var t := clampf(elapsed / maxf(total, 0.0001), 0.0, 1.0)
		var wave := sin(PI * t)
		var multiplier := (1.0 - t) * (1.0 + SCALE_BUMP * wave)
		slot.scale = Vector2.ONE * multiplier
		slot.rotation = twist_peak * wave
		if t >= 0.5:
			passed_peak = true
		if not poof_spawned and passed_peak and multiplier <= POOF_AT_SCALE:
			_spawn_poof(host, slot)
			poof_spawned = true
	if is_instance_valid(slot) and not poof_spawned:
		_spawn_poof(host, slot)


static func _spawn_poof(host: Node, slot: Control) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	UltraUiFx.play_ui_sfx(host, "poof", -2.0)
	var anchor := slot.global_position + slot.size * 0.5
	if SparklesScene == null:
		return
	var fx = SparklesScene.instantiate()
	var layer: Node = slot.get_parent() if is_instance_valid(slot.get_parent()) else host
	layer.add_child(fx)
	if fx is Node2D:
		fx.global_position = anchor
	elif fx is Control:
		fx.top_level = true
		fx.global_position = anchor


static func _spawn_effect_floating_text(host: Node, slot: Control, effect_text: String) -> void:
	var text := effect_text.strip_edges()
	if text.is_empty():
		text = DISPLAY_USE
	if host == null or slot == null or not is_instance_valid(slot):
		return
	var overlay := slot.get_parent()
	if overlay == null or not (overlay is Control):
		return
	var slot_size := slot.size
	if slot_size.x < 1.0 or slot_size.y < 1.0:
		slot_size = slot.custom_minimum_size
	var local_anchor := BoardFloatJuiceScript.hud_slot_bottom_center_local(slot)
	BoardFloatJuiceScript.spawn_labeled_popup(
		overlay as Control,
		local_anchor,
		text,
		BoardFloatJuiceScript.COLOR_MONEY,
		0.0,
		BoardFloatJuiceScript.PopupMotion.HUD_SCALE_POP
	)


static func pulse_bar(panel: Control) -> Tween:
	if panel == null or not is_instance_valid(panel):
		return null
	panel.pivot_offset = panel.size * 0.5
	var engine := Match3GameSpeedScript.engine_from_node(panel)
	var out_sec := Match3GameSpeedScript.scale_duration(engine, 0.12, 0.03)
	var back_sec := Match3GameSpeedScript.scale_duration(engine, 0.14, 0.03)
	var tw := panel.create_tween()
	tw.tween_property(panel, "scale", Vector2(1.03, 1.03), out_sec).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2.ONE, back_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw
