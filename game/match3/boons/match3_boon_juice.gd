class_name Match3BoonJuice
extends RefCounted

## Boon bar scaling UP juice and score-kind inference (Unity BoonPresentation partial parity).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const BoardFloatJuiceScript = preload("res://game/match3/view/match3_board_float_juice.gd")
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


static func play_score_on_slot(host: Node, slot: Control, score_kind: String, display_text: String) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	var accent := accent_for_kind(score_kind)
	var label := display_text.strip_edges()
	if label.is_empty():
		label = "+?"
	BoardFloatJuiceScript.spawn_labeled_popup_global(
		host,
		slot.global_position + Vector2(slot.size.x * 0.5, slot.size.y * 0.15),
		label,
		accent
	)
	var tw := host.create_tween()
	tw.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.12)


static func play_on_slot(host: Node, slot: Control, score_kind: String) -> void:
	if host == null or slot == null or not is_instance_valid(slot):
		return
	var accent := accent_for_kind(score_kind)
	BoardFloatJuiceScript.spawn_labeled_popup_global(
		host,
		slot.global_position + Vector2(slot.size.x * 0.5, slot.size.y * 0.15),
		"UP",
		accent
	)
	var tw := host.create_tween()
	tw.tween_property(slot, "scale", Vector2(1.12, 1.12), 0.08).set_trans(Tween.TRANS_BACK)
	tw.tween_property(slot, "scale", Vector2.ONE, 0.12)


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
