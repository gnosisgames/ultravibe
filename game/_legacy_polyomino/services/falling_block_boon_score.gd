class_name FallingBlockBoonScore
extends RefCounted

## Catalog-specific equipped-boon gameplay hooks. Score-expression boons are
## handled by rules/config; this class restores the Unity hardcoded side effects
## that run on placement, line clear, round advance, consumable use, and boss win.

var _service: GnosisService = null

const BOON_SANTA := "santa"
const BOON_BOB := "bob"
const BOON_BOUNTY := "bounty"
const BOON_DUPLICATOR := "duplicator"
const BOON_MEOW := "meow"
const BOON_MIRROR := "mirror"
const BOON_MAGIC8 := "magic8"
const BOON_WIZARD := "wizard"
const BOON_PIRATE := "pirate"
const BOON_SLAYER := "slayer"
const BOON_MUSHROOM := "mushroom"
const BOON_RAGE := "rage"
const BOON_SUNFLOWER := "sunflower"
const BOON_URF := "urf"
const BOON_EAGLE := "eagle"
const BOON_RETRO := "retro"
const BOON_RANGER := "ranger"

const BOON_MIRROR_CHANCE_PERCENT := 1
const BOON_MEOW_CHANCE_ONE_IN := 32
const BOON_MAGIC8_CHANCE_PERCENT := 25
const BOON_WIZARD_CHANCE_PERCENT := 10
const BOON_PIRATE_CHANCE_ONE_IN := 3
const BOON_SLAYER_CHANCE_ONE_IN := 2
const BOON_SLAYER_LINES_CLEARED := 4
const BOON_MUSHROOM_CHANCE_ONE_IN := 3
const BOON_RAGE_CHANCE_ONE_IN := 2
const BOON_SUNFLOWER_CHANCE_ONE_IN := 3
const BOON_URF_CHANCE_ONE_IN := 4
const BOON_URF_MAX_SECONDS_SINCE_PREVIOUS_LOCK := 3.0
const BOON_BOB_ROUND_END_CHANCE_ONE_IN := 2
const BOON_BOUNTY_ROUND_END_CHANCE_ONE_IN := 3
const BOON_DUPLICATOR_ROUND_END_CHANCE_ONE_IN := 4
const BOON_SANTA_ROUND_END_CHANCE_ONE_IN := 3
const BOON_EAGLE_HIGH_LINE_CLEAR_MAX_GRID_Y_THRESHOLD := 12
const BOON_EAGLE_ABILITY_COOLDOWN_REDUCTION_SECONDS := 5.0
const BOON_RETRO_ABILITY_COOLDOWN_REDUCTION_SECONDS := 1.0
const BOON_RANGER_CHANCE_ONE_IN := 4
const BOON_RANGER_ABILITY_COOLDOWN_REDUCTION_SECONDS := 4.0
var _previous_piece_lock_elapsed_by_player: Dictionary = {}

func _init(service: GnosisService) -> void:
	_service = service

func apply_on_line_clear(baseline_points: GnosisScalableValue, baseline_multi: GnosisScalableValue, _line_ctx: Dictionary = {}) -> Array:
	var raw_lines := int(_line_ctx.get("raw_lines", 0))
	if raw_lines > 0:
		_try_apply_rage_on_line_clear()
		_try_apply_pirate_on_line_clear(_line_ctx)
		_try_apply_slayer_on_line_clear(raw_lines)
		_try_apply_eagle_on_line_clear(_line_ctx)
		_try_apply_ranger_on_line_clear()
	return [baseline_points, baseline_multi]

func apply_on_placement(placement_ctx: Dictionary) -> void:
	var player_id := str(placement_ctx.get("player_id", "")).strip_edges()
	var seconds_since_previous := _seconds_since_previous_lock(player_id)
	_record_piece_lock_elapsed(player_id)
	_try_apply_wizard_on_placement()
	_try_apply_urf_on_placement(seconds_since_previous)
	_try_apply_retro_on_placement(placement_ctx)
	_try_apply_meow_on_placement()
	_try_apply_mirror_on_placement(placement_ctx)
	_try_apply_magic8_on_placement(placement_ctx)

func apply_on_consumable_use() -> void:
	_for_each_boon(BOON_MUSHROOM, func(_slot, _i):
		if _roll_one_in(BOON_MUSHROOM_CHANCE_ONE_IN):
			_add_discards(1.0)
	)

func apply_on_boss_defeated(_boss_ctx: Dictionary = {}) -> void:
	pass

func apply_on_round_advanced(_round_ctx: Dictionary = {}) -> void:
	_try_apply_santa_round_end_consumable_grants()
	_try_apply_bob_round_end_deck_grants()
	_try_apply_bounty_round_end_deck_grants()
	_try_apply_duplicator_round_end_deck_grants()
	_try_apply_sunflower_round_end_negative_chance_relief()

func _try_apply_santa_round_end_consumable_grants() -> void:
	_for_each_boon(BOON_SANTA, func(_slot, _i):
		if _roll_one_in(BOON_SANTA_ROUND_END_CHANCE_ONE_IN):
			_roll_random_consumable()
	)

func _try_apply_bob_round_end_deck_grants() -> void:
	_for_each_boon(BOON_BOB, func(_slot, _i):
		if _roll_one_in(BOON_BOB_ROUND_END_CHANCE_ONE_IN):
			var args := _store().create_object()
			args.set_key("ultravibeId", "Square4")
			args.set_key("variantId", "brick")
			_call("Deck", "AddDeckEntry", args)
	)

func _try_apply_bounty_round_end_deck_grants() -> void:
	_for_each_boon(BOON_BOUNTY, func(_slot, _i):
		if _roll_one_in(BOON_BOUNTY_ROUND_END_CHANCE_ONE_IN):
			_call("Deck", "AddRandomDeckEntry", _store().create_object())
	)

func _try_apply_duplicator_round_end_deck_grants() -> void:
	_for_each_boon(BOON_DUPLICATOR, func(_slot, _i):
		if _roll_one_in(BOON_DUPLICATOR_ROUND_END_CHANCE_ONE_IN):
			_call("Deck", "DuplicateRandomDeckEntry", _store().create_object())
	)

func _try_apply_sunflower_round_end_negative_chance_relief() -> void:
	_for_each_boon(BOON_SUNFLOWER, func(_slot, _i):
		if _roll_one_in(BOON_SUNFLOWER_CHANCE_ONE_IN):
			var args := _store().create_object()
			args.set_key("delta", -1)
			_call("Deck", "ChangeNegativeUltravibeChance", args)
	)

func _try_apply_retro_on_placement(placement_ctx: Dictionary) -> void:
	if int(placement_ctx.get("block_count", 0)) != 4:
		return
	_for_each_boon(BOON_RETRO, func(_slot, _i):
		_reduce_ability_cooldown(BOON_RETRO_ABILITY_COOLDOWN_REDUCTION_SECONDS)
	)

func _try_apply_meow_on_placement() -> void:
	_for_each_boon(BOON_MEOW, func(_slot, _i):
		if _roll_one_in(BOON_MEOW_CHANCE_ONE_IN):
			_roll_random_consumable()
	)

func _try_apply_mirror_on_placement(placement_ctx: Dictionary) -> void:
	var ultravibe_id := str(placement_ctx.get("ultravibe_id", "")).strip_edges()
	if ultravibe_id.is_empty():
		return
	var variant_id := str(placement_ctx.get("variant_id", "blue")).strip_edges().to_lower()
	if variant_id.is_empty():
		variant_id = "blue"
	_for_each_boon(BOON_MIRROR, func(_slot, _i):
		if _roll_percent(BOON_MIRROR_CHANCE_PERCENT):
			var args := _store().create_object()
			args.set_key("ultravibeId", ultravibe_id)
			args.set_key("variantId", variant_id)
			_call("Deck", "AddDeckEntry", args)
	)

func _try_apply_magic8_on_placement(placement_ctx: Dictionary) -> void:
	if int(placement_ctx.get("block_count", 0)) != 8:
		return
	_for_each_boon(BOON_MAGIC8, func(_slot, _i):
		if _roll_percent(BOON_MAGIC8_CHANCE_PERCENT):
			_roll_random_consumable()
	)

func _try_apply_wizard_on_placement() -> void:
	_for_each_boon(BOON_WIZARD, func(_slot, _i):
		if _roll_percent(BOON_WIZARD_CHANCE_PERCENT):
			_try_convert_random_negative_cell_to_positive()
	)

func _try_apply_urf_on_placement(seconds_since_previous_lock: float) -> void:
	if seconds_since_previous_lock < 0.0 or seconds_since_previous_lock > BOON_URF_MAX_SECONDS_SINCE_PREVIOUS_LOCK:
		return
	_for_each_boon(BOON_URF, func(_slot, _i):
		if _roll_one_in(BOON_URF_CHANCE_ONE_IN):
			_try_convert_random_negative_cell_to_positive()
	)

func _try_apply_rage_on_line_clear() -> void:
	if FallingBlockEphemeral.get_fb_float(_ctx(), "currentDiscards", 0.0) > 0.0:
		return
	_for_each_boon(BOON_RAGE, func(_slot, _i):
		if _roll_one_in(BOON_RAGE_CHANCE_ONE_IN):
			_add_discards(1.0)
	)

func _try_apply_pirate_on_line_clear(line_ctx: Dictionary) -> void:
	var tags: Dictionary = line_ctx.get("tags", {})
	if int(tags.get("discardable", 0)) < 1:
		return
	_for_each_boon(BOON_PIRATE, func(_slot, _i):
		if _roll_one_in(BOON_PIRATE_CHANCE_ONE_IN):
			_add_discards(1.0)
	)

func _try_apply_slayer_on_line_clear(raw_lines: int) -> void:
	if raw_lines != BOON_SLAYER_LINES_CLEARED:
		return
	_for_each_boon(BOON_SLAYER, func(_slot, _i):
		if _roll_one_in(BOON_SLAYER_CHANCE_ONE_IN):
			_roll_random_consumable()
	)

func _try_apply_eagle_on_line_clear(line_ctx: Dictionary) -> void:
	if int(line_ctx.get("cleared_line_max_grid_y", -1)) <= BOON_EAGLE_HIGH_LINE_CLEAR_MAX_GRID_Y_THRESHOLD:
		return
	_for_each_boon(BOON_EAGLE, func(_slot, _i):
		_reduce_ability_cooldown(BOON_EAGLE_ABILITY_COOLDOWN_REDUCTION_SECONDS)
	)

func _try_apply_ranger_on_line_clear() -> void:
	_for_each_boon(BOON_RANGER, func(_slot, _i):
		if _roll_one_in(BOON_RANGER_CHANCE_ONE_IN):
			_reduce_ability_cooldown(BOON_RANGER_ABILITY_COOLDOWN_REDUCTION_SECONDS)
	)

func _roll_random_consumable() -> void:
	_call("Consumable", "RollRandomConsumable", _store().create_object())

func _add_discards(amount: float) -> void:
	var args := _store().create_object()
	args.set_key("amount", amount)
	_call("FallingBlock", "AddDiscards", args)

func _reduce_ability_cooldown(seconds: float) -> void:
	if seconds <= 0.0 or _service == null:
		return
	if _service.has_method("reduce_ability_cooldown_remaining_seconds"):
		_service.reduce_ability_cooldown_remaining_seconds(seconds)

func _try_convert_random_negative_cell_to_positive() -> bool:
	if _service == null or not ("_runtime_grid_state" in _service) or _service._runtime_grid_state == null:
		return false
	var grid: FallingBlockModels.GridState = _service._runtime_grid_state
	var candidates: Array[int] = []
	for i in range(grid.cells.size()):
		var cell: FallingBlockModels.CellState = grid.cells[i]
		if cell == null or cell.block_id.is_empty() or not cell.is_locked:
			continue
		if _service._cell_has_immutable_tag(cell):
			continue
		for tag in _service._get_variant_tags(cell.variant_id):
			if str(tag).to_lower() == "negative":
				candidates.append(i)
				break
	if candidates.is_empty():
		return false
	var pick_idx := _seed_range_int(0, candidates.size(), 0)
	var target: FallingBlockModels.CellState = grid.cells[candidates[clampi(pick_idx, 0, candidates.size() - 1)]]
	var positive: String = _service._pick_random_variant_by_polarity(false)
	if target == null or positive.is_empty():
		return false
	target.variant_id = positive
	target.tags = _service._resolve_variant_tags(positive)
	return true

func _seconds_since_previous_lock(player_id: String) -> float:
	var key := player_id if not player_id.is_empty() else "_default"
	if not _previous_piece_lock_elapsed_by_player.has(key):
		return -1.0
	return maxf(0.0, _run_elapsed_seconds() - float(_previous_piece_lock_elapsed_by_player[key]))

func _record_piece_lock_elapsed(player_id: String) -> void:
	var key := player_id if not player_id.is_empty() else "_default"
	_previous_piece_lock_elapsed_by_player[key] = _run_elapsed_seconds()

func _run_elapsed_seconds() -> float:
	if _service != null and _service.has_method("get_run_elapsed_seconds"):
		return float(_service.get_run_elapsed_seconds())
	return 0.0

func _for_each_boon(catalog_id: String, action: Callable) -> int:
	if _service == null or not FallingBlockGameFlags.is_include_boons(_ctx()):
		return 0
	var matches: Array = []
	for i in range(_equipped_boon_slots().size()):
		var slot: GnosisNode = _equipped_boon_slots()[i]
		if _read_boon_catalog_id(slot).to_lower() == catalog_id.to_lower():
			matches.append([slot, i])
	if matches.is_empty():
		return 0
	if _is_per_instance(matches[0][0]):
		for match in matches:
			action.call(match[0], int(match[1]))
		return matches.size()
	action.call(matches[0][0], int(matches[0][1]))
	return 1

func _equipped_boon_slots() -> Array:
	var result: Array = []
	var ep := _ctx().state.root.get_node("Ephemeral") if _ctx() and _ctx().state else GnosisNode.new(null)
	if not ep.is_valid() or ep.get_type() != GnosisValueType.OBJECT:
		return result
	var boons := ep.get_node("boons")
	if not boons.is_valid() or boons.get_type() != GnosisValueType.OBJECT:
		return result
	var bag := boons.get_node("default")
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return result
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return result
	for i in range(list.get_count()):
		var slot := list.get_node(i)
		if slot.is_valid() and slot.get_type() == GnosisValueType.OBJECT:
			result.append(slot)
	return result

func _read_boon_catalog_id(slot: GnosisNode) -> String:
	var boon_id := FallingBlockEphemeral.read_string(slot.get_node("boonId"), "")
	if boon_id.is_empty():
		boon_id = FallingBlockEphemeral.read_string(slot.get_node("id"), "")
	return boon_id.strip_edges()

func _is_per_instance(slot: GnosisNode) -> bool:
	var props := slot.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	return FallingBlockEphemeral.read_string(props.get_node("effectApplication"), "catalogOnce").strip_edges().to_lower() == "perinstance"

func _roll_one_in(one_in: int) -> bool:
	return one_in > 0 and _seed_range_int(0, one_in, 0) == 0

func _roll_percent(percent: int) -> bool:
	return percent > 0 and _seed_range_int(0, 100, 0) < percent

func _seed_range_int(min_inclusive: int, max_exclusive: int, fallback: int) -> int:
	if max_exclusive <= min_inclusive:
		return fallback
	var args := _store().create_object()
	args.set_key("min", min_inclusive)
	args.set_key("max", max_exclusive)
	var res = _call("Seed", "RangeInt", args)
	if res is GnosisNode and res.is_valid():
		var value: GnosisNode = res.get_node("value")
		if value.is_valid():
			return int(value.value)
	return fallback

func _call(service_id: String, function_name: String, args: GnosisNode):
	if _service == null or _service.context == null or _service.context.engine == null:
		return null
	return _service.context.engine.call_function("FallingBlock", service_id, function_name, args)

func _store() -> GnosisStore:
	return _service.context.store

func _ctx() -> GnosisContext:
	return _service.context
