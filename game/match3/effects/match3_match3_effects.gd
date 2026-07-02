class_name Match3Match3Effects
extends RefCounted

## Active Match3 round effects and boon-driven effect sync (Unity Match3Effects + BoonMatch3RoundEffects).

const AccumulatorScript = preload("res://game/match3/effects/match3_effect_rebuild_accumulator.gd")
const HandlerScript = preload("res://game/match3/effects/match3_effect_handlers.gd")
const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

const MATCH3_EFFECT_INFINITE_ROUNDS := -1
const ACTIVE_MATCH3_EFFECT_IDS_STORE_KEY := "activeMatch3EffectIds"

var _service: GnosisService
var _active_rounds: Dictionary = {}
var _stack_counts: Dictionary = {}
var _definition_cache: Dictionary = {}

var manual_shuffles_round_start_override := -1
var manual_shuffle_add := 0
var round_moves_limit_multiplier_product := 1.0
var round_moves_limit_add := 0
var tile_points_contribution_scale := 1.0
var tile_multi_contribution_scale := 1.0
var spawn_disabled_block_ids: Dictionary = {}
var random_spawn_disabled_probability := 0.0
var restrict_score_to_exact_three_line_matches := false
var restrict_score_to_exact_four_or_five_line_matches := false
var shuffle_board_after_each_move := false
var reduce_first_destroyed_item_level_each_move := false
var disable_all_cell_floor_modifiers := false
var currency_spend_per_match_by_currency_id: Dictionary = {}


func _init(service: GnosisService) -> void:
	_service = service


func hydrate_from_store(match3_root: GnosisNode) -> void:
	_active_rounds.clear()
	_stack_counts.clear()
	if match3_root == null or not match3_root.is_valid():
		sync_equipped_boon_round_effects()
		return
	var list_node: GnosisNode = match3_root.get_node(ACTIVE_MATCH3_EFFECT_IDS_STORE_KEY)
	if not list_node.is_valid() or list_node.get_type() != GnosisValueType.LIST:
		sync_equipped_boon_round_effects()
		return
	for i in range(list_node.get_count()):
		var entry: GnosisNode = list_node.get_node(i)
		if not entry.is_valid():
			continue
		if entry.get_type() == GnosisValueType.OBJECT:
			var effect_id := _normalize_effect_id(SupportScript._node_str(entry, "effectId", SupportScript._node_str(entry, "id")))
			if effect_id.is_empty():
				continue
			var rounds := SupportScript._node_int(entry, "roundsRemaining", 1)
			_active_rounds[effect_id] = rounds
			_set_stack_count(effect_id, 1)
		elif entry.get_type() == GnosisValueType.STRING:
			var effect_id := _normalize_effect_id(str(entry.value))
			if not effect_id.is_empty():
				_active_rounds[effect_id] = MATCH3_EFFECT_INFINITE_ROUNDS
				_set_stack_count(effect_id, 1)
	sync_equipped_boon_round_effects()


func persist_to_store(match3_node: GnosisNode) -> void:
	if _service == null or _service.context == null or _service.context.store == null:
		return
	if match3_node == null or not match3_node.is_valid() or match3_node.get_type() != GnosisValueType.OBJECT:
		return
	var list := _service.context.store.create_list()
	var ids: Array = _active_rounds.keys()
	ids.sort()
	for effect_id in ids:
		var row := _service.context.store.create_object()
		row.set_key("effectId", str(effect_id))
		row.set_key("roundsRemaining", int(_active_rounds[effect_id]))
		list.add(row)
	match3_node.set_key(ACTIVE_MATCH3_EFFECT_IDS_STORE_KEY, list)


func rebuild_derived_state() -> void:
	var acc := AccumulatorScript.new()
	for effect_id in _active_rounds.keys():
		var def := _load_definition(str(effect_id))
		if def.is_empty():
			continue
		var stacks := _get_stack_count(str(effect_id))
		for _stack in range(stacks):
			HandlerScript.try_apply_rebuild(str(def.get("handler", "")), def.get("parameters", {}) as Dictionary, acc)
	spawn_disabled_block_ids = acc.spawn_disabled_block_ids.duplicate()
	random_spawn_disabled_probability = clampf(acc.random_spawn_disabled_probability, 0.0, 1.0)
	tile_points_contribution_scale = acc.tile_points_scale if is_finite(acc.tile_points_scale) else 1.0
	tile_multi_contribution_scale = acc.tile_multi_scale if is_finite(acc.tile_multi_scale) else 1.0
	manual_shuffles_round_start_override = acc.manual_shuffle_override_min
	manual_shuffle_add = acc.manual_shuffle_delta_sum
	round_moves_limit_multiplier_product = acc.moves_limit_multiplier_product
	if round_moves_limit_multiplier_product <= 0.0 or not is_finite(round_moves_limit_multiplier_product):
		round_moves_limit_multiplier_product = 1.0
	round_moves_limit_add = acc.moves_limit_delta_sum
	currency_spend_per_match_by_currency_id = acc.currency_spend_per_match_by_id.duplicate()
	restrict_score_to_exact_three_line_matches = acc.restrict_score_to_exact_three_line_matches
	restrict_score_to_exact_four_or_five_line_matches = acc.restrict_score_to_exact_four_or_five_line_matches
	shuffle_board_after_each_move = acc.shuffle_board_after_each_move
	reduce_first_destroyed_item_level_each_move = acc.reduce_first_destroyed_item_level_each_move
	disable_all_cell_floor_modifiers = acc.disable_all_cell_floor_modifiers


func apply_round_budget(base_moves: int, base_shuffles: int) -> Dictionary:
	rebuild_derived_state()
	var moves_budget := maxi(1, base_moves)
	if round_moves_limit_multiplier_product > 0.0 and not is_equal_approx(round_moves_limit_multiplier_product, 1.0):
		moves_budget = maxi(1, int(round(float(moves_budget) * round_moves_limit_multiplier_product)))
	moves_budget = maxi(1, moves_budget + round_moves_limit_add)
	var shuffle_budget := maxi(0, base_shuffles + manual_shuffle_add)
	if manual_shuffles_round_start_override >= 0:
		shuffle_budget = maxi(0, manual_shuffles_round_start_override + manual_shuffle_add)
	return {"moves": moves_budget, "shuffles": shuffle_budget}


func try_commit_effect(effect_id: String, rounds_lifetime: int, stack_count: int = 1, rebuild: bool = true) -> bool:
	var key := _normalize_effect_id(effect_id)
	if key.is_empty() or _load_definition(key).is_empty():
		return false
	_active_rounds[key] = rounds_lifetime
	_set_stack_count(key, stack_count)
	if rebuild:
		rebuild_derived_state()
	return true


func sync_equipped_boon_round_effects() -> void:
	if _service == null:
		return
	var desired := _build_equipped_boon_match3_round_effect_stacks()
	var boon_managed := _collect_boon_catalog_match3_round_effect_ids()
	for effect_id in boon_managed:
		var key := str(effect_id)
		if desired.has(key) and int(desired[key]) > 0:
			continue
		if _active_rounds.erase(key):
			_definition_cache.erase(key)
			_stack_counts.erase(key)
	for effect_id in desired.keys():
		var stacks := int(desired[effect_id])
		if stacks <= 0:
			continue
		try_commit_effect(str(effect_id), MATCH3_EFFECT_INFINITE_ROUNDS, stacks, false)
	rebuild_derived_state()
	var m3: GnosisNode = _service.get_node("match3", false)
	if m3.is_valid():
		persist_to_store(m3)


func try_juice_boon_on_activate(_boon_catalog_id: String) -> void:
	pass


func invoke_apply_effect(parameters: GnosisNode) -> Dictionary:
	if _service == null or _service.context == null or _service.context.store == null:
		return {"ok": false, "error": "Store unavailable."}
	if parameters == null or not parameters.is_valid():
		return {"ok": false, "error": "ApplyEffect requires parameters."}
	var parsed := _parse_apply_effect_parameters(parameters)
	if not bool(parsed.get("ok", false)):
		return parsed
	var effect_id := str(parsed.get("effectId", ""))
	var lifetime := int(parsed.get("roundsLifetime", MATCH3_EFFECT_INFINITE_ROUNDS))
	var already := _active_rounds.has(effect_id)
	if not try_commit_effect(effect_id, lifetime):
		return {"ok": false, "error": "Unknown or invalid Match3 effect '%s'." % effect_id}
	_persist_active_effects()
	return {
		"ok": true,
		"effectId": effect_id,
		"alreadyActive": already,
		"roundsRemaining": lifetime,
		"activeCount": _active_rounds.size(),
	}


func invoke_remove_effect(parameters: GnosisNode) -> Dictionary:
	if _service == null or _service.context == null or _service.context.store == null:
		return {"ok": false, "error": "Store unavailable."}
	var effect_id := _read_remove_effect_id(parameters)
	if effect_id.is_empty():
		return {"ok": false, "error": "RemoveEffect requires a non-empty effectId."}
	var removed := _active_rounds.erase(effect_id)
	if removed:
		_definition_cache.erase(effect_id)
		_stack_counts.erase(effect_id)
	rebuild_derived_state()
	_persist_active_effects()
	return {
		"ok": true,
		"effectId": effect_id,
		"removed": removed,
		"activeCount": _active_rounds.size(),
	}


func tick_round_lifetimes() -> void:
	var mutated := false
	var snapshot: Array = []
	for effect_id in _active_rounds.keys():
		snapshot.append([str(effect_id), int(_active_rounds[effect_id])])
	for entry in snapshot:
		var effect_id: String = entry[0]
		var remaining: int = entry[1]
		if remaining < 0:
			continue
		var next := remaining - 1
		if next <= 0:
			if _active_rounds.erase(effect_id):
				mutated = true
				_stack_counts.erase(effect_id)
				_definition_cache.erase(effect_id)
		elif int(_active_rounds.get(effect_id, -999)) == remaining:
			_active_rounds[effect_id] = next
			mutated = true
	if mutated:
		rebuild_derived_state()
		_persist_active_effects()


func apply_boss_round_start_for_profile(profile_id: String, skip_if_backstabber: bool) -> void:
	if skip_if_backstabber or _service == null:
		return
	var trimmed := profile_id.strip_edges()
	if trimmed.is_empty():
		return
	var profile := _get_level_profile(trimmed)
	if profile == null or not profile.is_valid():
		return
	var invocations := profile.get_node("properties").get_node("onRoundStartInvocations")
	if not invocations.is_valid() or invocations.get_type() != GnosisValueType.LIST:
		return
	var any := false
	for i in range(invocations.get_count()):
		var inv := invocations.get_node(i)
		if not inv.is_valid() or inv.get_type() != GnosisValueType.OBJECT:
			continue
		if SupportScript._node_str(inv, "service").strip_edges().to_lower() != "match3":
			continue
		if SupportScript._node_str(inv, "function").strip_edges().to_lower() != "applyeffect":
			continue
		var result := invoke_apply_effect(inv.get_node("parameters"))
		if bool(result.get("ok", false)):
			any = true
	if any:
		rebuild_derived_state()
		_persist_active_effects()


func apply_boss_round_end_for_profile(profile_id: String) -> void:
	if _service == null:
		return
	var trimmed := profile_id.strip_edges()
	if trimmed.is_empty():
		return
	var profile := _get_level_profile(trimmed)
	if profile == null or not profile.is_valid():
		return
	var invocations := profile.get_node("properties").get_node("onRoundEndInvocations")
	if not invocations.is_valid() or invocations.get_type() != GnosisValueType.LIST:
		return
	for i in range(invocations.get_count()):
		var inv := invocations.get_node(i)
		if not inv.is_valid() or inv.get_type() != GnosisValueType.OBJECT:
			continue
		if SupportScript._node_str(inv, "service").strip_edges().to_lower() != "match3":
			continue
		if SupportScript._node_str(inv, "function").strip_edges().to_lower() != "removeeffect":
			continue
		invoke_remove_effect(inv.get_node("parameters"))


func active_effect_count() -> int:
	return _active_rounds.size()


func _persist_active_effects() -> void:
	var m3: GnosisNode = _service.get_node("match3", false)
	if m3.is_valid():
		persist_to_store(m3)


func _parse_apply_effect_parameters(parameters: GnosisNode) -> Dictionary:
	if parameters.get_type() == GnosisValueType.STRING:
		var effect_id := _normalize_effect_id(str(parameters.value))
		if effect_id.is_empty():
			return {"ok": false, "error": "ApplyEffect requires a non-empty effectId."}
		return {"ok": true, "effectId": effect_id, "roundsLifetime": MATCH3_EFFECT_INFINITE_ROUNDS}
	if parameters.get_type() != GnosisValueType.OBJECT:
		return {"ok": false, "error": "ApplyEffect parameters must be an object or effect id string."}
	var effect_id := _normalize_effect_id(
		SupportScript._node_str(parameters, "effectId", SupportScript._node_str(parameters, "id"))
	)
	if effect_id.is_empty():
		return {"ok": false, "error": "ApplyEffect requires a non-empty effectId."}
	var lifetime := MATCH3_EFFECT_INFINITE_ROUNDS
	if parameters.get_node("roundsLifetime").is_valid():
		lifetime = SupportScript._node_int(parameters, "roundsLifetime", MATCH3_EFFECT_INFINITE_ROUNDS)
	elif parameters.get_node("roundLifetime").is_valid():
		lifetime = SupportScript._node_int(parameters, "roundLifetime", MATCH3_EFFECT_INFINITE_ROUNDS)
	return {"ok": true, "effectId": effect_id, "roundsLifetime": lifetime}


func _read_remove_effect_id(parameters: GnosisNode) -> String:
	if parameters == null or not parameters.is_valid():
		return ""
	if parameters.get_type() == GnosisValueType.STRING:
		return _normalize_effect_id(str(parameters.value))
	if parameters.get_type() == GnosisValueType.OBJECT:
		return _normalize_effect_id(
			SupportScript._node_str(parameters, "effectId", SupportScript._node_str(parameters, "id"))
		)
	return ""


func _get_level_profile(profile_id: String) -> GnosisNode:
	if _service == null:
		return GnosisNode.new(null, null)
	var config := _service.get_node("configuration", true)
	if not config.is_valid():
		return GnosisNode.new(null, null)
	var levels := config.get_node("levels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		return GnosisNode.new(null, null)
	return levels.get_node(profile_id.strip_edges())


func _build_equipped_boon_match3_round_effect_stacks() -> Dictionary:
	var stacks: Dictionary = {}
	var catalog_once_counted: Dictionary = {}
	var slot_rows := SupportScript.get_active_boon_inventory_slot_rows(_service)
	for i in range(slot_rows.size()):
		var row: GnosisNode = slot_rows[i]
		var catalog_id := SupportScript.read_boon_catalog_id_from_inventory_entry(row)
		var effect_id := _normalize_effect_id(_read_boon_match3_round_effect_id(row, catalog_id))
		if effect_id.is_empty():
			continue
		if SupportScript.read_boon_effect_application_is_per_instance(row):
			stacks[effect_id] = int(stacks.get(effect_id, 0)) + 1
			continue
		if not catalog_once_counted.has(effect_id):
			catalog_once_counted[effect_id] = {}
		var seen: Dictionary = catalog_once_counted[effect_id]
		var catalog_key := catalog_id.strip_edges() if not catalog_id.is_empty() else "__row_%d" % i
		if seen.has(catalog_key.to_lower()):
			continue
		seen[catalog_key.to_lower()] = true
		stacks[effect_id] = int(stacks.get(effect_id, 0)) + 1
	return stacks


func _collect_boon_catalog_match3_round_effect_ids() -> Array[String]:
	var ids: Array[String] = []
	var boons_root: GnosisNode = _service.get_node("configuration", true).get_node("boons")
	if not boons_root.is_valid() or boons_root.get_type() != GnosisValueType.OBJECT:
		return ids
	for key in boons_root.get_keys():
		var cfg: GnosisNode = boons_root.get_node(str(key))
		if not cfg.is_valid():
			continue
		var effect_id := _normalize_effect_id(SupportScript._node_str(cfg.get_node("properties"), "match3RoundEffectId"))
		if not effect_id.is_empty() and not ids.has(effect_id):
			ids.append(effect_id)
	return ids


func _read_boon_match3_round_effect_id(slot_entry: GnosisNode, catalog_id: String) -> String:
	if slot_entry != null and slot_entry.is_valid() and slot_entry.get_type() == GnosisValueType.OBJECT:
		var props: GnosisNode = slot_entry.get_node("properties")
		if props.is_valid():
			var from_row := SupportScript._node_str(props, "match3RoundEffectId")
			if not from_row.is_empty():
				return from_row
	if catalog_id.strip_edges().is_empty():
		return ""
	var cfg: GnosisNode = _service.get_node("configuration", true).get_node("boons").get_node(catalog_id.strip_edges())
	if not cfg.is_valid():
		return ""
	return SupportScript._node_str(cfg.get_node("properties"), "match3RoundEffectId")


func _load_definition(effect_id: String) -> Dictionary:
	var key := _normalize_effect_id(effect_id)
	if key.is_empty():
		return {}
	if _definition_cache.has(key):
		return _definition_cache[key]
	var effects_root: GnosisNode = _service.get_node("configuration", true).get_node("match3Effects")
	if not effects_root.is_valid() or effects_root.get_type() != GnosisValueType.OBJECT:
		return {}
	var entry: GnosisNode = effects_root.get_node(key)
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return {}
	var data: Variant = entry.value
	if not data is Dictionary:
		return {}
	var root: Dictionary = data.duplicate(true)
	var declared_id := str(root.get("id", "")).strip_edges()
	if declared_id.is_empty():
		declared_id = key
	if declared_id.to_lower() != key.to_lower():
		return {}
	var handler := str(root.get("handler", root.get("kind", ""))).strip_edges()
	if handler.is_empty() or not HandlerScript.is_registered(handler):
		return {}
	var parameters: Dictionary = {}
	if root.has("parameters") and root["parameters"] is Dictionary:
		parameters = (root["parameters"] as Dictionary).duplicate(true)
	else:
		for k in root.keys():
			var name := str(k)
			if name.to_lower() in ["id", "handler", "kind"]:
				continue
			parameters[name] = root[k]
	var def := {"id": key, "handler": handler, "parameters": parameters}
	_definition_cache[key] = def
	return def


func _normalize_effect_id(raw: String) -> String:
	var value := raw.strip_edges()
	return value


func _get_stack_count(effect_id: String) -> int:
	var key := _normalize_effect_id(effect_id)
	return maxi(1, int(_stack_counts.get(key, 1)))


func _set_stack_count(effect_id: String, stack_count: int) -> void:
	var key := _normalize_effect_id(effect_id)
	if key.is_empty():
		return
	_stack_counts[key] = maxi(1, stack_count)
