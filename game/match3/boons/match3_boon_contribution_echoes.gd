class_name Match3BoonContributionEchoes
extends RefCounted

## Data-driven listener boon reactions (Unity ContributionEchoes partial parity).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ScoreScript = preload("res://game/match3/boons/match3_boon_score.gd")

const SOURCE_BOON_SCORE_STEP := "boon_score_step"
const SOURCE_CELL_FLOOR_FINALIZE := "cell_floor_finalize_step"
const CONTRIBUTOR_OTHER_BOON := "other_boon"


static func try_apply_after_boon_score_step(
	service: GnosisService,
	score_helper: RefCounted,
	payload: GnosisNode,
	contributor_boon_id: String,
	contributor_slot_index: int,
	contribution_list_key: String
) -> void:
	if service == null or payload == null or not payload.is_valid():
		return
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	for listener_slot in range(slot_rows.size()):
		var listener_entry: GnosisNode = slot_rows[listener_slot]
		var listener_id := SupportScript.read_boon_catalog_id_from_inventory_entry(listener_entry)
		if listener_id.is_empty():
			continue
		var echoes := listener_entry.get_node("properties").get_node("contributionEchoes")
		if not echoes.is_valid() or echoes.get_type() != GnosisValueType.LIST:
			continue
		for i in echoes.get_count():
			var echo := echoes.get_node(i)
			if not echo.is_valid():
				continue
			if not _listen_matches_boon_score_step(
				echo.get_node("listen"),
				contributor_boon_id,
				contributor_slot_index,
				listener_id,
				listener_slot,
				slot_rows
			):
				continue
			var echo_id := SupportScript._node_str(echo, "id")
			if score_helper != null and score_helper.has_method("_apply_echo_outcomes"):
				score_helper.call(
					"_apply_echo_outcomes",
					echo,
					payload,
					listener_id,
					listener_slot,
					echo_id,
					contribution_list_key
				)


static func try_apply_after_cell_floor_finalize(
	service: GnosisService,
	score_helper: RefCounted,
	payload: GnosisNode,
	floor_type_id: String,
	contribution_list_key: String
) -> void:
	if service == null or payload == null or not payload.is_valid():
		return
	var floor_id := floor_type_id.strip_edges()
	if floor_id.is_empty():
		return
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	for listener_slot in range(slot_rows.size()):
		var listener_entry: GnosisNode = slot_rows[listener_slot]
		var listener_id := SupportScript.read_boon_catalog_id_from_inventory_entry(listener_entry)
		if listener_id.is_empty():
			continue
		var echoes := listener_entry.get_node("properties").get_node("contributionEchoes")
		if not echoes.is_valid() or echoes.get_type() != GnosisValueType.LIST:
			continue
		for i in echoes.get_count():
			var echo := echoes.get_node(i)
			if not echo.is_valid():
				continue
			var listen := echo.get_node("listen")
			if SupportScript._node_str(listen, "source").to_lower() != SOURCE_CELL_FLOOR_FINALIZE:
				continue
			if SupportScript._node_str(listen, "floorTypeId").to_lower() != floor_id.to_lower():
				continue
			var echo_id := SupportScript._node_str(echo, "id")
			if score_helper != null and score_helper.has_method("_apply_echo_outcomes"):
				score_helper.call(
					"_apply_echo_outcomes",
					echo,
					payload,
					listener_id,
					listener_slot,
					echo_id,
					contribution_list_key
				)


static func _listen_matches_boon_score_step(
	listen: GnosisNode,
	contributor_boon_id: String,
	contributor_slot_index: int,
	listener_boon_id: String,
	listener_slot_index: int,
	slot_rows: Array
) -> bool:
	if not listen.is_valid():
		return false
	if SupportScript._node_str(listen, "source").to_lower() != SOURCE_BOON_SCORE_STEP:
		return false
	var exclude_self := true
	var exclude_node := listen.get_node("excludeSelf")
	if exclude_node.is_valid():
		if exclude_node.get_type() == GnosisValueType.BOOL:
			exclude_self = bool(exclude_node.value)
		elif exclude_node.get_type() == GnosisValueType.INT:
			exclude_self = int(exclude_node.value) != 0
	if exclude_self and contributor_boon_id.to_lower() == listener_boon_id.to_lower():
		return false
	var contributor := SupportScript._node_str(listen, "contributor", CONTRIBUTOR_OTHER_BOON).to_lower()
	if contributor == CONTRIBUTOR_OTHER_BOON:
		if contributor_boon_id.is_empty():
			return false
		if exclude_self and contributor_slot_index == listener_slot_index:
			return false
	var required_tag := SupportScript._node_str(listen, "contributorGameplayTag")
	if not required_tag.is_empty():
		if contributor_slot_index < 0 or contributor_slot_index >= slot_rows.size():
			return false
		if not SupportScript.boon_slot_entry_has_gameplay_tag(slot_rows[contributor_slot_index], required_tag):
			return false
	return true
