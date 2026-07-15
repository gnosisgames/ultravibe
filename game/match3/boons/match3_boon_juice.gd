class_name Match3BoonJuice
extends RefCounted

## Boon bar scaling UP juice and score-kind inference (Unity BoonPresentation partial parity).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const BoardFloatJuiceScript = preload("res://game/match3/view/match3_board_float_juice.gd")
const Match3GameSpeedScript = preload("res://game/match3/core/match3_game_speed.gd")
const EventsScript = preload("res://game/match3/match3_events.gd")

const KIND_POINTS := "points"
const KIND_MULTI := "multi"
const KIND_MONEY := "money"


static func resolve_score_kind_for_scaling(slot_entry: GnosisNode, counter_key: String = "") -> String:
	if slot_entry == null or not slot_entry.is_valid():
		return KIND_POINTS
	var key := counter_key.strip_edges().to_lower()
	var calcs := slot_entry.get_node("properties").get_node("scoreCalculations")
	if calcs.is_valid() and calcs.get_type() == GnosisValueType.LIST:
		for i in calcs.get_count():
			var calc := calcs.get_node(i)
			if not calc.is_valid():
				continue
			if not key.is_empty() and not _outcomes_reference_counter(calc.get_node("outcomes"), key):
				continue
			return _kind_from_outcomes(calc.get_node("outcomes"))
	var echoes := slot_entry.get_node("properties").get_node("contributionEchoes")
	if echoes.is_valid() and echoes.get_type() == GnosisValueType.LIST:
		for i in echoes.get_count():
			var echo := echoes.get_node(i)
			if echo.is_valid():
				return _kind_from_outcomes(echo.get_node("outcomes"))
	return KIND_POINTS


static func publish_scaling_juice(service: GnosisService, slot_index: int, counter_key: String = "") -> void:
	if service == null or service.context == null or service.context.event_bus == null:
		return
	var payload := service.context.store.create_object()
	payload.set_key("slotIndex", slot_index)
	payload.set_key("counterKey", counter_key.strip_edges())
	service.context.event_bus.publish(
		GnosisEvent.new(EventsScript.FACT_MATCH3_BOON_SCALING_JUICE, payload, false)
	)


static func try_play_scaling_up_now(service: GnosisService, slot_index: int, counter_key: String = "") -> void:
	publish_scaling_juice(service, slot_index, counter_key)


static func publish_score_juice(service: GnosisService, slot_index: int, score_kind: String, display_text: String) -> void:
	if service == null or service.context == null or service.context.event_bus == null:
		return
	var payload := service.context.store.create_object()
	payload.set_key("slotIndex", slot_index)
	payload.set_key("scoreKind", score_kind.strip_edges().to_lower())
	payload.set_key("displayText", display_text.strip_edges())
	service.context.event_bus.publish(
		GnosisEvent.new(EventsScript.FACT_MATCH3_BOON_SCORE_JUICE, payload, false)
	)


const SCALE_BUMP := 0.09
const MAX_TWIST_DEG := 10.0
const TRIGGER_JUICE_SEC := 0.15


static func play_score_on_slot(host: Node, slot: Control, score_kind: String, display_text: String) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	var accent := accent_for_kind(score_kind)
	var label := display_text.strip_edges()
	if label.is_empty():
		label = "+?"
	BoardFloatJuiceScript.spawn_labeled_popup_global(
		host,
		BoardFloatJuiceScript.hud_slot_bottom_center_global(slot),
		label,
		accent,
		0.0,
		BoardFloatJuiceScript.PopupMotion.HUD_SCALE_POP,
		BoardFloatJuiceScript.HUD_BOON_FLOAT_SIZE_SCALE
	)
	_play_trigger_juice(host, slot)


static func play_on_slot(host: Node, slot: Control, score_kind: String) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	var accent := accent_for_kind(score_kind)
	BoardFloatJuiceScript.spawn_labeled_popup_global(
		host,
		BoardFloatJuiceScript.hud_slot_bottom_center_global(slot),
		"UP",
		accent,
		0.0,
		BoardFloatJuiceScript.PopupMotion.HUD_SCALE_POP,
		BoardFloatJuiceScript.HUD_BOON_FLOAT_SIZE_SCALE
	)
	_play_trigger_juice(host, slot)


static func _play_trigger_juice(host: Node, slot: Control) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	slot.set_meta(&"sway_paused", true)
	if slot.size.x > 1.0 and slot.size.y > 1.0:
		slot.pivot_offset = slot.size * 0.5
	var twist_peak_deg := randf_range(-MAX_TWIST_DEG, MAX_TWIST_DEG)
	var tw := host.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var juice_sec := Match3GameSpeedScript.scale_duration(
		Match3GameSpeedScript.engine_from_node(host),
		TRIGGER_JUICE_SEC,
		0.04
	)
	tw.tween_method(
		func(t: float) -> void:
			if not is_instance_valid(slot):
				return
			var wave := sin(PI * t)
			slot.scale = Vector2.ONE * (1.0 + SCALE_BUMP * wave)
			slot.rotation_degrees = twist_peak_deg * wave,
		0.0,
		1.0,
		juice_sec,
	).set_trans(Tween.TRANS_LINEAR)
	tw.finished.connect(
		func() -> void:
			if is_instance_valid(slot):
				slot.scale = Vector2.ONE
				slot.set_meta(&"sway_paused", false)
	)


static func accent_for_kind(kind: String) -> Color:
	match kind.strip_edges().to_lower():
		KIND_MULTI:
			return BoardFloatJuiceScript.COLOR_MULTI
		KIND_MONEY:
			return BoardFloatJuiceScript.COLOR_MONEY
		_:
			return BoardFloatJuiceScript.COLOR_POINTS


static func _kind_from_outcomes(outcomes: GnosisNode) -> String:
	if not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST:
		return KIND_POINTS
	for i in outcomes.get_count():
		var outcome := outcomes.get_node(i)
		if not outcome.is_valid():
			continue
		var target := SupportScript._node_str(outcome, "target").to_lower()
		if target.contains("multitotal"):
			return KIND_MULTI
		if target.contains("money") or target.contains("currency"):
			return KIND_MONEY
	return KIND_POINTS


static func _outcomes_reference_counter(outcomes: GnosisNode, counter_key: String) -> bool:
	if counter_key.is_empty() or not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST:
		return false
	var needle := counter_key.strip_edges().to_lower()
	for i in outcomes.get_count():
		var value_node := outcomes.get_node(i).get_node("value")
		if value_node.is_valid() and value_node.get_type() == GnosisValueType.STRING:
			if str(value_node.value).to_lower().contains(needle):
				return true
	return false
