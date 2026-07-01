class_name Match3BoonRuntime
extends RefCounted

## Match3 boon invoke router and gameplay hooks (Unity boon partials entry point).

const GrantsScript = preload("res://game/match3/boons/match3_boon_grants.gd")
const ScoreScript = preload("res://game/match3/boons/match3_boon_score.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const ScalingScript = preload("res://game/match3/boons/match3_boon_scaling.gd")
const CatalogPolicyScript = preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")

const BOON_SLOT_CAPACITY_ENGINE_MAX := 32
const CONSUMABLE_SLOT_CAPACITY_ENGINE_MAX := 32

var _service: GnosisService
var _grants: RefCounted
var _score: RefCounted
var _previous_round_for_boon_hooks := 0


func _init(service: GnosisService) -> void:
	_service = service
	_grants = GrantsScript.new(service)
	_score = ScoreScript.new(service)


func get_invoke_names() -> Array[String]:
	return [
		"RollRandomBoon",
		"DuplicateRandomEquippedBoon",
		"PanicSwapAllEquippedBoons",
		"ApplyBoonSlotCapacityDelta",
		"ApplyConsumableSlotCapacityDelta",
		"JuiceBoonMatch3RoundEffectOnActivate",
		"SyncEquippedBoonMatch3RoundEffects",
	]


func handles_invoke(name: String) -> bool:
	return get_invoke_names().has(name)


func invoke(name: String, parameters: GnosisNode) -> Variant:
	match name:
		"RollRandomBoon":
			return _grants.roll_random_boon(parameters)
		"DuplicateRandomEquippedBoon":
			return _grants.duplicate_random_equipped_boon(parameters)
		"PanicSwapAllEquippedBoons":
			return _grants.panic_swap_all_equipped_boons(parameters)
		"ApplyBoonSlotCapacityDelta":
			return apply_boon_slot_capacity_delta(parameters)
		"ApplyConsumableSlotCapacityDelta":
			return apply_consumable_slot_capacity_delta(parameters)
		"JuiceBoonMatch3RoundEffectOnActivate":
			var boon_id := SupportScript._node_str(parameters, "boonId")
			if _service.has_method("on_boon_activated"):
				_service.call("on_boon_activated", boon_id)
			var ok: GnosisNode = _service.context.store.create_object()
			ok.set_key("success", true)
			return GnosisFunctionResult.ok(ok)
		"SyncEquippedBoonMatch3RoundEffects":
			if _service.has_method("sync_equipped_boon_match3_round_effects"):
				_service.call("sync_equipped_boon_match3_round_effects")
			var payload: GnosisNode = _service.context.store.create_object()
			payload.set_key("success", true)
			payload.set_key("activeCount", _service.get_match3_effects_active_count() if _service.has_method("get_match3_effects_active_count") else 0)
			return GnosisFunctionResult.ok(payload)
	return GnosisFunctionResult.fail("Unknown boon invoke '%s'." % name)


func apply_finalize_for_move(results: Array, points: int, multi: int) -> Dictionary:
	return _score.apply_finalize_for_move(results, points, multi)


func begin_resolve_step(step, results: Array, points: int, multi: int, destroyed_count: int) -> void:
	_score.begin_resolve_step(step, results, points, multi, destroyed_count)


func apply_resolve_item_destroyed(
	item_id: String,
	step,
	results: Array,
	points: int,
	multi: int,
	destroyed_count: int
) -> Dictionary:
	return _score.apply_item_destroyed(item_id, step, results, points, multi, destroyed_count)


func apply_resolve_step_cascade(
	step,
	results: Array,
	points: int,
	multi: int,
	destroyed_count: int
) -> Dictionary:
	return _score.apply_resolve_step_cascade(step, results, points, multi, destroyed_count)


func apply_cell_floor_finalize_echo(floor_type_id: String, points: int, multi: int) -> Dictionary:
	return _score.apply_cell_floor_finalize_echo(floor_type_id, points, multi)


func apply_round_end_scaling_increments() -> void:
	ScalingScript.apply_round_end_scaling_increments(_service, _score)


func apply_resolve_step_scaling_for_step(step) -> void:
	ScalingScript.apply_resolve_step_scaling_increments(_service, _score, step)


func on_round_boundary(previous_round: int, new_round: int) -> void:
	_grants.try_grant_hype_train_round_start_common_boons(previous_round, new_round)
	_previous_round_for_boon_hooks = new_round


func on_round_skipped() -> void:
	_grants.try_grant_crypto_bro_currency_on_round_skip()


func apply_boon_slot_capacity_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	if _service.context == null or _service.context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var delta := SupportScript._node_int(parameters, "delta", 0)
	if delta == 0:
		return GnosisFunctionResult.fail("ApplyBoonSlotCapacityDelta requires non-zero 'delta'.")
	var bucket_id := SupportScript._node_str(parameters, "bucketId", CatalogPolicyScript.DEFAULT_BOON_BUCKET_ID)
	var boons_buckets: GnosisNode = _service.get_node("boons", false)
	if not boons_buckets.is_valid():
		return GnosisFunctionResult.fail("Boon buckets unavailable.")
	var boons_bag: GnosisNode = boons_buckets.get_node(bucket_id)
	if not boons_bag.is_valid():
		return GnosisFunctionResult.fail("Boon bucket '%s' unavailable." % bucket_id)
	var list: GnosisNode = boons_bag.get_node("list")
	var list_count: int = list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var current_max := SupportScript.read_boon_bag_max_slot_capacity(boons_bag)
	var min_cap := maxi(1, list_count)
	var next_max := clampi(current_max + delta, min_cap, BOON_SLOT_CAPACITY_ENGINE_MAX)
	if next_max == current_max:
		var unchanged: GnosisNode = _service.context.store.create_object()
		unchanged.set_key("success", true)
		unchanged.set_key("maxSlots", float(current_max))
		unchanged.set_key("delta", float(delta))
		unchanged.set_key("changed", false)
		return GnosisFunctionResult.ok(unchanged)
	boons_bag.set_key("maxSize", next_max)
	_service.set_node("maxBoonSlots", next_max, false)
	_sync_boon_bag_slot_count_metrics(boons_buckets, boons_bag)
	SupportScript.publish_ephemeral_state(_service)
	var payload: GnosisNode = _service.context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("changed", true)
	payload.set_key("delta", float(delta))
	payload.set_key("previousMaxSlots", float(current_max))
	payload.set_key("maxSlots", float(next_max))
	return GnosisFunctionResult.ok(payload)


func apply_consumable_slot_capacity_delta(parameters: GnosisNode) -> GnosisFunctionResult:
	if _service.context == null or _service.context.store == null:
		return GnosisFunctionResult.fail("Store unavailable.")
	var delta := SupportScript._node_int(parameters, "delta", 0)
	if delta == 0:
		return GnosisFunctionResult.fail("ApplyConsumableSlotCapacityDelta requires non-zero 'delta'.")
	var bucket_id := SupportScript._node_str(parameters, "bucketId", CatalogPolicyScript.DEFAULT_CONSUMABLE_BUCKET_ID)
	var consumables_buckets: GnosisNode = _service.get_node("consumables", false)
	if not consumables_buckets.is_valid():
		return GnosisFunctionResult.fail("Consumable buckets unavailable.")
	var bag: GnosisNode = consumables_buckets.get_node(bucket_id)
	if not bag.is_valid():
		return GnosisFunctionResult.fail("Consumable bucket '%s' unavailable." % bucket_id)
	var list: GnosisNode = bag.get_node("list")
	var list_count: int = list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var current_max := maxi(1, SupportScript._node_int(bag, "maxSize", 1))
	var min_cap := maxi(1, list_count)
	var next_max := clampi(current_max + delta, min_cap, CONSUMABLE_SLOT_CAPACITY_ENGINE_MAX)
	if next_max == current_max:
		var unchanged: GnosisNode = _service.context.store.create_object()
		unchanged.set_key("success", true)
		unchanged.set_key("maxSlots", float(current_max))
		unchanged.set_key("delta", float(delta))
		unchanged.set_key("changed", false)
		return GnosisFunctionResult.ok(unchanged)
	bag.set_key("maxSize", next_max)
	_sync_consumable_bag_slot_count_metrics(consumables_buckets, bag)
	SupportScript.publish_ephemeral_state(_service)
	var payload: GnosisNode = _service.context.store.create_object()
	payload.set_key("success", true)
	payload.set_key("changed", true)
	payload.set_key("delta", float(delta))
	payload.set_key("previousMaxSlots", float(current_max))
	payload.set_key("maxSlots", float(next_max))
	return GnosisFunctionResult.ok(payload)


func _sync_boon_bag_slot_count_metrics(boons_buckets: GnosisNode, boons_bag: GnosisNode) -> void:
	if boons_bag == null or not boons_bag.is_valid():
		return
	var list := boons_bag.get_node("list")
	var list_count := list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var max_size := SupportScript.read_boon_bag_max_slot_capacity(boons_bag)
	boons_bag.set_key("listCount", list_count)
	boons_bag.set_key("filledSlotsCount", list_count)
	boons_bag.set_key("emptySlotsCount", maxi(0, max_size - list_count))
	if boons_buckets != null and boons_buckets.is_valid():
		boons_buckets.set_key("filledSlotsCount", list_count)
		boons_buckets.set_key("emptySlotsCount", maxi(0, max_size - list_count))


func _sync_consumable_bag_slot_count_metrics(consumables_buckets: GnosisNode, bag: GnosisNode) -> void:
	if bag == null or not bag.is_valid():
		return
	var list := bag.get_node("list")
	var list_count := list.get_count() if list.is_valid() and list.get_type() == GnosisValueType.LIST else 0
	var max_size := maxi(1, SupportScript._node_int(bag, "maxSize", 1))
	bag.set_key("listCount", list_count)
	bag.set_key("filledSlotsCount", list_count)
	bag.set_key("emptySlotsCount", maxi(0, max_size - list_count))
	if consumables_buckets != null and consumables_buckets.is_valid():
		consumables_buckets.set_key("filledSlotsCount", list_count)
		consumables_buckets.set_key("emptySlotsCount", maxi(0, max_size - list_count))
