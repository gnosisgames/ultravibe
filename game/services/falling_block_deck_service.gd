class_name FallingBlockDeckService
extends GnosisService

## Gnosis-side deck service for Ultravibe. Draws ultravibe + variant selections,
## maintains the next-pieces preview queue, runs the spawn interceptor pipeline, and
## injects negative pieces per game flags. Ported from FallingBlockDeckService.cs (+partials).

const E = preload("res://game/services/falling_block_events.gd")

const NEXT_PIECES_QUEUE_SIZE := 3
const DEFAULT_NEGATIVE_ULTRAVIBE_CHANCE_MAX := 25
const NEGATIVE_INJECTION_ABNORMAL_SHAPE_CHANCE_PERCENT := 25

const EPHEMERAL_DECK_ENTRIES := "deckEntries"
const EPHEMERAL_DECK_LENGTH := "deckLength"
const EPHEMERAL_DECK_COUNT := "deckCount"
## Per-player upcoming pieces. An object keyed by player id ("P0".."P3"); every
## player has an independent preview queue but draws from the shared deckEntries.
## Solo play uses the single "P0" lane so the model is uniform everywhere.
const EPHEMERAL_NEXT_PIECES_QUEUES := "nextPiecesQueues"
const DEFAULT_PLAYER_ID := "P0"
const EPHEMERAL_DECK_ENTRY_ID_COUNTER := "deckEntryIdCounter"
const EPHEMERAL_MIN_DECK_SIZE := "minDeckSize"
const EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE := "negativeUltravibeChance"
const EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_MIN := "negativeUltravibeChanceMin"
const EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_MAX := "negativeUltravibeChanceMax"

const STAT_DECK_ENTRIES_ADDED := "tetris.deck.entriesAdded"
const STAT_DECK_ENTRIES_REMOVED := "tetris.deck.entriesRemoved"

var _neutral_variant_ids: Array[String] = []
var _negative_variant_ids: Array[String] = []
var _spawn_needed_subscription: RefCounted = null

func _init() -> void:
	super("Deck", GnosisLifetime.TRANSIENT)

func on_initialize() -> void:
	if not context or not context.event_bus:
		return
	_enforce_negative_chance_within_bounds()
	_spawn_needed_subscription = context.event_bus.subscribe(
		E.FACT_FALLING_BLOCK_SPAWN_NEEDED, _on_spawn_needed, 50)

func on_run_ended() -> void:
	if _spawn_needed_subscription and _spawn_needed_subscription.has_method("dispose"):
		_spawn_needed_subscription.dispose()
	_spawn_needed_subscription = null

func on_shutdown() -> void:
	on_run_ended()

func get_functions() -> Array:
	return [
		"DrawPiece", "AddDeckEntry", "AddRandomDeckEntry", "RemoveDeckEntry",
		"GetDeckLength", "SetDeckEntryVariant", "ChangeNegativeUltravibeChance",
		"DuplicateRandomDeckEntry", "RemoveRandomDeckEntry",
	]

func invoke_function(name: String, parameters: GnosisNode) -> Variant:
	match name:
		"DrawPiece": return _handle_draw_piece(parameters)
		"AddDeckEntry": return _handle_add_deck_entry(parameters)
		"AddRandomDeckEntry": return _handle_add_random_deck_entry()
		"RemoveDeckEntry": return _handle_remove_deck_entry(parameters)
		"GetDeckLength": return _handle_get_deck_length()
		"SetDeckEntryVariant": return _handle_set_deck_entry_variant(parameters)
		"ChangeNegativeUltravibeChance": return _handle_change_negative_chance(parameters)
		"DuplicateRandomDeckEntry": return _handle_duplicate_random_deck_entry()
		"RemoveRandomDeckEntry": return _handle_remove_random_deck_entry()
	return GnosisFunctionResult.fail("Function '%s' not found on service 'Deck'." % name)

# --- Ephemeral access ---

func _fb() -> GnosisNode:
	return FallingBlockEphemeral.get_fb(context)

func _get_fb_int(leaf: String, default_value: int = 0) -> int:
	return FallingBlockEphemeral.read_int(_fb().get_node(leaf), default_value)

func _get_fb_float(leaf: String, default_value: float = 0.0) -> float:
	return FallingBlockEphemeral.read_float(_fb().get_node(leaf), default_value)

func _get_fb_node(leaf: String) -> GnosisNode:
	return _fb().get_node(leaf)

func _set_fb_int(leaf: String, value: int) -> void:
	_fb().set_node(leaf, value)

func _set_fb_float(leaf: String, value: float) -> void:
	_fb().set_node(leaf, value)

func _set_fb_node(leaf: String, value: GnosisNode) -> void:
	_fb().set_node(leaf, value)

# --- Per-player next-pieces queues ---

func _normalize_player_id(player_id: String) -> String:
	return player_id if not player_id.is_empty() else DEFAULT_PLAYER_ID

## The object holding every player's queue, created lazily.
func _get_queues_root() -> GnosisNode:
	var root := _get_fb_node(EPHEMERAL_NEXT_PIECES_QUEUES)
	if not root.is_valid() or root.get_type() != GnosisValueType.OBJECT:
		root = context.store.create_object()
		_set_fb_node(EPHEMERAL_NEXT_PIECES_QUEUES, root)
	return root

## A single player's queue list, created lazily under the queues root.
func _get_player_queue(player_id: String) -> GnosisNode:
	var key := _normalize_player_id(player_id)
	var root := _get_queues_root()
	var queue := root.get_node(key)
	if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST:
		queue = context.store.create_list()
		root.set_node(key, queue)
	return queue

func _set_player_queue(player_id: String, queue: GnosisNode) -> void:
	_get_queues_root().set_node(_normalize_player_id(player_id), queue)

# --- Seed RNG ---

func _seed_range_int(min_inclusive: int, max_exclusive: int, fallback: int) -> int:
	if max_exclusive <= min_inclusive:
		return fallback
	var params := context.store.create_object()
	params.set_key("min", min_inclusive)
	params.set_key("max", max_exclusive)
	var res = call_service("Seed", "RangeInt", params)
	if res is GnosisNode and res.is_valid():
		var v: GnosisNode = res.get_node("value")
		if v.is_valid():
			return int(v.value)
	return fallback

func _seed_random_float01(fallback: float) -> float:
	var params := context.store.create_object()
	params.set_key("min", 0.0)
	params.set_key("max", 1.0)
	var res = call_service("Seed", "RangeFloat", params)
	if res is GnosisNode and res.is_valid():
		var v: GnosisNode = res.get_node("value")
		if v.is_valid():
			return float(v.value)
	return fallback

# --- Public functions ---

func _handle_add_deck_entry(parameters: GnosisNode) -> GnosisFunctionResult:
	var ultravibe_id := _read_param_string(parameters, E.PAYLOAD_ULTRAVIBE_ID)
	var variant_id := _read_param_string(parameters, E.PAYLOAD_VARIANT_ID)
	if ultravibe_id.is_empty():
		return GnosisFunctionResult.fail("AddDeckEntry requires non-empty ultravibeId.")
	if variant_id.is_empty():
		return GnosisFunctionResult.fail("AddDeckEntry requires non-empty variantId.")
	variant_id = variant_id.to_lower()

	var request := context.store.create_object()
	request.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	request.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	request.set_key(E.PAYLOAD_ALLOWED, true)
	var final_payload := _publish(E.REQUEST_FALLING_BLOCK_DECK_ADD_ENTRY, request)
	if not _payload_bool(final_payload, E.PAYLOAD_ALLOWED, true):
		_publish_fact(E.FACT_FALLING_BLOCK_DECK_ADD_ENTRY_DENIED, final_payload)
		return GnosisFunctionResult.fail("AddDeckEntry denied by interceptor.")

	ultravibe_id = _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	variant_id = _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, variant_id).to_lower()

	if not _has_ultravibe_in_config(ultravibe_id):
		return GnosisFunctionResult.fail("Unknown ultravibeId '%s'." % ultravibe_id)
	if not _has_variant_in_config(variant_id):
		return GnosisFunctionResult.fail("Unknown variantId '%s'." % variant_id)

	var deck_entries := _ensure_deck_entries_list()
	var deck_entry_id := _generate_next_deck_entry_id()
	var entry := context.store.create_object()
	entry.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	entry.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	entry.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	deck_entries.add(entry)
	_sync_deck_length(deck_entries)

	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	payload.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	payload.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	payload.set_key("deckLength", float(deck_entries.get_count()))
	_publish_fact(E.FACT_FALLING_BLOCK_DECK_ADD_ENTRY_CONFIRMED, payload)
	_increment_statistic(STAT_DECK_ENTRIES_ADDED, 1.0)
	return GnosisFunctionResult.ok(payload)

func _handle_add_random_deck_entry() -> GnosisFunctionResult:
	var candidates := _get_ultravibe_ids_by_tag("basic")
	if candidates.is_empty():
		return GnosisFunctionResult.fail("No ultravibe candidates for AddRandomDeckEntry.")
	var positives := _get_variant_ids_by_tag("positive")
	if positives.is_empty():
		return GnosisFunctionResult.fail("No positive variants for AddRandomDeckEntry.")
	var ultravibe_id: String = candidates[_seed_range_int(0, candidates.size(), 0)]
	var variant_id: String = positives[_seed_range_int(0, positives.size(), 0)]

	var request := context.store.create_object()
	request.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	request.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	request.set_key(E.PAYLOAD_ALLOWED, true)
	var final_payload := _publish(E.REQUEST_FALLING_BLOCK_DECK_ADD_RANDOM_ENTRY, request)
	if not _payload_bool(final_payload, E.PAYLOAD_ALLOWED, true):
		_publish_fact(E.FACT_FALLING_BLOCK_DECK_ADD_RANDOM_ENTRY_DENIED, final_payload)
		return GnosisFunctionResult.fail("AddRandomDeckEntry denied by interceptor.")

	var args := context.store.create_object()
	args.set_key(E.PAYLOAD_ULTRAVIBE_ID, _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id))
	args.set_key(E.PAYLOAD_VARIANT_ID, _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, variant_id))
	var result := _handle_add_deck_entry(args)
	if result.is_ok:
		_publish_fact(E.FACT_FALLING_BLOCK_DECK_ADD_RANDOM_ENTRY_CONFIRMED, result.payload)
	return result

func _handle_remove_deck_entry(parameters: GnosisNode) -> GnosisFunctionResult:
	var deck_entry_id := _read_param_string(parameters, E.PAYLOAD_DECK_ENTRY_ID)
	if deck_entry_id.is_empty():
		deck_entry_id = _read_param_string(parameters, "deckId")
	if deck_entry_id.is_empty():
		return GnosisFunctionResult.fail("RemoveDeckEntry requires deckEntryId (or deckId).")

	var request := context.store.create_object()
	request.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	request.set_key(E.PAYLOAD_ALLOWED, true)
	var final_payload := _publish(E.REQUEST_FALLING_BLOCK_DECK_REMOVE_ENTRY, request)
	if not _payload_bool(final_payload, E.PAYLOAD_ALLOWED, true):
		_publish_fact(E.FACT_FALLING_BLOCK_DECK_REMOVE_ENTRY_DENIED, final_payload)
		return GnosisFunctionResult.fail("RemoveDeckEntry denied by interceptor.")
	deck_entry_id = _payload_string(final_payload, E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)

	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST or deck_entries.get_count() == 0:
		return GnosisFunctionResult.fail("deckEntries is empty.")

	var removed_index := -1
	var removed_poly := ""
	var removed_variant := ""
	var rebuilt := context.store.create_list()
	for i in range(deck_entries.get_count()):
		var entry := deck_entries.get_node(i)
		if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
			continue
		var entry_id := _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "")
		if removed_index < 0 and entry_id == deck_entry_id:
			removed_index = i
			removed_poly = _payload_string(entry, E.PAYLOAD_ULTRAVIBE_ID, "")
			removed_variant = _payload_string(entry, E.PAYLOAD_VARIANT_ID, "")
			continue
		rebuilt.add(entry)
	if removed_index < 0:
		return GnosisFunctionResult.fail("deckEntryId '%s' not found." % deck_entry_id)

	_set_fb_node(EPHEMERAL_DECK_ENTRIES, rebuilt)
	_sync_deck_length(rebuilt)
	_purge_next_pieces_queue_removing(deck_entry_id)

	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	payload.set_key(E.PAYLOAD_ULTRAVIBE_ID, removed_poly)
	payload.set_key(E.PAYLOAD_VARIANT_ID, removed_variant)
	payload.set_key("removedIndex", removed_index)
	payload.set_key("deckLength", float(rebuilt.get_count()))
	_publish_fact(E.FACT_FALLING_BLOCK_DECK_REMOVE_ENTRY_CONFIRMED, payload)
	_increment_statistic(STAT_DECK_ENTRIES_REMOVED, 1.0)
	return GnosisFunctionResult.ok(payload)

func _handle_get_deck_length() -> GnosisFunctionResult:
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	var count := 0
	if deck_entries.is_valid() and deck_entries.get_type() == GnosisValueType.LIST:
		count = deck_entries.get_count()
	var payload := context.store.create_object()
	payload.set_key("deckLength", float(count))
	return GnosisFunctionResult.ok(payload)

func _handle_set_deck_entry_variant(parameters: GnosisNode) -> GnosisFunctionResult:
	var deck_entry_id := _read_param_string(parameters, E.PAYLOAD_DECK_ENTRY_ID)
	var variant_id := _read_param_string(parameters, E.PAYLOAD_VARIANT_ID)
	if deck_entry_id.is_empty():
		return GnosisFunctionResult.fail("SetDeckEntryVariant requires deckEntryId.")
	if variant_id.is_empty():
		return GnosisFunctionResult.fail("SetDeckEntryVariant requires variantId.")
	variant_id = variant_id.strip_edges().to_lower()
	if not _has_variant_in_config(variant_id):
		return GnosisFunctionResult.fail("Unknown variantId '%s'." % variant_id)

	var deck_updated := false
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if deck_entries.is_valid() and deck_entries.get_type() == GnosisValueType.LIST:
		for i in range(deck_entries.get_count()):
			var entry := deck_entries.get_node(i)
			if entry.is_valid() and entry.get_type() == GnosisValueType.OBJECT and _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "") == deck_entry_id:
				entry.set_node(E.PAYLOAD_VARIANT_ID, variant_id)
				deck_updated = true
				break

	# The deck entry is shared, so refresh the matching preview in every player's queue.
	var queue_updated := 0
	var queues_root := _get_queues_root()
	for player_key in queues_root.get_keys():
		var queue := queues_root.get_node(player_key)
		if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST:
			continue
		for i in range(queue.get_count()):
			var entry := queue.get_node(i)
			if entry.is_valid() and entry.get_type() == GnosisValueType.OBJECT and _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "") == deck_entry_id:
				entry.set_node(E.PAYLOAD_VARIANT_ID, variant_id)
				queue_updated += 1

	var payload := context.store.create_object()
	payload.set_key("success", true)
	payload.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	payload.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	payload.set_key("deckEntryUpdated", deck_updated)
	payload.set_key("nextQueueEntriesUpdated", queue_updated)
	return GnosisFunctionResult.ok(payload)

func _handle_change_negative_chance(parameters: GnosisNode) -> GnosisFunctionResult:
	var delta_node := parameters.get_node("delta") if parameters and parameters.is_valid() else GnosisNode.new(null)
	if not delta_node.is_valid():
		return GnosisFunctionResult.fail("ChangeNegativeUltravibeChance requires int 'delta'.")
	var delta := int(delta_node.value)
	var current := _get_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE, 0)
	var updated := _clamp_negative_chance(current + delta)
	_set_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE, updated)
	var payload := context.store.create_object()
	payload.set_key("previousNegativeUltravibeChance", current)
	payload.set_key("negativeUltravibeChance", updated)
	payload.set_key("deltaApplied", delta)
	return GnosisFunctionResult.ok(payload)

func _handle_duplicate_random_deck_entry() -> GnosisFunctionResult:
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST or deck_entries.get_count() == 0:
		return GnosisFunctionResult.fail("deckEntries is empty.")
	var entry := deck_entries.get_node(_seed_range_int(0, deck_entries.get_count(), 0))
	var ultravibe_id := _payload_string(entry, E.PAYLOAD_ULTRAVIBE_ID, "")
	var variant_id := _payload_string(entry, E.PAYLOAD_VARIANT_ID, "")
	if ultravibe_id.is_empty() or variant_id.is_empty():
		return GnosisFunctionResult.fail("Random deck entry missing ultravibeId or variantId.")
	var args := context.store.create_object()
	args.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	args.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	return _handle_add_deck_entry(args)

func _handle_remove_random_deck_entry() -> GnosisFunctionResult:
	var min_deck_size := maxi(1, _get_fb_int(EPHEMERAL_MIN_DECK_SIZE, 1))
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST:
		return GnosisFunctionResult.fail("deckEntries missing.")
	if deck_entries.get_count() <= min_deck_size:
		return GnosisFunctionResult.fail("Deck must contain more than %d entr(y/ies) to remove one." % min_deck_size)
	var entry := deck_entries.get_node(_seed_range_int(0, deck_entries.get_count(), 0))
	var deck_entry_id := _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "")
	if deck_entry_id.is_empty():
		return GnosisFunctionResult.fail("Random entry had no deckEntryId.")
	var args := context.store.create_object()
	args.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	return _handle_remove_deck_entry(args)

func _handle_draw_piece(parameters: GnosisNode) -> GnosisFunctionResult:
	var candidate_ids: Array[String] = []
	if parameters and parameters.is_valid() and parameters.get_type() == GnosisValueType.OBJECT:
		var ids_node := parameters.get_node("ultravibeIds")
		if ids_node.is_valid() and ids_node.get_type() == GnosisValueType.LIST:
			for i in range(ids_node.get_count()):
				var item := ids_node.get_node(i)
				if item.is_valid() and item.get_type() == GnosisValueType.STRING:
					var id := str(item.value)
					if not id.is_empty():
						candidate_ids.append(id)
	if candidate_ids.is_empty():
		candidate_ids = _get_all_ultravibe_ids_from_config()
	candidate_ids = _filter_ultravibe_ids_for_game_flags(candidate_ids)
	if candidate_ids.is_empty():
		return GnosisFunctionResult.fail("No usable ultravibe candidates found.")

	_ensure_deck_initialized(candidate_ids)
	_set_fb_float(EPHEMERAL_DECK_COUNT, _get_fb_float(EPHEMERAL_DECK_COUNT, 0.0) + 1.0)

	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST or deck_entries.get_count() == 0:
		return GnosisFunctionResult.fail("deckEntries missing/empty in Ephemeral state.")

	var selection := _try_resolve_draw_selection(candidate_ids, deck_entries)
	if selection.is_empty():
		return GnosisFunctionResult.fail("Could not resolve draw selection.")

	var result := context.store.create_object()
	result.set_key(E.PAYLOAD_ULTRAVIBE_ID, selection["ultravibeId"])
	result.set_key(E.PAYLOAD_VARIANT_ID, selection["variantId"])
	result.set_key(E.PAYLOAD_DECK_ENTRY_ID, selection["deckEntryId"])
	result.set_key(E.PAYLOAD_SPAWN_FROM_DECK_ENTRIES, selection["spawnFromDeckEntries"])
	return GnosisFunctionResult.ok(result)

# --- Spawn pipeline ---

func _on_spawn_needed(event: GnosisEvent) -> void:
	if not event or not event.data or not event.data.is_valid():
		return
	if not context.event_bus or not context.store:
		return
	var player_id := _payload_string(event.data, E.PAYLOAD_PLAYER_ID, "")
	if player_id.is_empty():
		return
	var spawn_reason := _payload_string(event.data, E.PAYLOAD_SPAWN_REASON, "")

	_ensure_next_pieces_queue_filled(player_id, spawn_reason)
	var queue := _get_player_queue(player_id)
	if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST or queue.get_count() <= 0:
		_publish_immediate_spawn_ready(player_id, spawn_reason)
		return

	var entry := queue.get_node(0)
	if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
		return
	var ultravibe_id := _payload_string(entry, E.PAYLOAD_ULTRAVIBE_ID, "")
	var variant_id := _payload_string(entry, E.PAYLOAD_VARIANT_ID, "")
	var deck_entry_id := _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "")
	if ultravibe_id.is_empty():
		return
	if variant_id.is_empty():
		variant_id = "blue"
	if deck_entry_id.is_empty():
		deck_entry_id = _generate_next_deck_entry_id()

	# Dequeue index 0 from this player's own queue.
	var new_queue := context.store.create_list()
	for i in range(1, queue.get_count()):
		new_queue.add(queue.get_node(i))
	_set_player_queue(player_id, new_queue)

	_ensure_next_pieces_queue_filled(player_id, spawn_reason)

	var ready := context.store.create_object()
	ready.set_key(E.PAYLOAD_PLAYER_ID, player_id)
	ready.set_key(E.PAYLOAD_SPAWN_REASON, spawn_reason)
	ready.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	ready.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	ready.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	context.event_bus.publish(GnosisEvent.new(E.FACT_FALLING_BLOCK_SPAWN_PIECE_READY, ready, false))
	if context.engine:
		context.engine.commit("fallingBlock")

func _publish_immediate_spawn_ready(player_id: String, spawn_reason: String) -> void:
	var draw := _handle_draw_piece(null)
	if not draw.is_ok or not draw.payload.is_valid():
		return
	var ultravibe_id := _payload_string(draw.payload, E.PAYLOAD_ULTRAVIBE_ID, "")
	var variant_id := _payload_string(draw.payload, E.PAYLOAD_VARIANT_ID, "")
	var deck_entry_id := _payload_string(draw.payload, E.PAYLOAD_DECK_ENTRY_ID, "")
	var spawn_from_deck := _payload_bool(draw.payload, E.PAYLOAD_SPAWN_FROM_DECK_ENTRIES, false)
	if ultravibe_id.is_empty():
		return
	if variant_id.is_empty():
		variant_id = "blue"
	if deck_entry_id.is_empty():
		deck_entry_id = _generate_next_deck_entry_id()

	var request := context.store.create_object()
	request.set_key(E.PAYLOAD_PLAYER_ID, player_id)
	request.set_key(E.PAYLOAD_SPAWN_REASON, spawn_reason)
	request.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	request.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
	request.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	request.set_key(E.PAYLOAD_SPAWN_FROM_DECK_ENTRIES, spawn_from_deck)
	request.set_key(E.PAYLOAD_ULTRAVIBE_BLOCKS_COUNT, float(_read_ultravibe_block_count(ultravibe_id)))
	_attach_spawn_piece_rule_context(request, ultravibe_id, variant_id)
	request.set_key(E.PAYLOAD_ALLOWED, true)
	var final_payload := _publish(E.REQUEST_FALLING_BLOCK_SPAWN_PIECE, request)
	if not _payload_bool(final_payload, E.PAYLOAD_ALLOWED, true):
		return
	var final_poly := _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
	var final_variant := _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, variant_id)
	var final_deck_entry := _payload_string(final_payload, E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
	_refresh_spawn_payload_after_interceptors(final_payload, final_poly, final_variant)
	final_poly = _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, final_poly)
	final_variant = _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, final_variant)

	var ready := context.store.create_object()
	ready.set_key(E.PAYLOAD_PLAYER_ID, player_id)
	ready.set_key(E.PAYLOAD_SPAWN_REASON, spawn_reason)
	ready.set_key(E.PAYLOAD_ULTRAVIBE_ID, final_poly)
	ready.set_key(E.PAYLOAD_VARIANT_ID, final_variant)
	ready.set_key(E.PAYLOAD_DECK_ENTRY_ID, final_deck_entry)
	context.event_bus.publish(GnosisEvent.new(E.FACT_FALLING_BLOCK_SPAWN_PIECE_READY, ready, false))

func _ensure_next_pieces_queue_filled(player_id: String, spawn_reason: String) -> void:
	var queue := _get_player_queue(player_id)
	var remaining := queue.get_count()
	var attempts := 0
	while remaining < NEXT_PIECES_QUEUE_SIZE and attempts < 100:
		attempts += 1
		var draw := _handle_draw_piece(null)
		if not draw.is_ok or not draw.payload.is_valid():
			continue
		var ultravibe_id := _payload_string(draw.payload, E.PAYLOAD_ULTRAVIBE_ID, "")
		var variant_id := _payload_string(draw.payload, E.PAYLOAD_VARIANT_ID, "")
		var deck_entry_id := _payload_string(draw.payload, E.PAYLOAD_DECK_ENTRY_ID, "")
		var spawn_from_deck := _payload_bool(draw.payload, E.PAYLOAD_SPAWN_FROM_DECK_ENTRIES, false)
		if ultravibe_id.is_empty():
			continue
		if variant_id.is_empty():
			variant_id = "blue"
		if deck_entry_id.is_empty():
			deck_entry_id = _generate_next_deck_entry_id()

		var request := context.store.create_object()
		request.set_key(E.PAYLOAD_PLAYER_ID, player_id)
		request.set_key(E.PAYLOAD_SPAWN_REASON, spawn_reason)
		request.set_key(E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
		request.set_key(E.PAYLOAD_VARIANT_ID, variant_id)
		request.set_key(E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
		request.set_key(E.PAYLOAD_SPAWN_FROM_DECK_ENTRIES, spawn_from_deck)
		request.set_key(E.PAYLOAD_ULTRAVIBE_BLOCKS_COUNT, float(_read_ultravibe_block_count(ultravibe_id)))
		_attach_spawn_piece_rule_context(request, ultravibe_id, variant_id)
		request.set_key(E.PAYLOAD_ALLOWED, true)
		var final_payload := _publish(E.REQUEST_FALLING_BLOCK_SPAWN_PIECE, request)
		if not _payload_bool(final_payload, E.PAYLOAD_ALLOWED, true):
			continue
		var final_poly := _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, ultravibe_id)
		var final_variant := _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, variant_id)
		var final_deck_entry := _payload_string(final_payload, E.PAYLOAD_DECK_ENTRY_ID, deck_entry_id)
		_refresh_spawn_payload_after_interceptors(final_payload, final_poly, final_variant)
		final_poly = _payload_string(final_payload, E.PAYLOAD_ULTRAVIBE_ID, final_poly)
		final_variant = _payload_string(final_payload, E.PAYLOAD_VARIANT_ID, final_variant)

		var entry := context.store.create_object()
		entry.set_key(E.PAYLOAD_ULTRAVIBE_ID, final_poly)
		entry.set_key(E.PAYLOAD_VARIANT_ID, final_variant)
		entry.set_key(E.PAYLOAD_DECK_ENTRY_ID, final_deck_entry)
		queue.add(entry)
		remaining += 1

func _purge_next_pieces_queue_removing(deck_entry_id: String) -> void:
	if deck_entry_id.is_empty():
		return
	# The removed deck entry can be queued for any player, so purge every queue.
	var queues_root := _get_queues_root()
	for player_key in queues_root.get_keys():
		var queue := queues_root.get_node(player_key)
		if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST or queue.get_count() == 0:
			continue
		var filtered := context.store.create_list()
		for i in range(queue.get_count()):
			var entry := queue.get_node(i)
			if not entry.is_valid() or entry.get_type() != GnosisValueType.OBJECT:
				filtered.add(entry)
				continue
			if _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "") == deck_entry_id:
				continue
			filtered.add(entry)
		queues_root.set_node(player_key, filtered)

# --- Draw selection ---

func _try_resolve_draw_selection(candidate_ids: Array[String], deck_entries: GnosisNode) -> Dictionary:
	var include_negatives := FallingBlockGameFlags.is_include_negatives(context)
	var negative_only := FallingBlockGameFlags.is_negative_only(context)
	var can_use_negative := include_negatives and FallingBlockGameFlags.is_include_special_ultravibes(context) and _negative_variant_ids.size() > 0

	var use_chance_injection := false
	if can_use_negative and not negative_only:
		var negative_percent := _clamp_negative_chance(_get_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE, 0))
		var roll := _seed_random_float01(1.0)
		use_chance_injection = roll < float(negative_percent) / 100.0

	if can_use_negative and use_chance_injection:
		var poly := _pick_ultravibe_for_negative_injection(candidate_ids)
		if poly.is_empty():
			poly = candidate_ids[_seed_range_int(0, candidate_ids.size(), 0)]
		return {
			"ultravibeId": poly,
			"variantId": _sanitize_variant_for_game_flags(_pick_random_negative_variant_id()),
			"deckEntryId": _generate_next_deck_entry_id(),
			"spawnFromDeckEntries": false,
		}

	var idx := _seed_range_int(0, deck_entries.get_count(), 0)
	var entry := deck_entries.get_node(idx)
	var chosen_poly := _payload_string(entry, "ultravibeId", "")
	var chosen_variant := _payload_string(entry, "variantId", "")
	var chosen_deck_entry := _payload_string(entry, E.PAYLOAD_DECK_ENTRY_ID, "")

	if chosen_poly.is_empty() or chosen_variant.is_empty():
		chosen_poly = candidate_ids[_seed_range_int(0, candidate_ids.size(), 0)]
		chosen_variant = _neutral_variant_ids[_seed_range_int(0, _neutral_variant_ids.size(), 0)] if _neutral_variant_ids.size() > 0 else "blue"

	if can_use_negative and negative_only:
		var neg := _pick_random_negative_variant_id()
		if neg != "":
			chosen_variant = neg
	chosen_variant = _sanitize_variant_for_game_flags(chosen_variant)
	if chosen_deck_entry.is_empty():
		chosen_deck_entry = _generate_next_deck_entry_id()
	return {
		"ultravibeId": chosen_poly,
		"variantId": chosen_variant,
		"deckEntryId": chosen_deck_entry,
		"spawnFromDeckEntries": true,
	}

func _pick_ultravibe_for_negative_injection(candidate_ids: Array[String]) -> String:
	if candidate_ids.is_empty():
		return ""
	if candidate_ids.size() == 1:
		return candidate_ids[0]
	var basic_ids: Array[String] = []
	var abnormal_ids: Array[String] = []
	for id in candidate_ids:
		if id.is_empty():
			continue
		if _read_ultravibe_tags(id).has("basic"):
			basic_ids.append(id)
		else:
			abnormal_ids.append(id)
	var pool: Array[String]
	if basic_ids.is_empty():
		pool = abnormal_ids
	elif abnormal_ids.is_empty():
		pool = basic_ids
	else:
		var abnormal_roll := _seed_range_int(0, 100, 100)
		pool = abnormal_ids if abnormal_roll < NEGATIVE_INJECTION_ABNORMAL_SHAPE_CHANCE_PERCENT else basic_ids
	return pool[_seed_range_int(0, pool.size(), 0)]

func _pick_random_negative_variant_id() -> String:
	if _negative_variant_ids.is_empty():
		return ""
	return _negative_variant_ids[_seed_range_int(0, _negative_variant_ids.size(), 0)]

func _sanitize_variant_for_game_flags(variant_id: String) -> String:
	if variant_id.is_empty() or FallingBlockGameFlags.is_include_special_ultravibes(context):
		return variant_id
	if _neutral_variant_ids.size() > 0:
		return _neutral_variant_ids[_seed_range_int(0, _neutral_variant_ids.size(), 0)]
	return "blue"

func _filter_ultravibe_ids_for_game_flags(ids: Array[String]) -> Array[String]:
	if ids.is_empty() or not FallingBlockGameFlags.is_original_only(context):
		return ids
	var filtered: Array[String] = []
	for id in ids:
		if not id.is_empty() and _read_ultravibe_block_count(id) == FallingBlockGameFlags.ORIGINAL_ONLY_BLOCK_COUNT:
			filtered.append(id)
	return filtered

# --- Deck init ---

func _ensure_deck_initialized(candidate_ids: Array[String]) -> void:
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	var has_deck := deck_entries.is_valid() and deck_entries.get_type() == GnosisValueType.LIST and deck_entries.get_count() > 0

	_neutral_variant_ids = _get_variant_ids_by_tag("neutral")
	if _neutral_variant_ids.is_empty():
		_neutral_variant_ids.append("blue")
	_negative_variant_ids = _get_variant_ids_by_tag("negative")

	if has_deck:
		return

	var basic_ids: Array[String] = []
	for id in candidate_ids:
		if _read_ultravibe_tags(id).has("basic"):
			basic_ids.append(id)
	if basic_ids.is_empty():
		basic_ids = candidate_ids.duplicate()
	basic_ids = _filter_ultravibe_ids_for_game_flags(basic_ids)
	if basic_ids.is_empty():
		return

	var deck_list := context.store.create_list()
	for poly_id in basic_ids:
		var variant_id: String = _neutral_variant_ids[_seed_range_int(0, _neutral_variant_ids.size(), 0)]
		var entry := context.store.create_object()
		entry.set_key("ultravibeId", poly_id)
		entry.set_key("variantId", variant_id)
		entry.set_key(E.PAYLOAD_DECK_ENTRY_ID, _generate_next_deck_entry_id())
		deck_list.add(entry)
	_set_fb_node(EPHEMERAL_DECK_ENTRIES, deck_list)
	_set_fb_float(EPHEMERAL_DECK_COUNT, 0.0)
	_set_fb_int(EPHEMERAL_DECK_LENGTH, deck_list.get_count())

func _ensure_deck_entries_list() -> GnosisNode:
	var deck_entries := _get_fb_node(EPHEMERAL_DECK_ENTRIES)
	if deck_entries.is_valid() and deck_entries.get_type() == GnosisValueType.LIST:
		return deck_entries
	var list := context.store.create_list()
	_set_fb_node(EPHEMERAL_DECK_ENTRIES, list)
	return list

func _sync_deck_length(deck_entries: GnosisNode) -> void:
	if not deck_entries.is_valid() or deck_entries.get_type() != GnosisValueType.LIST:
		return
	var to := deck_entries.get_count()
	if _get_fb_int(EPHEMERAL_DECK_LENGTH, 0) == to:
		return
	_set_fb_int(EPHEMERAL_DECK_LENGTH, to)
	if context.engine:
		context.engine.commit("fallingBlock")

func _generate_next_deck_entry_id() -> String:
	var counter := _get_fb_int(EPHEMERAL_DECK_ENTRY_ID_COUNTER, 0) + 1
	_set_fb_int(EPHEMERAL_DECK_ENTRY_ID_COUNTER, counter)
	return "deck_entry_%d" % counter

# --- Config reads ---

func _config_root() -> GnosisNode:
	return get_node("configuration", true)

func _get_all_ultravibe_ids_from_config() -> Array[String]:
	var ids: Array[String] = []
	var poly_root := _config_root().get_node("ultravibes")
	if not poly_root.is_valid() or poly_root.get_type() != GnosisValueType.OBJECT:
		return ids
	for key in poly_root.get_keys():
		if not str(key).is_empty():
			ids.append(str(key))
	return _filter_ultravibe_ids_for_game_flags(ids)

func _read_ultravibe_block_count(ultravibe_id: String) -> int:
	if ultravibe_id.is_empty():
		return 0
	var poly := _config_root().get_node("ultravibes").get_node(ultravibe_id)
	if not poly.is_valid() or poly.get_type() != GnosisValueType.OBJECT:
		return 0
	return FallingBlockEphemeral.read_int(poly.get_node("blocksCount"), 0)

func _has_ultravibe_in_config(ultravibe_id: String) -> bool:
	if ultravibe_id.is_empty():
		return false
	var poly := _config_root().get_node("ultravibes").get_node(ultravibe_id)
	return poly.is_valid() and poly.get_type() == GnosisValueType.OBJECT

func _has_variant_in_config(variant_id: String) -> bool:
	if variant_id.is_empty():
		return false
	var v := _config_root().get_node("variants").get_node(variant_id.to_lower())
	return v.is_valid() and v.get_type() == GnosisValueType.OBJECT

func _read_ultravibe_tags(ultravibe_id: String) -> PackedStringArray:
	var tags := PackedStringArray()
	if ultravibe_id.is_empty():
		return tags
	var poly := _config_root().get_node("ultravibes").get_node(ultravibe_id)
	if not poly.is_valid() or poly.get_type() != GnosisValueType.OBJECT:
		return tags
	var tags_node := poly.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return tags
	for i in range(tags_node.get_count()):
		var item := tags_node.get_node(i)
		if item.is_valid() and item.get_type() == GnosisValueType.STRING:
			tags.append(str(item.value).to_lower())
	return tags

func _get_variant_ids_by_tag(required_tag: String) -> Array[String]:
	var allowed: Array[String] = []
	if required_tag.is_empty():
		return allowed
	required_tag = required_tag.to_lower()
	var variants_root := _config_root().get_node("variants")
	if not variants_root.is_valid() or variants_root.get_type() != GnosisValueType.OBJECT:
		return allowed
	for key in variants_root.get_keys():
		var variant_id := str(key).to_lower()
		if variant_id == "ghost" or variant_id == "disabled":
			continue
		var variant_node := variants_root.get_node(key)
		if not variant_node.is_valid() or variant_node.get_type() != GnosisValueType.OBJECT:
			continue
		var tags_node := variant_node.get_node("tags")
		if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
			continue
		for i in range(tags_node.get_count()):
			var item := tags_node.get_node(i)
			if item.is_valid() and item.get_type() == GnosisValueType.STRING and str(item.value).to_lower() == required_tag:
				allowed.append(variant_id)
				break
	return allowed

func _get_ultravibe_ids_by_tag(required_tag: String) -> Array[String]:
	var filtered: Array[String] = []
	if required_tag.is_empty():
		return filtered
	required_tag = required_tag.to_lower()
	for id in _get_all_ultravibe_ids_from_config():
		if _read_ultravibe_tags(id).has(required_tag):
			filtered.append(id)
	return filtered

# --- Negative chance clamping ---

func _negative_chance_max_bound() -> int:
	return clampi(_get_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_MAX, DEFAULT_NEGATIVE_ULTRAVIBE_CHANCE_MAX), 0, 100)

func _clamp_negative_chance(percent: int) -> int:
	var max_bound := _negative_chance_max_bound()
	var min_bound := clampi(_get_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE_MIN, 0), 0, max_bound)
	return clampi(percent, min_bound, max_bound)

func _enforce_negative_chance_within_bounds() -> void:
	var current := _get_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE, 0)
	var clamped := _clamp_negative_chance(current)
	if clamped != current:
		_set_fb_int(EPHEMERAL_NEGATIVE_ULTRAVIBE_CHANCE, clamped)

# --- Spawn rule context ---

func _attach_spawn_piece_rule_context(request: GnosisNode, ultravibe_id: String, variant_id: String) -> void:
	var variant_tags := _read_variant_tags(variant_id)
	var poly_tags := _read_ultravibe_tags(ultravibe_id)
	request.set_key(E.PAYLOAD_SPAWN_VARIANT_TAGS, _build_tag_presence(variant_tags))
	request.set_key(E.PAYLOAD_SPAWN_ULTRAVIBE_TAGS, _build_tag_presence(poly_tags))
	var merged := {}
	for t in variant_tags:
		var id := _normalize_tag_key(t)
		if id != "":
			merged[id] = true
	for t in poly_tags:
		var id := _normalize_tag_key(t)
		if id != "":
			merged[id] = true
	var merged_node := context.store.create_value(merged)
	request.set_key(E.PAYLOAD_SPAWN_MERGED_TAGS, merged_node)
	request.set_key(E.PAYLOAD_SPAWN_COLOR_FLAGS, _build_color_flags(merged))

func _refresh_spawn_payload_after_interceptors(payload: GnosisNode, final_poly: String, final_variant: String) -> void:
	if not payload.is_valid() or final_poly.is_empty():
		return
	if final_variant.is_empty():
		final_variant = "blue"
	_apply_boon_spawn_conversions(payload)
	final_poly = _payload_string(payload, E.PAYLOAD_ULTRAVIBE_ID, final_poly)
	final_variant = _payload_string(payload, E.PAYLOAD_VARIANT_ID, final_variant)
	payload.set_key(E.PAYLOAD_ULTRAVIBE_BLOCKS_COUNT, float(_read_ultravibe_block_count(final_poly)))
	_attach_spawn_piece_rule_context(payload, final_poly, final_variant)

func _apply_boon_spawn_conversions(payload: GnosisNode) -> void:
	if not context.engine:
		return
	var fb_service = context.engine.get_service("FallingBlock")
	if fb_service and fb_service.has_method("apply_equipped_boon_spawn_conversions_to_payload"):
		fb_service.apply_equipped_boon_spawn_conversions_to_payload(payload)

func _read_variant_tags(variant_id: String) -> PackedStringArray:
	var tags := PackedStringArray()
	if variant_id.is_empty():
		return tags
	var v := _config_root().get_node("variants").get_node(variant_id.to_lower())
	if not v.is_valid() or v.get_type() != GnosisValueType.OBJECT:
		return tags
	var tags_node := v.get_node("tags")
	if not tags_node.is_valid() or tags_node.get_type() != GnosisValueType.LIST:
		return tags
	for i in range(tags_node.get_count()):
		var item := tags_node.get_node(i)
		if item.is_valid() and item.get_type() == GnosisValueType.STRING:
			tags.append(str(item.value))
	return tags

func _normalize_tag_key(raw: String) -> String:
	var t := raw.strip_edges().to_lower()
	if t.is_empty() or t == "total" or t == "tags":
		return ""
	return t

func _build_tag_presence(tags) -> GnosisNode:
	var d := {}
	for t in tags:
		var id := _normalize_tag_key(t)
		if id != "":
			d[id] = true
	return context.store.create_value(d)

func _build_color_flags(merged_tags: Dictionary) -> GnosisNode:
	var d := {}
	for suffix in ["red", "orange", "green", "blue"]:
		if merged_tags.has("color_" + suffix):
			d[suffix] = true
	return context.store.create_value(d)

# --- Event / payload helpers ---

func _publish(event_id: String, payload: GnosisNode) -> GnosisNode:
	var result := context.event_bus.publish(GnosisEvent.new(event_id, payload, false))
	if result and result.final_event and result.final_event.data:
		return result.final_event.data
	return payload

func _publish_fact(fact_id: String, payload: GnosisNode) -> void:
	if context.event_bus and not fact_id.is_empty():
		context.event_bus.publish(GnosisEvent.new(fact_id, payload, false))

func _increment_statistic(key: String, delta: float) -> void:
	var params := context.store.create_object()
	params.set_key("persistent", false)
	params.set_key("key", key)
	params.set_key("delta", delta)
	call_service("Statistic", "IncrementCounter", params)

func _read_param_string(parameters: GnosisNode, key: String) -> String:
	if parameters == null or not parameters.is_valid():
		return ""
	var node := parameters.get_node(key)
	if node.is_valid() and node.get_type() == GnosisValueType.STRING:
		return str(node.value)
	return ""

func _payload_string(payload: GnosisNode, key: String, default_value: String) -> String:
	if payload == null or not payload.is_valid():
		return default_value
	var n := payload.get_node(key)
	if n.is_valid() and n.get_type() == GnosisValueType.STRING:
		return str(n.value)
	return default_value

func _payload_bool(payload: GnosisNode, key: String, default_value: bool) -> bool:
	if payload == null or not payload.is_valid():
		return default_value
	var n := payload.get_node(key)
	if n.is_valid() and n.get_type() == GnosisValueType.BOOL:
		return bool(n.value)
	return default_value
