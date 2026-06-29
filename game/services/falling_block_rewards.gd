class_name FallingBlockRewards
extends RefCounted

## Round-advance reward cycle for Ultravibe. Ported from
## FallingBlockGnosisService.Reward.RewardsCycle.partial.cs (+ Reward.partial.cs and
## FallingBlockRunCatalogOfferPolicy.cs). Rolls reward offers (consumable / boon /
## rare upgrade-or-ability), persists them on Ephemeral, and grants the selected
## offer when a round completes by dispatching to the engine item services.
##
## Reward selection is player-driven: when a round completes, the current offer
## row is marked pending; the UI selects a slot and calls claim.

const REWARD_OFFERS_KEY := "rewardOffers"
const SELECTED_REWARD_SLOT_INDEX := "selectedRewardSlotIndex"
const REWARD_CHOICE_COUNT := "rewardChoiceCount"
const REWARD_SELECTION_PENDING := "rewardSelectionPending"
const EMPTY_BOON_SLOTS_COUNT := "emptyBoonSlotsCount"
const FILLED_BOON_SLOTS_COUNT := "filledBoonSlotsCount"
const MAX_BOON_SLOTS := "maxBoonSlots"
const RARE_OFFER_CHANCE_KEY := "roundRewardRareOfferChancePercent"

const MAX_REWARD_SLOTS := 5
## Number of offers shown in the inline board reward row (old Unity parity).
const INLINE_REWARD_SLOT_COUNT := 3
const DEFAULT_RARE_OFFER_CHANCE := 30
const DEFAULT_BUCKET := "default"
const RUN_UPGRADES_CATEGORY := "run"

var _service: GnosisService = null
var _burst_granted := {}

func _init(service: GnosisService) -> void:
	_service = service

# --- Lifecycle hooks (called from FallingBlockService) ---

## Run start: roll fresh offers, or validate/keep restored ones.
func ensure_offers_on_run_start() -> void:
	if _ctx() == null or _ctx().store == null:
		return
	_set_selection_pending(false)
	if not FallingBlockGameFlags.is_include_rewards(_ctx()):
		_write_offers([])
		_sync_reward_row(0, 0)
		return
	var offers := _read_offers()
	if offers.is_empty():
		refresh_offers()
		return
	var count: int = min(MAX_REWARD_SLOTS, offers.size())
	var valid := 0
	for i in range(count):
		if _parse_offer(offers[i]) != null:
			valid += 1
		else:
			break
	if valid == 0:
		refresh_offers()
	else:
		_sync_reward_row(valid, 0)

func reset_burst() -> void:
	_burst_granted.clear()

## Grant the round reward. First completed round in a burst grants the player's
## selected offer; subsequent rounds grant a random offer (mirrors C# loop).
func grant_on_round_advance(grant_selected: bool) -> void:
	if _ctx() == null:
		return
	if grant_selected:
		_grant_selected_round_reward()
	else:
		_grant_random_round_reward()

## Re-roll the reward row once a progress burst finishes.
func refresh_offers() -> void:
	if _ctx() == null:
		return
	_set_selection_pending(false)
	if not FallingBlockGameFlags.is_include_rewards(_ctx()):
		_write_offers([])
		_sync_reward_row(0, 0)
		return
	var offers := _roll_round_offers()
	_write_offers(offers)
	_sync_reward_row(min(INLINE_REWARD_SLOT_COUNT, offers.size()), 0)

func begin_selection() -> bool:
	if _ctx() == null or not FallingBlockGameFlags.is_include_rewards(_ctx()):
		return false
	if _effective_choice_count() <= 0:
		return false
	_set_selection_pending(true)
	return true

func has_pending_selection() -> bool:
	return _read_root_bool(_ephemeral_root(), REWARD_SELECTION_PENDING, false)

func select_slot(index: int) -> void:
	_sync_reward_row(_effective_choice_count(), index)

func claim_selected_reward() -> bool:
	if not has_pending_selection():
		return false
	var choice_count := _effective_choice_count()
	if choice_count <= 0:
		_set_selection_pending(false)
		return false
	var offers := _read_offers()
	var selected := clampi(_get_selected_index(), 0, choice_count - 1)
	if selected >= offers.size():
		_set_selection_pending(false)
		return false
	var parsed = _parse_offer(offers[selected])
	if parsed == null:
		_set_selection_pending(false)
		return false
	_grant_offer_by_type(parsed[0], parsed[1])
	_remember_granted(parsed[0], parsed[1])
	refresh_offers()
	return true

# --- Granting ---

func _grant_selected_round_reward() -> void:
	var choice_count := _effective_choice_count()
	if choice_count <= 0:
		return
	var offers := _read_offers()
	var selected := _get_selected_index()
	if selected < 0 or selected >= offers.size() or selected >= choice_count:
		return
	var parsed = _parse_offer(offers[selected])
	if parsed == null:
		return
	_grant_offer_by_type(parsed[0], parsed[1])
	_remember_granted(parsed[0], parsed[1])

func _grant_random_round_reward() -> void:
	var picked = _roll_single_random_offer(_burst_granted)
	if picked == null:
		return
	_grant_offer_by_type(picked[0], picked[1])
	_remember_granted(picked[0], picked[1])

func _grant_offer_by_type(type_raw: String, item_id: String) -> void:
	if item_id.strip_edges().is_empty() or not FallingBlockGameFlags.is_include_rewards(_ctx()):
		return
	var t := _normalize_type(type_raw)
	var args := _ctx().store.create_object()
	match t:
		"consumable":
			if not FallingBlockGameFlags.is_include_consumables(_ctx()):
				return
			args.set_key("consumableId", item_id.strip_edges())
			args.set_key("bucketId", DEFAULT_BUCKET)
			_service.call_service("Consumable", "AddConsumable", args)
		"boon":
			if not FallingBlockGameFlags.is_include_boons(_ctx()):
				return
			args.set_key("boonId", item_id.strip_edges())
			args.set_key("bucketId", DEFAULT_BUCKET)
			_service.call_service("Boon", "ActivateBoon", args)
		"upgrade":
			if not FallingBlockGameFlags.is_include_upgrades(_ctx()):
				return
			args.set_key("upgradeId", item_id.strip_edges())
			args.set_key("categoryId", RUN_UPGRADES_CATEGORY)
			_service.call_service("Upgrade", "AddUpgrade", args)
		"ability":
			if not FallingBlockGameFlags.is_include_abilities(_ctx()):
				return
			args.set_key("abilityId", item_id.strip_edges())
			_service.call_service("Ability", "AddAbility", args)
		_:
			return
	FallingBlockCollection.mark_discovered(_ctx(), t, item_id)

# --- Offer rolling ---

func _roll_round_offers() -> Array:
	var pools := _build_catalog_offer_pools()
	var consumables: Array = pools[0]
	var boons: Array = pools[1]
	var used := {}
	var result: Array = []
	var rare_slot := -1
	if _should_offer_rare_reward():
		rare_slot = _seed_range_int(0, INLINE_REWARD_SLOT_COUNT, 0)
	for i in range(INLINE_REWARD_SLOT_COUNT):
		if i == rare_slot:
			var rare = _try_pick_rare_reward_offer(used)
			if rare != null:
				used[_format_key(rare[0], rare[1])] = true
				result.append(_build_offer_node(rare[0], rare[1]))
				continue
		var pick = _try_pick_catalog_offer(consumables, boons, used)
		if pick == null:
			break
		used["%s:%s" % [pick[0], pick[1]]] = true
		result.append(_build_offer_node(pick[0], pick[1]))
	return result

func _roll_single_random_offer(exclude: Dictionary):
	if _should_offer_rare_reward():
		var rare = _try_pick_rare_reward_offer(exclude)
		if rare != null:
			return rare
	var pools := _build_catalog_offer_pools()
	return _try_pick_catalog_offer(pools[0], pools[1], exclude)

func _try_pick_catalog_offer(consumables: Array, boons: Array, used: Dictionary):
	var can_consumable := not consumables.is_empty()
	var can_boon := not boons.is_empty() and _has_available_boon_slots()
	if not can_consumable and not can_boon:
		return null
	var pick_type := ""
	if can_consumable and can_boon:
		pick_type = "consumable" if _seed_range_int(0, 2, 0) == 0 else "boon"
	elif can_consumable:
		pick_type = "consumable"
	else:
		pick_type = "boon"
	var item_id := _pick_catalog_item(pick_type, consumables, boons, used)
	if item_id.is_empty() and can_consumable and can_boon:
		pick_type = "boon" if pick_type == "consumable" else "consumable"
		item_id = _pick_catalog_item(pick_type, consumables, boons, used)
	if item_id.is_empty():
		return null
	return [pick_type, item_id]

func _try_pick_rare_reward_offer(exclude: Dictionary):
	var include_upgrades := FallingBlockGameFlags.is_include_upgrades(_ctx())
	var include_abilities := FallingBlockGameFlags.is_include_abilities(_ctx())
	if not include_upgrades and not include_abilities:
		return null

	# Early run: guarantee an ability while the player owns none.
	if include_abilities and not _has_owned_abilities():
		var guaranteed := _pick_ability_offer(exclude)
		if not guaranteed.is_empty():
			return ["ability", guaranteed]

	var upgrade_id := _pick_upgrade_offer(exclude) if include_upgrades else ""
	var ability_id := _pick_ability_offer(exclude) if include_abilities else ""
	var has_upgrade := not upgrade_id.is_empty()
	var has_ability := not ability_id.is_empty()
	if not has_upgrade and not has_ability:
		return null
	if has_upgrade and not has_ability:
		return ["upgrade", upgrade_id]
	if has_ability and not has_upgrade:
		return ["ability", ability_id]
	if _seed_range_int(0, 2, 0) == 0:
		return ["upgrade", upgrade_id]
	return ["ability", ability_id]

func _pick_catalog_item(pick_type: String, consumables: Array, boons: Array, used: Dictionary) -> String:
	var pool := consumables if pick_type == "consumable" else boons
	return _pick_unused_random_id(pool, used, pick_type)

func _pick_unused_random_id(pool: Array, used: Dictionary, prefix: String) -> String:
	if pool.is_empty():
		return ""
	var candidates: Array = []
	for id in pool:
		if not used.has("%s:%s" % [prefix, id]):
			candidates.append(id)
	if candidates.is_empty():
		return ""
	var idx := _seed_range_int(0, candidates.size(), 0)
	if idx < 0 or idx >= candidates.size():
		idx = 0
	return str(candidates[idx])

func _pick_ability_offer(exclude: Dictionary) -> String:
	var catalog := _list_config_keys("abilities")
	if catalog.is_empty():
		return ""
	var owned := _owned_ability_ids()
	var mode := _current_mode()
	var candidates: Array = []
	for id in catalog:
		var sid := str(id)
		if owned.has(sid.to_lower()):
			continue
		if exclude.has(_format_key("ability", sid)):
			continue
		if not _ability_enabled_in_mode(sid, mode):
			continue
		candidates.append(sid)
	if candidates.is_empty():
		return ""
	var idx := _seed_range_int(0, candidates.size(), 0)
	if idx < 0 or idx >= candidates.size():
		idx = 0
	return str(candidates[idx])

func _current_mode() -> String:
	var ep := _ephemeral_root()
	if not ep.is_valid():
		return "solo"
	var n := ep.get_node("mode")
	if n.is_valid() and n.value != null:
		return str(n.value).strip_edges().to_lower()
	return "solo"

## An ability is offerable only when its config has no enabledModes restriction or
## explicitly lists the current run mode. Coop-only abilities (e.g. gridShift, which
## is auto-granted in co-op) are therefore never offered as a solo reward.
func _ability_enabled_in_mode(ability_id: String, mode: String) -> bool:
	var root := _config_root()
	if not root.is_valid() or root.get_type() != GnosisValueType.OBJECT:
		return true
	var abilities := root.get_node("abilities")
	if not abilities.is_valid() or abilities.get_type() != GnosisValueType.OBJECT:
		return true
	var cfg := abilities.get_node(ability_id)
	if not cfg.is_valid() or cfg.get_type() != GnosisValueType.OBJECT:
		return true
	var props := cfg.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return true
	var modes := props.get_node("enabledModes")
	if not modes.is_valid() or modes.get_type() != GnosisValueType.LIST:
		return true
	if modes.get_count() == 0:
		return true
	for i in range(modes.get_count()):
		var m := modes.get_node(i)
		if m.is_valid() and m.value != null and str(m.value).strip_edges().to_lower() == mode:
			return true
	return false

func _pick_upgrade_offer(exclude: Dictionary) -> String:
	var pick_args := _ctx().store.create_object()
	pick_args.set_key("categoryId", RUN_UPGRADES_CATEGORY)
	var exclude_ids: Array = []
	for key in exclude.keys():
		if str(key).begins_with("upgrade:"):
			var id := str(key).substr("upgrade:".length()).strip_edges()
			if not id.is_empty():
				exclude_ids.append(id)
	if not exclude_ids.is_empty():
		pick_args.set_key("excludeUpgradeIds", _ctx().store.create_value(exclude_ids))
	var res = _service.call_service("Upgrade", "GetRandomEligibleUpgrade", pick_args)
	if res == null or not (res is GnosisNode):
		return ""
	var node: GnosisNode = res
	if not node.is_valid() or node.get_type() != GnosisValueType.OBJECT:
		return ""
	var id_node := node.get_node("upgradeId")
	if id_node.is_valid() and id_node.get_type() == GnosisValueType.STRING:
		return str(id_node.value).strip_edges()
	return ""

# --- Catalog pools ---

func _build_catalog_offer_pools() -> Array:
	if not FallingBlockGameFlags.is_include_rewards(_ctx()):
		return [[], []]
	var consumable_catalog := _list_config_keys("consumables") if FallingBlockGameFlags.is_include_consumables(_ctx()) else []
	var boon_catalog := _list_config_keys("boons") if FallingBlockGameFlags.is_include_boons(_ctx()) else []
	var ep := _ephemeral_root()
	var boon_buckets := ep.get_node("boons") if ep.is_valid() else GnosisNode.new(null)
	var consumable_buckets := ep.get_node("consumables") if ep.is_valid() else GnosisNode.new(null)
	var owned_boons := _collect_owned_ids(boon_buckets, "boonId", "id")
	var owned_consumables := _collect_owned_ids(consumable_buckets, "id", "")
	var consumables := _build_pool(consumable_catalog, owned_consumables, _read_bag_allow_duplicates(consumable_buckets))
	var boons := _build_pool(boon_catalog, owned_boons, _read_bag_allow_duplicates(boon_buckets))
	return [consumables, boons]

func _build_pool(catalog: Array, owned: Dictionary, allow_dup: bool) -> Array:
	if catalog.is_empty():
		return []
	if allow_dup:
		return catalog.duplicate()
	var r: Array = []
	for id in catalog:
		var sid := str(id).strip_edges()
		if sid.is_empty():
			continue
		if owned.has(sid.to_lower()):
			continue
		r.append(id)
	return r

func _collect_owned_ids(buckets_root: GnosisNode, primary: String, secondary: String) -> Dictionary:
	var owned := {}
	if buckets_root == null or not buckets_root.is_valid() or buckets_root.get_type() != GnosisValueType.OBJECT:
		return owned
	var bag := buckets_root.get_node(DEFAULT_BUCKET)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return owned
	var list := bag.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return owned
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var id := _read_entry_str(entry, primary)
		if id.is_empty() and not secondary.is_empty():
			id = _read_entry_str(entry, secondary)
		if not id.is_empty():
			owned[id.strip_edges().to_lower()] = true
	return owned

func _read_bag_allow_duplicates(buckets_root: GnosisNode) -> bool:
	if buckets_root == null or not buckets_root.is_valid() or buckets_root.get_type() != GnosisValueType.OBJECT:
		return false
	var bag := buckets_root.get_node(DEFAULT_BUCKET)
	if not bag.is_valid() or bag.get_type() != GnosisValueType.OBJECT:
		return false
	var v := bag.get_node("allowDuplicates")
	if v.is_valid() and v.get_type() == GnosisValueType.BOOL:
		return bool(v.value)
	return false

func _list_config_keys(category: String) -> Array:
	var list: Array = []
	var root := _config_root()
	if not root.is_valid() or root.get_type() != GnosisValueType.OBJECT:
		return list
	var cat := root.get_node(category)
	if not cat.is_valid() or cat.get_type() != GnosisValueType.OBJECT:
		return list
	for key in cat.get_keys():
		if str(key).strip_edges().is_empty():
			continue
		var node := cat.get_node(key)
		if not node.is_valid() or node.get_type() != GnosisValueType.OBJECT:
			continue
		if category == "boons" and not _read_catalog_entry_valid(node):
			continue
		list.append(str(key))
	return list

func _read_catalog_entry_valid(entry: GnosisNode, default_when_missing := true) -> bool:
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return default_when_missing
	var props := entry.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return default_when_missing
	var v := props.get_node("valid")
	if not v.is_valid() or v.get_type() != GnosisValueType.BOOL:
		return default_when_missing
	return bool(v.value)

# --- Availability checks ---

func _should_offer_rare_reward() -> bool:
	var roll := _seed_range_int(0, 100, 0)
	return roll < _read_rare_offer_chance()

func _read_rare_offer_chance() -> int:
	var pct := FallingBlockEphemeral.get_fb_int(_ctx(), RARE_OFFER_CHANCE_KEY, DEFAULT_RARE_OFFER_CHANCE)
	return clampi(pct, 0, 100)

func _has_available_boon_slots() -> bool:
	var ep := _ephemeral_root()
	if not ep.is_valid():
		return true
	var empty := _read_root_int(ep, EMPTY_BOON_SLOTS_COUNT, -1)
	if empty >= 0:
		return empty > 0
	var max_slots := _read_root_int(ep, MAX_BOON_SLOTS, 0)
	var filled := _read_root_int(ep, FILLED_BOON_SLOTS_COUNT, 0)
	if max_slots > 0:
		return filled < max_slots
	return true

func _has_owned_abilities() -> bool:
	return not _owned_ability_ids().is_empty()

func _owned_ability_ids() -> Dictionary:
	var owned := {}
	var params := _ctx().store.create_object()
	params.set_key("bucketId", DEFAULT_BUCKET)
	var res = _service.call_service("Ability", "GetList", params)
	if res == null or not (res is GnosisNode):
		return owned
	var node: GnosisNode = res
	if not node.is_valid() or node.get_type() != GnosisValueType.OBJECT:
		return owned
	var list := node.get_node("list")
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return owned
	for i in range(list.get_count()):
		var entry := list.get_node(i)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var id := _read_entry_str(entry, "id")
		if id.is_empty():
			id = _read_entry_str(entry, "abilityId")
		if not id.is_empty():
			owned[id.strip_edges().to_lower()] = true
	return owned

# --- Ephemeral offer storage (root-level keys, matching C#) ---

func _read_offers() -> Array:
	var result: Array = []
	var ep := _ephemeral_root()
	if not ep.is_valid() or ep.get_type() != GnosisValueType.OBJECT:
		return result
	var list := ep.get_node(REWARD_OFFERS_KEY)
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return result
	for i in range(list.get_count()):
		result.append(list.get_node(i))
	return result

func _write_offers(offers: Array) -> void:
	var list := _ctx().store.create_list()
	for o in offers:
		list.add(o)
	var ep := _ephemeral_root()
	if ep.is_valid() and ep.get_type() == GnosisValueType.OBJECT:
		ep.set_key(REWARD_OFFERS_KEY, list)

func _get_selected_index() -> int:
	return _read_root_int(_ephemeral_root(), SELECTED_REWARD_SLOT_INDEX, 0)

func _set_selected_index(idx: int) -> void:
	var ep := _ephemeral_root()
	if ep.is_valid() and ep.get_type() == GnosisValueType.OBJECT:
		ep.set_key(SELECTED_REWARD_SLOT_INDEX, idx)

func _set_choice_count(c: int) -> void:
	var ep := _ephemeral_root()
	if ep.is_valid() and ep.get_type() == GnosisValueType.OBJECT:
		ep.set_key(REWARD_CHOICE_COUNT, c)

func _set_selection_pending(value: bool) -> void:
	var ep := _ephemeral_root()
	if ep.is_valid() and ep.get_type() == GnosisValueType.OBJECT:
		ep.set_key(REWARD_SELECTION_PENDING, value)

func _effective_choice_count() -> int:
	var offers := _read_offers()
	var from_offers := 0
	for i in range(min(offers.size(), MAX_REWARD_SLOTS)):
		if _parse_offer(offers[i]) != null:
			from_offers += 1
		else:
			break
	var stored := _read_root_int(_ephemeral_root(), REWARD_CHOICE_COUNT, 0)
	if from_offers <= 0:
		return clampi(stored, 0, MAX_REWARD_SLOTS)
	if stored <= 0:
		return min(MAX_REWARD_SLOTS, from_offers)
	return min(MAX_REWARD_SLOTS, max(stored, from_offers))

func _sync_reward_row(choice_count: int, selected_index: int) -> void:
	choice_count = clampi(choice_count, 0, MAX_REWARD_SLOTS)
	var max_sel := (choice_count - 1) if choice_count > 0 else 0
	selected_index = clampi(selected_index, 0, max_sel)
	_set_choice_count(choice_count)
	_set_selected_index(selected_index)

# --- Helpers ---

func _build_offer_node(type_raw: String, item_id: String) -> GnosisNode:
	var o := _ctx().store.create_object()
	o.set_key("type", type_raw)
	o.set_key("itemId", item_id)
	return o

func _parse_offer(entry: GnosisNode):
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return null
	var t := entry.get_node("type")
	var id := entry.get_node("itemId")
	if not t.is_valid() or t.get_type() != GnosisValueType.STRING:
		return null
	if not id.is_valid() or id.get_type() != GnosisValueType.STRING:
		return null
	var type_s := str(t.value).strip_edges()
	var id_s := str(id.value).strip_edges()
	if type_s.is_empty() or id_s.is_empty():
		return null
	return [type_s, id_s]

func _remember_granted(type_raw: String, item_id: String) -> void:
	if item_id.strip_edges().is_empty():
		return
	_burst_granted[_format_key(type_raw, item_id)] = true

func _format_key(type_raw: String, item_id: String) -> String:
	return "%s:%s" % [_normalize_type(type_raw), item_id.strip_edges()]

func _normalize_type(raw: String) -> String:
	return raw.strip_edges().to_lower()

func _seed_range_int(min_inclusive: int, max_exclusive: int, fallback: int) -> int:
	if max_exclusive <= min_inclusive:
		return fallback
	var params := _ctx().store.create_object()
	params.set_key("min", min_inclusive)
	params.set_key("max", max_exclusive)
	var res = _service.call_service("Seed", "RangeInt", params)
	if res is GnosisNode and res.is_valid():
		var v: GnosisNode = res.get_node("value")
		if v.is_valid():
			return int(v.value)
	return fallback

func _read_entry_str(entry: GnosisNode, key: String) -> String:
	var n := entry.get_node(key)
	if n.is_valid() and n.value != null and n.get_type() == GnosisValueType.STRING:
		return str(n.value)
	return ""

func _read_root_int(node: GnosisNode, key: String, default_value: int) -> int:
	if node == null or not node.is_valid():
		return default_value
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		var t := n.get_type()
		if t == GnosisValueType.INT or t == GnosisValueType.LONG:
			return int(n.value)
		if t == GnosisValueType.FLOAT:
			return int(round(n.value))
	return default_value

func _read_root_bool(node: GnosisNode, key: String, default_value: bool) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var n := node.get_node(key)
	if n.is_valid() and n.get_type() == GnosisValueType.BOOL:
		return bool(n.value)
	return default_value

func _ctx() -> GnosisContext:
	return _service.context

func _ephemeral_root() -> GnosisNode:
	if _ctx() == null or _ctx().state == null:
		return GnosisNode.new(null)
	return _ctx().state.root.get_node("Ephemeral")

func _config_root() -> GnosisNode:
	return _service.get_node("configuration", true)
