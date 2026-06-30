class_name Match3Service
extends GnosisService

## UltraVibe match-3 run authority (initial Godot port of Match3GnosisService).

const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Match3GameplayScript = preload("res://game/match3/core/match3_gameplay.gd")
const Match3BoardLayoutScript = preload("res://game/match3/core/match3_board_layout.gd")

const Events = Match3EventsScript
const Models = Match3ModelsScript

const BASE_MOVES_LIMIT := 10
const BASE_SCORE_TO_WIN := 1000
const BASE_COLOR_LIMIT := 6
const DEFAULT_BOARD_ID := "grid9x9_bm"
const BOARDS_INDEX_PATH := "res://data/Boards/index.json"
const DEFAULT_ROUNDS_PER_FLOOR := 3
const DEFAULT_SHUFFLES_PER_ROUND := 2
const COLOR_LIMIT_PLAYABLE_SMALL := 42
const COLOR_LIMIT_PLAYABLE_MEDIUM := 63

var _gameplay = Match3GameplayScript.new()
var _item_points: Dictionary = {}
var _current_round := 1
var _active_board_id := ""
var _active_level_id := "normal"
var _current_floor := 1
var _round_in_floor := 1
var _active_stage_type := "normal"
var _manual_shuffles_remaining := 0
var _boss_level_ids_cache: Array[String] = []
var _board_pools_loaded := false
var _normal_board_pool_ids: Array[String] = []
var _advanced_board_pool_ids: Array[String] = []
var _boss_board_pool_ids: Array[String] = []
var _board_difficulty_by_id: Dictionary = {}

var _move_subscription: RefCounted = null
var _reset_subscription: RefCounted = null
var _begin_level_subscription: RefCounted = null


func _init() -> void:
	super._init("Match3", GnosisLifetime.TRANSIENT)


func on_initialize() -> void:
	_refresh_item_catalog()
	_load_board_pools()
	_hydrate_runtime_from_store()
	_gameplay.status = Models.STATUS_LEVEL_SELECT_PANEL
	_publish_ephemeral_state()
	if context and context.event_bus:
		_move_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_MOVE, _on_move_requested, 0)
		_reset_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_RESET, _on_reset_requested, 0)
		_begin_level_subscription = context.event_bus.subscribe(
			Events.REQUEST_MATCH3_BEGIN_LEVEL, _on_begin_level_requested, 0)
	_publish_fact(Events.FACT_MATCH3_EPHEMERAL_SERVICE_STARTED)


func on_shutdown() -> void:
	_publish_fact(Events.FACT_MATCH3_EPHEMERAL_SERVICE_STOPPED)
	_dispose_subscription(_move_subscription)
	_dispose_subscription(_reset_subscription)
	_dispose_subscription(_begin_level_subscription)
	_move_subscription = null
	_reset_subscription = null
	_begin_level_subscription = null


func get_functions() -> Array:
	return ["PlayLevel", "TryUseShuffle"]


func invoke_function(name: String, parameters: GnosisNode) -> Variant:
	match name:
		"PlayLevel":
			var level := 1
			if parameters != null and parameters.is_valid():
				level = maxi(1, _node_int(parameters, "levelNumber", 1))
			_begin_level(level)
			return GnosisFunctionResult.ok(context.store.create_value(true))
		"TryUseShuffle":
			return GnosisFunctionResult.fail("Shuffle not implemented yet.")
	return GnosisFunctionResult.fail("Unknown Match3 function '%s'." % name)


func get_gameplay():
	return _gameplay


func get_current_status() -> int:
	return _gameplay.status


func get_current_round() -> int:
	return _current_round


func get_current_floor() -> int:
	return _current_floor


func get_round_in_floor() -> int:
	return _round_in_floor


func get_rounds_per_floor() -> int:
	return DEFAULT_ROUNDS_PER_FLOOR


func get_shuffles_remaining() -> int:
	return _manual_shuffles_remaining


func is_boss_round() -> bool:
	return _active_stage_type == "boss"


## Run currency. Not modeled in the Godot port yet (Unity sources this from the
## match3 ephemeral money currency); returns 0 until the economy is ported.
func get_money() -> int:
	return 0


## Step scoring for the last resolved move (points x multi shown on the HUD).
## Not modeled in the Godot port yet; returns 0 until scoring steps are ported.
func get_step_points() -> int:
	return 0


func get_step_multi() -> int:
	return 0


## Resolves the display metadata for the current round's level/boss profile from
## the `levels` catalog (name, description, token letter, accent colors, reward).
func get_active_level_meta() -> Dictionary:
	var result := {
		"id": _active_level_id,
		"nameKey": "",
		"descriptionKey": "",
		"startingLetter": "",
		"backgroundColor": "",
		"textColor": "",
		"rewardAmount": 0,
		"isBoss": _active_stage_type == "boss",
	}
	var config := get_node("configuration", true)
	if not config.is_valid():
		return result
	var levels := config.get_node("levels")
	if not levels.is_valid():
		return result
	var entry := levels.get_node(_active_level_id)
	if not entry.is_valid():
		return result
	var meta := entry.get_node("metadata")
	var props := entry.get_node("properties")
	result["nameKey"] = _node_str(meta, "nameKey")
	result["descriptionKey"] = _node_str(meta, "descriptionKey")
	result["startingLetter"] = _node_str(meta, "startingLetter")
	result["backgroundColor"] = _node_str(meta, "backgroundColor")
	result["textColor"] = _node_str(meta, "textColor")
	result["rewardAmount"] = _node_int(props, "rewardAmount", 0)
	return result


func is_board_input_allowed() -> bool:
	return _gameplay.status == Models.STATUS_PLAYING


func handle_run_started() -> void:
	_begin_level(1)


func _on_begin_level_requested(event: GnosisEvent) -> void:
	var level := 1
	if event != null and event.data.is_valid():
		level = maxi(1, _node_int(event.data, Events.PAYLOAD_LEVEL_NUMBER, 1))
	_begin_level(level)


func _on_reset_requested(_event: GnosisEvent) -> void:
	_begin_level(_current_round)


func _on_move_requested(event: GnosisEvent) -> void:
	if not is_board_input_allowed() or context == null:
		return
	var x1 := -1
	var y1 := -1
	var x2 := -1
	var y2 := -1
	if event != null and event.data.is_valid():
		x1 = _node_int(event.data, "x1", -1)
		y1 = _node_int(event.data, "y1", -1)
		x2 = _node_int(event.data, "x2", -1)
		y2 = _node_int(event.data, "y2", -1)
	if x1 < 0 or y1 < 0 or x2 < 0 or y2 < 0:
		return
	var a = Models.TileCoord.new(x1, y1)
	var b = Models.TileCoord.new(x2, y2)
	var results := _gameplay.process_move(a, b, _item_points)
	_publish_ephemeral_state()
	_publish_board_changed()
	if not results.is_empty():
		_publish_move_resolved(results)
	if _gameplay.status != Models.STATUS_PLAYING:
		_publish_status_changed()


func _begin_level(level_number: int) -> void:
	_current_round = maxi(1, level_number)
	var seed_svc = context.engine.get_service("Seed") if context and context.engine else null
	if seed_svc and seed_svc.has_method("get_run_seed"):
		_gameplay.configure_rng(int(seed_svc.get_run_seed()))
	var setup := _resolve_round_setup(_current_round)
	var layout = _load_board_layout(str(setup.get("board_id", DEFAULT_BOARD_ID)))
	if layout == null:
		push_warning("Match3Service: board '%s' missing; using empty 8x8." % DEFAULT_BOARD_ID)
		layout = Match3BoardLayoutScript.new()
		layout.id = "fallback"
		layout.width = 8
		layout.height = 8
	_active_board_id = str(setup.get("board_id", layout.id))
	_active_level_id = str(setup.get("level_id", "normal"))
	_current_floor = int(setup.get("floor", 1))
	_round_in_floor = int(setup.get("round_in_floor", 1))
	_active_stage_type = str(setup.get("stage_type", "normal"))
	_manual_shuffles_remaining = int(setup.get("shuffles", DEFAULT_SHUFFLES_PER_ROUND))
	_gameplay.load_level(
		layout,
		int(setup.get("target_score", BASE_SCORE_TO_WIN)),
		int(setup.get("moves", BASE_MOVES_LIMIT)),
		int(setup.get("color_limit", BASE_COLOR_LIMIT)),
		_item_points
	)
	_publish_ephemeral_state()
	_publish_board_reset()


func _load_board_layout(board_id: String):
	var config := get_node("configuration", true)
	if not config.is_valid():
		return null
	var boards := config.get_node("match3Boards")
	if not boards.is_valid():
		return null
	var entry := boards.get_node(board_id)
	if not entry.is_valid():
		return null
	var data: Variant = entry.value
	if data is Dictionary:
		var layout = Match3BoardLayoutScript.from_json(data)
		if layout.id.is_empty():
			layout.id = board_id
		return layout
	return null


func _resolve_round_setup(round_number: int) -> Dictionary:
	_load_board_pools()
	var round := maxi(1, round_number)
	var rounds_per_floor := DEFAULT_ROUNDS_PER_FLOOR
	var floor := int((round - 1) / rounds_per_floor) + 1
	var round_in_floor := int((round - 1) % rounds_per_floor) + 1
	var stage_type := "boss" if round_in_floor == rounds_per_floor else ("advanced" if round_in_floor == 2 else "normal")
	var board_id := _pick_board_id_for_stage(stage_type, floor)
	var layout = _load_board_layout(board_id)
	if layout == null:
		layout = _load_board_layout(DEFAULT_BOARD_ID)
		board_id = DEFAULT_BOARD_ID
	var color_limit := _resolve_adaptive_color_limit(layout)
	return {
		"round": round,
		"floor": floor,
		"round_in_floor": round_in_floor,
		"stage_type": stage_type,
		"board_id": board_id,
		"level_id": _resolve_level_id_for_stage(stage_type, floor),
		"target_score": _resolve_target_score(round, stage_type),
		"moves": _resolve_moves_limit(round, stage_type),
		"shuffles": DEFAULT_SHUFFLES_PER_ROUND,
		"color_limit": color_limit,
	}


## Picks which level/boss profile backs the current round. Boss stages cycle
## through the boss-tagged entries in the `levels` catalog by floor; normal and
## advanced stages use their generic level profiles.
func _resolve_level_id_for_stage(stage_type: String, floor: int) -> String:
	if stage_type == "boss":
		var bosses := _get_boss_level_ids()
		if bosses.is_empty():
			return "normal"
		return bosses[(maxi(1, floor) - 1) % bosses.size()]
	if stage_type == "advanced":
		return "advanced"
	return "normal"


func _get_boss_level_ids() -> Array[String]:
	if not _boss_level_ids_cache.is_empty():
		return _boss_level_ids_cache
	var config := get_node("configuration", true)
	if not config.is_valid():
		return _boss_level_ids_cache
	var levels := config.get_node("levels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		return _boss_level_ids_cache
	for level_id in levels.get_keys():
		var entry := levels.get_node(level_id)
		if not entry.is_valid():
			continue
		if _level_has_tag(entry.get_node("metadata"), "boss"):
			_boss_level_ids_cache.append(str(level_id))
	_boss_level_ids_cache.sort()
	return _boss_level_ids_cache


func _level_has_tag(meta: GnosisNode, tag: String) -> bool:
	if meta == null or not meta.is_valid():
		return false
	var tags := meta.get_node("tags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	for i in range(tags.get_count()):
		var t := tags.get_node(i)
		if t.is_valid() and str(t.value) == tag:
			return true
	return false


func _load_board_pools() -> void:
	if _board_pools_loaded:
		return
	_board_pools_loaded = true
	_normal_board_pool_ids.clear()
	_advanced_board_pool_ids.clear()
	_boss_board_pool_ids.clear()
	_board_difficulty_by_id.clear()
	if not FileAccess.file_exists(BOARDS_INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BOARDS_INDEX_PATH))
	if not (parsed is Dictionary):
		return
	var entries: Variant = parsed.get("match3Boards", [])
	if not (entries is Array):
		return
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var board_id := str(entry.get("id", "")).strip_edges()
		if board_id.is_empty():
			continue
		var difficulty := _infer_board_difficulty(entry)
		_board_difficulty_by_id[board_id] = difficulty
		match difficulty:
			"easy":
				_add_unique(_normal_board_pool_ids, board_id)
			"normal":
				_add_unique(_normal_board_pool_ids, board_id)
				_add_unique(_advanced_board_pool_ids, board_id)
			"hard", "extreme", "boss":
				_add_unique(_boss_board_pool_ids, board_id)
	_normal_board_pool_ids.sort()
	_advanced_board_pool_ids.sort()
	_boss_board_pool_ids.sort()


func _infer_board_difficulty(entry: Dictionary) -> String:
	var difficulty := str(entry.get("difficulty", "")).strip_edges().to_lower()
	if not difficulty.is_empty():
		return difficulty
	var path := str(entry.get("path", "")).strip_edges().to_lower()
	if path.begins_with("easy/"):
		return "easy"
	if path.begins_with("normal/"):
		return "normal"
	if path.begins_with("hard/"):
		return "hard"
	if path.begins_with("extreme/"):
		return "extreme"
	return ""


func _pick_board_id_for_stage(stage_type: String, floor: int) -> String:
	var pool: Array[String] = _normal_board_pool_ids
	if stage_type == "advanced":
		pool = _advanced_board_pool_ids
	elif stage_type == "boss":
		pool = _boss_board_pool_ids
	var picked := _pick_from_pool(pool, floor, stage_type)
	if not picked.is_empty():
		return picked
	return DEFAULT_BOARD_ID


func _pick_from_pool(pool: Array[String], floor: int, stage_type: String) -> String:
	if pool.is_empty():
		return ""
	var offset := 0
	if stage_type == "advanced":
		offset = 1
	elif stage_type == "boss":
		offset = 2
	var index := _compute_deterministic_index(pool.size(), floor, stage_type, offset)
	return pool[index]


func _compute_deterministic_index(count: int, floor: int, stage_type: String, offset: int) -> int:
	if count <= 1:
		return 0
	var acc := floor * 1103515245 + offset * 12345
	for i in stage_type.length():
		acc += stage_type.unicode_at(i) * (i + 17)
	return absi(acc) % count


func _resolve_target_score(round_number: int, stage_type: String) -> int:
	var target := BASE_SCORE_TO_WIN + (maxi(1, round_number) - 1) * 350
	if stage_type == "advanced":
		target = int(roundf(float(target) * 1.2))
	elif stage_type == "boss":
		target = int(roundf(float(target) * 1.5))
	return maxi(1, target)


func _resolve_moves_limit(round: int, stage_type: String) -> int:
	var moves := BASE_MOVES_LIMIT + int((maxi(1, round) - 1) / 3)
	if stage_type == "boss":
		moves += 2
	return maxi(1, moves)


func _resolve_adaptive_color_limit(layout) -> int:
	var playable := _count_playable_board_squares(layout)
	var target := 6
	if playable <= COLOR_LIMIT_PLAYABLE_SMALL:
		target = 4
	elif playable <= COLOR_LIMIT_PLAYABLE_MEDIUM:
		target = 5
	return mini(target, _item_points.size()) if not _item_points.is_empty() else target


func _count_playable_board_squares(layout) -> int:
	if layout == null:
		return 0
	var count := 0
	for sq in layout.squares:
		if sq.slot_type != Models.SLOT_NONE:
			count += 1
	return count


func _add_unique(ids: Array[String], board_id: String) -> void:
	if board_id.is_empty() or ids.has(board_id):
		return
	ids.append(board_id)


func _refresh_item_catalog() -> void:
	_item_points.clear()
	var config := get_node("configuration", true)
	if not config.is_valid():
		return
	var items := config.get_node("items")
	if not items.is_valid() or items.get_type() != GnosisValueType.OBJECT:
		return
	for item_id in items.get_keys():
		var entry := items.get_node(item_id)
		if not entry.is_valid():
			continue
		var props := entry.get_node("properties")
		var points = Models.DEFAULT_ITEM_POINTS
		if props.is_valid():
			points = _node_int(props, "basePoints", Models.DEFAULT_ITEM_POINTS)
		_item_points[str(item_id)] = points


func _hydrate_runtime_from_store() -> void:
	var m3 := get_node("match3", false)
	if not m3.is_valid():
		return
	_gameplay.current_score = _node_int(m3, "currentScore", 0)
	_gameplay.target_score = _node_int(m3, "targetScore", BASE_SCORE_TO_WIN)
	_gameplay.current_moves = _node_int(m3, "currentMoves", BASE_MOVES_LIMIT)
	_current_round = _node_int(m3, "currentRound", 1)
	_gameplay.status = _node_int(m3, "gameStatus", Models.STATUS_LEVEL_SELECT_PANEL)


func _publish_ephemeral_state() -> void:
	if context == null or context.store == null:
		return
	var m3 := get_node("match3", false)
	if not m3.is_valid() or m3.get_type() != GnosisValueType.OBJECT:
		m3 = context.store.create_object()
		set_node("match3", m3, false)
	m3.set_key("currentScore", _gameplay.current_score)
	m3.set_key("targetScore", _gameplay.target_score)
	m3.set_key("currentMoves", _gameplay.current_moves)
	m3.set_key("currentRound", _current_round)
	m3.set_key("currentFloor", _current_floor)
	m3.set_key("roundInFloor", _round_in_floor)
	m3.set_key("stageType", _active_stage_type)
	m3.set_key("gameStatus", _gameplay.status)
	m3.set_key("boardId", _active_board_id)
	m3.set_key("levelId", _active_level_id)
	m3.set_key("width", _gameplay.width)
	m3.set_key("height", _gameplay.height)
	m3.set_key("colorLimit", _gameplay.palette.size())
	m3.set_key("currentShuffles", _manual_shuffles_remaining)
	if context.engine:
		var changed_paths: Array[String] = ["Ephemeral.match3"]
		context.engine.commit("match3", changed_paths)


func _publish_board_reset() -> void:
	_publish_fact(Events.FACT_MATCH3_BOARD_RESET, _build_board_payload())


func _publish_board_changed() -> void:
	_publish_fact(Events.FACT_MATCH3_BOARD_CHANGED, _build_board_payload())


func _publish_move_resolved(results: Array) -> void:
	if context == null or context.store == null:
		return
	var payload := context.store.create_object()
	payload.set_key("stepCount", results.size())
	payload.set_key("finalScoreGain", _gameplay.current_score)
	_publish_fact(Events.FACT_MATCH3_MOVE_RESOLVED, payload)


func _publish_status_changed() -> void:
	if context == null or context.store == null:
		return
	var payload := context.store.create_object()
	payload.set_key(Events.PAYLOAD_GAME_STATUS, _gameplay.status)
	_publish_fact(Events.FACT_MATCH3_STATUS_CHANGED, payload)


func _build_board_payload() -> GnosisNode:
	var payload := context.store.create_object()
	payload.set_key(Events.PAYLOAD_WIDTH, _gameplay.width)
	payload.set_key(Events.PAYLOAD_HEIGHT, _gameplay.height)
	payload.set_key(Events.PAYLOAD_SCORE, _gameplay.current_score)
	payload.set_key(Events.PAYLOAD_SCORE_TO_WIN, _gameplay.target_score)
	payload.set_key(Events.PAYLOAD_CURRENT_MOVES, _gameplay.current_moves)
	var tiles := context.store.create_list()
	for y in _gameplay.height:
		for x in _gameplay.width:
			var tile = _gameplay.get_tile(x, y)
			var tile_node = context.store.create_object()
			tile_node.set_key("x", x)
			tile_node.set_key("y", y)
			tile_node.set_key("itemId", tile.item_id if tile else "")
			tile_node.set_key("slotType", tile.slot_type if tile else Models.SLOT_NONE)
			tiles.add(tile_node)
	payload.set_node(Events.PAYLOAD_TILES, tiles)
	return payload


func _publish_fact(event_id: String, payload: GnosisNode = null) -> void:
	if context == null or context.event_bus == null:
		return
	if payload == null and context.store:
		payload = context.store.create_object()
	context.event_bus.publish(GnosisEvent.new(event_id, payload, false))


func _dispose_subscription(sub: RefCounted) -> void:
	if sub and sub.has_method("dispose"):
		sub.dispose()


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)


func _node_str(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)
