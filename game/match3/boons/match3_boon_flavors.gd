class_name Match3BoonFlavors
extends RefCounted

## Match3 equipped-boon flavor runtime (Unity Match3GnosisService.BoonFlavors partial).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const EngineFlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")
const JuiceScript = preload("res://game/match3/boons/match3_boon_juice.gd")

const SCORE_TRIGGER_OUTCOMES_PROPERTY := "scoreTriggerOutcomes"
const ROUND_START_MONEY_COST_PROPERTY := "roundStartMoneyCost"


static func try_apply_positive_flavor_after_score_step(
	service: GnosisService,
	score_helper: RefCounted,
	payload: GnosisNode,
	contributor_slot_index: int,
	contributor_boon_id: String,
	contribution_list_key: String
) -> void:
	if service == null or score_helper == null or payload == null or not payload.is_valid():
		return
	if contributor_slot_index < 0:
		return
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	if contributor_slot_index >= slot_rows.size():
		return
	var slot_entry: GnosisNode = slot_rows[contributor_slot_index]
	var flavor_id := SupportScript._node_str(
		slot_entry.get_node("properties"),
		EngineFlavorsScript.POSITIVE_FLAVOR_ID_PROPERTY
	)
	if flavor_id.is_empty():
		return
	var flavor_def := EngineFlavorsScript.get_flavor_definition(_configuration_root(service), flavor_id)
	if not flavor_def.is_valid():
		return
	var outcomes := flavor_def.get_node("properties").get_node(SCORE_TRIGGER_OUTCOMES_PROPERTY)
	if not outcomes.is_valid() or outcomes.get_type() != GnosisValueType.LIST or outcomes.get_count() == 0:
		return
	if not score_helper.has_method("_apply_score_calc_outcomes"):
		return
	var calculation_id := "flavor_%s_score_trigger" % flavor_id.strip_edges().to_lower()
	var merged_params: GnosisNode = score_helper.call(
		"_merge_calc_parameters_with_optional_boon_slot",
		GnosisNode.new(null),
		slot_entry
	)
	score_helper.call(
		"_apply_score_calc_outcomes",
		outcomes,
		payload,
		merged_params,
		contributor_boon_id,
		contributor_slot_index,
		calculation_id,
		slot_entry,
		contribution_list_key,
		-1,
		-1,
		-1,
		-1,
		-1,
		false,
		false
	)


static func try_apply_negative_flavors_on_round_start(
	service: GnosisService,
	previous_round: int,
	new_round: int
) -> void:
	if service == null or service.context == null or new_round <= 0 or new_round == previous_round:
		return
	var config := _configuration_root(service)
	for i in range(SupportScript.get_active_boon_inventory_slot_rows(service).size()):
		var slot_entry: GnosisNode = SupportScript.get_active_boon_inventory_slot_rows(service)[i]
		var flavor_id := SupportScript._node_str(
			slot_entry.get_node("properties"),
			EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY
		)
		if flavor_id.is_empty():
			continue
		var flavor_def := EngineFlavorsScript.get_flavor_definition(config, flavor_id)
		if not flavor_def.is_valid():
			continue
		var cost := maxi(0, SupportScript._node_int(
			flavor_def.get_node("properties"),
			ROUND_START_MONEY_COST_PROPERTY,
			0
		))
		if cost <= 0:
			continue
		var catalog_id := SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry)
		_try_spend_money_for_rent(service, catalog_id, i, flavor_id, cost)


static func try_apply_perishable_flavors_on_round_end(service: GnosisService) -> void:
	if service == null or service.context == null:
		return
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	for i in range(slot_rows.size() - 1, -1, -1):
		var slot_entry: GnosisNode = slot_rows[i]
		var props := slot_entry.get_node("properties")
		if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
			continue
		var rounds_node := props.get_node(EngineFlavorsScript.FLAVOR_ROUNDS_REMAINING_PROPERTY)
		if not rounds_node.is_valid():
			continue
		var remaining := maxi(0, SupportScript._node_int(props, EngineFlavorsScript.FLAVOR_ROUNDS_REMAINING_PROPERTY, 0))
		if remaining <= 0:
			continue
		remaining -= 1
		props.set_key(EngineFlavorsScript.FLAVOR_ROUNDS_REMAINING_PROPERTY, remaining)
		if remaining > 0:
			continue
		var instance_id := SupportScript._node_str(slot_entry, "instanceId").strip_edges()
		if instance_id.is_empty():
			continue
		if service.has_method("play_boon_scaling_juice_now"):
			service.call("play_boon_scaling_juice_now", i, "self_destruct")
		var params := service.context.store.create_object()
		params.set_key("instanceId", instance_id)
		params.set_key("bucketId", "default")
		service.call_service("Boon", "DeactivateBoon", params)
	SupportScript.publish_ephemeral_state(service)


static func _try_spend_money_for_rent(
	service: GnosisService,
	catalog_id: String,
	slot_index: int,
	flavor_id: String,
	cost: int
) -> void:
	if service == null or service.context == null or cost <= 0:
		return
	var args := service.context.store.create_object()
	args.set_key("currencyId", "money")
	args.set_key("amount", cost)
	var result = service.call_service("Currency", "TrySpendCurrency", args)
	if result is GnosisFunctionResult and not result.is_ok:
		return
	if result is GnosisNode and not result.is_valid():
		return
	var calculation_id := "flavor_%s_round_start_rent" % flavor_id.strip_edges().to_lower()
	JuiceScript.publish_score_juice(service, slot_index, JuiceScript.KIND_MONEY, "-%d" % cost)
	SupportScript.publish_ephemeral_state(service)


static func _configuration_root(service: GnosisService) -> GnosisNode:
	if service == null:
		return GnosisNode.new(null)
	return service.get_node("configuration", true)
