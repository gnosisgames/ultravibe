class_name Match3BoonMoveHooks
extends RefCounted

## Move-end and first-match boon hooks (Unity Policy.Boons partial parity).

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const CatalogPolicyScript = preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")
const Models = preload("res://game/match3/core/match3_models.gd")
const DisplayTextScript = preload("res://game/match3/view/match3_score_floating_display_text.gd")

const BOON_CATALOG_ID_AUTOCORRECT := "Autocorrect"
const BOON_CATALOG_ID_RIZZ := "Rizz"
const BOON_CATALOG_ID_PLOT_ARMOR := "PlotArmor"
const BOON_CATALOG_ID_SIDE_HUSTLE := "SideHustle"

const PLOT_ARMOR_SHUFFLES_USED_COUNTER_KEY := "plotArmorShufflesUsed"
const FIRST_MATCH_GEM_LEVEL_CALCULATION_ID := "first_match_gem_level_chance"
const RIZZ_CALCULATION_ID := "rizz_first_match_multi_double"
const ITEM_LEVEL_UPGRADE_DISPLAY_TEXT := "+1"

const PALETTE_GEM_ITEM_IDS: Array[String] = [
	"blue", "green", "orange", "pink", "purple", "red",
]

var _service: GnosisService
var _rng := RandomNumberGenerator.new()
var _pending_autocorrect_finalize: Dictionary = {}


func _init(service: GnosisService) -> void:
	_service = service


func configure_rng(seed_value: int) -> void:
	_rng.seed = seed_value


func begin_move() -> void:
	_pending_autocorrect_finalize.clear()


func take_pending_autocorrect_finalize() -> Dictionary:
	var pending := _pending_autocorrect_finalize.duplicate()
	_pending_autocorrect_finalize.clear()
	return pending


func try_apply_first_match_gem_level_chance(first_match, gameplay) -> bool:
	if _service == null or _service.context == null or _service.context.store == null:
		return false
	if first_match == null or not ("matched_tiles" in first_match) or first_match.matched_tiles.is_empty():
		return false
	if gameplay == null:
		return false

	var gem_item_id := resolve_dominant_palette_gem_item_id(gameplay, first_match)
	if gem_item_id.is_empty():
		return false

	const NUMERATOR := 1
	const DENOMINATOR := 10
	var any := false
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		_service,
		BOON_CATALOG_ID_AUTOCORRECT,
		func(_slot: GnosisNode, slot_index: int) -> void:
			var proc := NUMERATOR >= DENOMINATOR or _rng.randi_range(0, DENOMINATOR - 1) < NUMERATOR
			if not proc:
				return
			var params := _service.context.store.create_object()
			params.set_key("itemId", gem_item_id)
			params.set_key("delta", 1)
			var result = _service.invoke_function("AddItemLevelDelta", params)
			if result is GnosisFunctionResult and result.is_ok:
				_pending_autocorrect_finalize = {
					"slotIndex": slot_index,
					"displayText": ITEM_LEVEL_UPGRADE_DISPLAY_TEXT,
				}
				any = true
	)
	return any


static func resolve_dominant_palette_gem_item_id(gameplay, first_match) -> String:
	if gameplay == null or first_match == null or not ("matched_tiles" in first_match):
		return ""
	var counts: Dictionary = {}
	for coord in first_match.matched_tiles:
		var tile = gameplay.get_tile(coord.x, coord.y)
		if tile == null or tile.is_empty() or tile.item_kind != Models.KIND_NORMAL:
			continue
		var item_id: String = tile.item_id.strip_edges().to_lower()
		if item_id.is_empty() or not PALETTE_GEM_ITEM_IDS.has(item_id):
			continue
		counts[item_id] = int(counts.get(item_id, 0)) + 1
	if counts.is_empty():
		return ""
	var best_id := ""
	var best_count := -1
	for item_id in counts.keys():
		var count := int(counts[item_id])
		if count > best_count:
			best_count = count
			best_id = item_id
	return best_id


static func compute_rizz_bonus(service: GnosisService, multi_before_step: int, multi_after_step: int) -> Dictionary:
	if not SupportScript.is_boon_catalog_id_equipped(service, BOON_CATALOG_ID_RIZZ):
		return {"multi_delta": 0, "slot_index": -1}
	var delta := multi_after_step - multi_before_step
	if delta <= 0:
		return {"multi_delta": 0, "slot_index": -1}
	var slot_index := SupportScript.index_of_active_boon_slot_by_catalog_id(service, BOON_CATALOG_ID_RIZZ)
	return {
		"multi_delta": delta,
		"slot_index": slot_index,
		"boon_id": BOON_CATALOG_ID_RIZZ,
		"calculation_id": RIZZ_CALCULATION_ID,
		"multi_display": DisplayTextScript.build_for_multi_op("multiply", 2.0),
	}


func try_plot_armor_record_manual_shuffle_usage(delta: int) -> void:
	if delta <= 0 or _service == null:
		return
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	for i in range(slot_rows.size()):
		var slot_entry: GnosisNode = slot_rows[i]
		if SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry).to_lower() != BOON_CATALOG_ID_PLOT_ARMOR.to_lower():
			continue
		ScalingScript.try_bank_boon_slot_scaling_counter(
			_service,
			i,
			slot_entry,
			PLOT_ARMOR_SHUFFLES_USED_COUNTER_KEY,
			delta,
			true
		)


func try_apply_move_end_shuffle_bonuses() -> bool:
	if _service == null:
		return false
	var changed := false
	for slot_entry in SupportScript.get_active_boon_inventory_slot_rows(_service):
		if SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry).is_empty():
			continue
		var bonus: GnosisNode = slot_entry.get_node("properties").get_node("moveEndShuffleBonus")
		if not bonus.is_valid() or bonus.get_type() != GnosisValueType.OBJECT:
			continue
		var denominator := maxi(1, SupportScript._node_int(bonus, "chanceDenominator", 1))
		var numerator := clampi(SupportScript._node_int(bonus, "chanceNumerator", 1), 0, denominator)
		if numerator <= 0:
			continue
		var roll_hits := numerator >= denominator or _rng.randi_range(0, denominator - 1) < numerator
		if not roll_hits:
			continue
		var add := maxi(0, SupportScript._node_int(bonus, "shuffleAdd", 1))
		if add <= 0:
			continue
		if _service.has_method("add_manual_shuffles"):
			_service.call("add_manual_shuffles", add)
			changed = true
	return changed


func try_apply_side_hustle_grants() -> bool:
	if _service == null or _service.context == null or _service.context.store == null:
		return false
	var money_balance := 0
	if _service.has_method("get_money"):
		money_balance = int(_service.call("get_money"))
	const MAX_MONEY_INCLUSIVE := 4
	if money_balance > MAX_MONEY_INCLUSIVE:
		return false

	var any := false
	ScalingScript.for_each_equipped_boon_slot_with_effect_application(
		_service,
		BOON_CATALOG_ID_SIDE_HUSTLE,
		func(_slot: GnosisNode, _slot_index: int) -> void:
			if _try_grant_side_hustle_consumable_from_roll():
				any = true
	)
	return any


func try_apply_active_boon_self_destructs(trigger: String, is_boss_round: bool) -> void:
	if _service == null or _service.context == null or trigger.strip_edges().is_empty():
		return
	var normalized_trigger := trigger.strip_edges().to_lower()
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	for i in range(slot_rows.size() - 1, -1, -1):
		var slot_entry: GnosisNode = slot_rows[i]
		if SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry).is_empty():
			continue
		var self_destruct := slot_entry.get_node("properties").get_node("selfDestruct")
		if not _should_self_destruct_now(self_destruct, normalized_trigger, is_boss_round):
			continue
		var instance_id := SupportScript._node_str(slot_entry, "instanceId").strip_edges()
		if instance_id.is_empty():
			continue
		_destroy_active_boon_by_instance(slot_entry, instance_id, i)


func _try_grant_side_hustle_consumable_from_roll() -> bool:
	const CHANCE_NUMERATOR := 1
	const CHANCE_DENOMINATOR := 3
	var denominator := maxi(1, CHANCE_DENOMINATOR)
	var numerator := clampi(CHANCE_NUMERATOR, 0, denominator)
	if numerator <= 0:
		return false
	var roll_hits := numerator >= denominator or _rng.randi_range(0, denominator - 1) < numerator
	if not roll_hits:
		return false

	var catalog := _build_consumable_catalog_ids()
	if catalog.is_empty():
		return false

	var boons := _service.get_node("boons", false)
	var consumables := _service.get_node("consumables", false)
	var upgrades := _service.get_node("upgrades", false)
	var m3 := _service.get_node("match3", false)
	var allow_dup := CatalogPolicyScript.read_allow_duplicate_catalog_offers(m3, boons)
	var owned := CatalogPolicyScript.collect_owned_catalog_ids(
		boons,
		consumables,
		upgrades,
		CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID,
		CatalogPolicyScript.DEFAULT_CONSUMABLE_BUCKET_ID,
		CatalogPolicyScript.DEFAULT_ITEM_UPGRADE_CATEGORY_ID
	)
	var pool: Array[String] = CatalogPolicyScript.build_offer_pool_from_catalog(
		catalog,
		owned.get("consumable", {}),
		allow_dup
	)
	if pool.is_empty():
		return false

	var pick := _rng.randi_range(0, pool.size() - 1)
	var consumable_id := pool[pick].strip_edges()
	if consumable_id.is_empty():
		return false

	var params := _service.context.store.create_object()
	params.set_key("bucketId", CatalogPolicyScript.DEFAULT_CONSUMABLE_BUCKET_ID)
	params.set_key("consumableId", consumable_id)
	var result = _service.call_service("Consumable", "AddConsumable", params)
	if result is GnosisFunctionResult and not result.is_ok:
		return false
	if result is GnosisNode and not result.is_valid():
		return false
	SupportScript.publish_ephemeral_state(_service)
	return true


func _build_consumable_catalog_ids() -> Array[String]:
	var result: Array[String] = []
	if _service == null:
		return result
	var config := _service.get_node("configuration", true)
	if not config.is_valid():
		return result
	var catalog := config.get_node("consumables")
	if not catalog.is_valid() or catalog.get_type() != GnosisValueType.OBJECT:
		return result
	for item_id in catalog.get_keys():
		var sid := str(item_id).strip_edges()
		if not sid.is_empty():
			result.append(sid)
	result.sort()
	return result


func _should_self_destruct_now(self_destruct: GnosisNode, trigger: String, is_boss_round: bool) -> bool:
	if not self_destruct.is_valid() or self_destruct.get_type() != GnosisValueType.OBJECT or trigger.is_empty():
		return false
	var configured_trigger := SupportScript._node_str(self_destruct, "trigger", "round_end").strip_edges().to_lower()
	if configured_trigger.is_empty():
		configured_trigger = "round_end"
	var trigger_matches := false
	match configured_trigger:
		"move_end":
			trigger_matches = trigger == "move_end"
		"round_end":
			trigger_matches = trigger == "round_end"
		"boss_round_end":
			trigger_matches = trigger == "round_end" and is_boss_round
	if not trigger_matches:
		return false
	if SupportScript._node_int(self_destruct, "onlyBossRounds", 0) != 0 and not is_boss_round:
		return false
	var denominator := maxi(1, SupportScript._node_int(self_destruct, "chanceDenominator", 1))
	var numerator := clampi(SupportScript._node_int(self_destruct, "chanceNumerator", 1), 0, denominator)
	if numerator <= 0:
		return false
	if numerator >= denominator:
		return true
	return _rng.randi_range(0, denominator - 1) < numerator


func _destroy_active_boon_by_instance(slot_entry: GnosisNode, instance_id: String, slot_index: int) -> void:
	if _service == null or _service.context == null or instance_id.is_empty():
		return
	var catalog_id := SupportScript.read_boon_catalog_id_from_inventory_entry(slot_entry)
	if slot_index >= 0 and not catalog_id.is_empty() and _service.has_method("play_boon_scaling_juice_now"):
		_service.call("play_boon_scaling_juice_now", slot_index, "self_destruct")
	var params := _service.context.store.create_object()
	params.set_key("instanceId", instance_id)
	params.set_key("bucketId", CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	_service.call_service("Boon", "DeactivateBoon", params)
	SupportScript.publish_ephemeral_state(_service)
