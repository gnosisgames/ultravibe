class_name Match3Dispatcher
extends Control

## Board view + swipe input. Gem motion/clear FX follow templates/match3
## (elastic land, sparkle pops, scale-to-zero clears).

const GROUP := "match3_dispatcher"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const SparklesScene = preload("res://game/match3/view/match3_sparkles.tscn")
const BoardFloatJuiceScript = preload("res://game/match3/view/match3_board_float_juice.gd")
const Match3ScoreFloatingDisplayText = preload("res://game/match3/view/match3_score_floating_display_text.gd")
const Match3FloorSpritesScript = preload("res://game/match3/view/match3_floor_sprites.gd")
const Events = Match3EventsScript

const ITEM_COLORS := {
	"orange": Color(0.98, 0.62, 0.15),
	"red": Color(0.92, 0.28, 0.24),
	"purple": Color(0.55, 0.36, 0.78),
	"blue": Color(0.28, 0.55, 0.92),
	"green": Color(0.32, 0.78, 0.42),
	"pink": Color(0.95, 0.45, 0.72),
}

const ITEM_TEXTURES := {
	"orange": "res://assets/blocks/joy.png",
	"red": "res://assets/blocks/anger.png",
	"purple": "res://assets/blocks/sadness.png",
	"blue": "res://assets/blocks/fear.png",
	"green": "res://assets/blocks/disgust.png",
	"pink": "res://assets/blocks/love.png",
}

## Template match-3 motion timings (templates/match3/scripts/main.gd + tile.gd).
const MOVE_DURATION := 0.3
const DESTROY_DURATION := 0.2
const STEP_PAUSE := 0.3
const INTER_STEP_DELAY := 0.0
const CELL_GAP_RATIO := 0.06
const ITEM_INSET_RATIO := 0.0
const MIN_DRAG_PX := 24.0
const DRAG_FOLLOW_RATIO := 0.42
const DRAG_HIGHLIGHT := Color(1.15, 1.15, 1.15, 1.0)

const SFX_SWAP := "res://assets/match3/sounds/tile-swap.ogg"
const SFX_MATCH := "res://assets/match3/sounds/tile-match.ogg"
const SFX_LAND := "res://assets/match3/sounds/tile-land.ogg"

var cell_size: Vector2 = Vector2(56, 56)
var cell_gap: float = 4.0

var _service = null
var _adapter = null
var _width: int = 0
var _height: int = 0
var _cells: Array = []
var _items: Dictionary = {}
var _textures: Dictionary = {}
var _origin: Vector2 = Vector2.ZERO
var _busy: bool = false
var _optimistic_swap_done: bool = false
var _active_swap_tween: Tween = null
var _combo_count: int = 0
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_available: Array[AudioStreamPlayer] = []

var _dragging: bool = false
var _drag_committed: bool = false
var _drag_start_cell: Vector2i = Vector2i(-1, -1)
var _drag_start_pos: Vector2 = Vector2.ZERO
var _drag_node: Control = null
var _drag_rest_pos: Vector2 = Vector2.ZERO
var _drag_rest_z: int = 0
var _hover_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	_preload_textures()
	_init_sfx_pool()
	resized.connect(_update_layout)
	set_process(false)
	call_deferred("_resolve_adapter")


func is_busy() -> bool:
	return _busy


func bind_service(service) -> void:
	_service = service
	_sync_from_service()


func refresh_hud() -> void:
	var hud = _find_hud()
	if hud and hud.has_method("refresh_from_service"):
		hud.refresh_from_service(_service)


func _find_hud():
	var node: Node = self
	while node:
		if node.get_script() and str(node.get_script().resource_path).ends_with("match3_hud.gd"):
			return node
		node = node.get_parent()
	return null


func apply_board_payload(payload: GnosisNode) -> void:
	if _busy:
		return
	if payload == null or not payload.is_valid():
		_sync_from_service()
		return
	_width = _node_int(payload, Events.PAYLOAD_WIDTH, _width)
	_height = _node_int(payload, Events.PAYLOAD_HEIGHT, _height)
	var cells: Array = []
	var tiles := payload.get_node(Events.PAYLOAD_TILES)
	if tiles.is_valid() and tiles.get_type() == GnosisValueType.LIST:
		for i in tiles.get_count():
			var tile_node = tiles.get_node(i)
			if not tile_node.is_valid():
				continue
			cells.append({
				"x": _node_int(tile_node, "x", 0),
				"y": _node_int(tile_node, "y", 0),
				"itemId": _node_string(tile_node, "itemId", ""),
				"slotType": _node_int(tile_node, "slotType", Match3ModelsScript.SLOT_ACTIVE),
				"cellFloorTypeId": _node_string(tile_node, "cellFloorTypeId", ""),
			})
	_rebuild_from_cells(cells)


func _sync_from_service() -> void:
	if _service == null:
		return
	var gameplay = _service.get_gameplay()
	_width = gameplay.width
	_height = gameplay.height
	var cells: Array = []
	for y in _height:
		for x in _width:
			var tile = gameplay.get_tile(x, y)
			cells.append({
				"x": x,
				"y": y,
				"itemId": tile.item_id if tile else "",
				"slotType": tile.slot_type if tile else Match3ModelsScript.SLOT_NONE,
				"cellFloorTypeId": tile.cell_floor_type_id if tile else "",
			})
	_rebuild_from_cells(cells)


func _rebuild_from_cells(cells: Array) -> void:
	_cancel_drag()
	_cells = cells
	_clear_items()
	_update_layout()
	for cell in cells:
		var item_id := str(cell.get("itemId", ""))
		if item_id.is_empty():
			continue
		var coord := Vector2i(int(cell.get("x", 0)), int(cell.get("y", 0)))
		var node := _make_item_node(item_id)
		_items[_key(coord.x, coord.y)] = node
		_place_node(node, coord.x, coord.y)
	queue_redraw()
	refresh_hud()


# --- Move sequence animation -------------------------------------------------

func play_move_sequence(payload: GnosisNode) -> void:
	_busy = true
	_combo_count = 0
	var a := Vector2i(-1, -1)
	var b := Vector2i(-1, -1)
	var success := false
	if payload != null and payload.is_valid():
		var swap := payload.get_node("swap")
		if swap.is_valid():
			a = Vector2i(_node_int(swap, "x1", -1), _node_int(swap, "y1", -1))
			b = Vector2i(_node_int(swap, "x2", -1), _node_int(swap, "y2", -1))
		success = _node_bool(payload, "success", false)

	if a.x >= 0 and b.x >= 0:
		if _optimistic_swap_done:
			_optimistic_swap_done = false
			await _await_active_swap()
		else:
			await _animate_swap(a, b)

	if success:
		var steps := payload.get_node("steps")
		if steps.is_valid() and steps.get_type() == GnosisValueType.LIST:
			for i in steps.get_count():
				await _animate_step(steps.get_node(i))
				if INTER_STEP_DELAY > 0.0:
					await _wait(INTER_STEP_DELAY)
		var finalize_steps := payload.get_node("cellFloorFinalizeSteps")
		if finalize_steps.is_valid() and finalize_steps.get_type() == GnosisValueType.LIST:
			await _animate_cell_floor_finalize_steps(finalize_steps)
	elif a.x >= 0 and b.x >= 0:
		_play_sfx(SFX_SWAP, false, 2.0, 0.3)
		await _animate_swap(a, b)

	_busy = false
	_sync_cell_floors_from_service()
	refresh_hud()
	if _adapter and _adapter.has_method("on_move_sequence_finished"):
		_adapter.on_move_sequence_finished()


func play_shuffle_sequence(payload: GnosisNode) -> void:
	_busy = true
	_cancel_drag()
	refresh_hud()
	var matched := payload.get_node("matched") if payload != null and payload.is_valid() else null
	var spawns := payload.get_node("spawns") if payload != null and payload.is_valid() else null
	if matched != null and matched.is_valid() and matched.get_type() == GnosisValueType.LIST and matched.get_count() > 0:
		await _animate_destroy(matched, null, false, false)
	if spawns != null and spawns.is_valid() and spawns.get_type() == GnosisValueType.LIST and spawns.get_count() > 0:
		await _animate_spawns(spawns)
	else:
		_sync_from_service()
	_busy = false
	refresh_hud()


func _animate_step(step: GnosisNode) -> void:
	if step == null or not step.is_valid():
		return
	await _animate_destroy(step.get_node("matched"), step.get_node("contributions"), true, true, step)
	_apply_floor_cells_cleared(step)
	await _animate_moves(step.get_node("movements"))
	await _animate_spawns(step.get_node("spawns"))


func _apply_floor_cells_cleared(step: GnosisNode) -> void:
	if step == null or not step.is_valid():
		return
	var cleared := step.get_node("floorCellsCleared")
	if not cleared.is_valid() or cleared.get_type() != GnosisValueType.LIST:
		return
	for i in cleared.get_count():
		var c = cleared.get_node(i)
		if not c.is_valid():
			continue
		var x := _node_int(c, "x", -1)
		var y := _node_int(c, "y", -1)
		if x < 0 or y < 0:
			continue
		for cell in _cells:
			if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
				cell["cellFloorTypeId"] = ""
				break
	queue_redraw()


func _animate_cell_floor_finalize_steps(steps: GnosisNode) -> void:
	for i in steps.get_count():
		var step = steps.get_node(i)
		if not step.is_valid():
			continue
		var x := _node_int(step, "x", -1)
		var y := _node_int(step, "y", -1)
		if x < 0 or y < 0:
			continue
		var anchor := _item_position(x, y) + cell_size * 0.5
		_pulse_floor_cell(x, y)
		var multi_delta := _node_int(step, "multiDelta", 0)
		var display := _node_string(step, "multiDisplayText", "")
		if display.is_empty() and multi_delta > 0:
			display = Match3ScoreFloatingDisplayText.build_multi_add(multi_delta)
		if not display.is_empty():
			BoardFloatJuiceScript.spawn_labeled_popup(
				self,
				anchor,
				display,
				BoardFloatJuiceScript.COLOR_MULTI,
				0.0
			)
		await _wait(0.18)


func _pulse_floor_cell(x: int, y: int) -> void:
	var rect := _cell_rect(x, y)
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.92, 0.45, 0.55)
	flash.position = rect.position
	flash.size = rect.size
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tw := create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.22)
	tw.finished.connect(func() -> void:
		if is_instance_valid(flash):
			flash.queue_free()
	)


func _await_active_swap() -> void:
	if _active_swap_tween and _active_swap_tween.is_running():
		await _active_swap_tween.finished
	else:
		await _wait(MOVE_DURATION)


func _animate_swap(a: Vector2i, b: Vector2i) -> void:
	_kill_swap_tween()
	var ka := _key(a.x, a.y)
	var kb := _key(b.x, b.y)
	var na = _items.get(ka, null)
	var nb = _items.get(kb, null)
	if na == null or nb == null:
		return
	_items[ka] = nb
	_items[kb] = na
	nb.set_meta("cell", a)
	na.set_meta("cell", b)
	var pos_a := _item_position(a.x, a.y)
	var pos_b := _item_position(b.x, b.y)
	nb.set_meta("rest_position", pos_a)
	na.set_meta("rest_position", pos_b)
	_reset_item_visual(na)
	_reset_item_visual(nb)
	_active_swap_tween = _tween_item_move_pair(na, pos_b, nb, pos_a, false)
	await _active_swap_tween.finished
	_active_swap_tween = null


func _start_optimistic_swap(a: Vector2i, b: Vector2i) -> void:
	_optimistic_swap_done = true
	_busy = true
	_kill_swap_tween()
	var ka := _key(a.x, a.y)
	var kb := _key(b.x, b.y)
	var na = _items.get(ka, null)
	var nb = _items.get(kb, null)
	if na == null or nb == null:
		return
	_items[ka] = nb
	_items[kb] = na
	nb.set_meta("cell", a)
	na.set_meta("cell", b)
	var pos_a := _item_position(a.x, a.y)
	var pos_b := _item_position(b.x, b.y)
	nb.set_meta("rest_position", pos_a)
	na.set_meta("rest_position", pos_b)
	_reset_item_visual(na)
	_reset_item_visual(nb)
	na.z_index = 1
	nb.z_index = 1
	_play_swap_sfx()
	_active_swap_tween = _tween_item_move_pair(na, pos_b, nb, pos_a, false)
	_active_swap_tween.finished.connect(func() -> void:
		if is_instance_valid(na):
			na.z_index = 0
		if is_instance_valid(nb):
			nb.z_index = 0
	)


func _kill_swap_tween() -> void:
	if _active_swap_tween and _active_swap_tween.is_running():
		_active_swap_tween.kill()
	_active_swap_tween = null


func _animate_destroy(
	matched: GnosisNode,
	contributions: GnosisNode,
	show_score: bool = true,
	play_match_sfx: bool = true,
	step: GnosisNode = null
) -> void:
	if matched == null or not matched.is_valid() or matched.get_type() != GnosisValueType.LIST:
		return
	if matched.get_count() > 0 and play_match_sfx:
		_combo_count += 1
		_play_match_sfx()
	var contrib_map := _build_contribution_lookup(contributions)
	var floor_pop_map := _build_floor_pop_lookup(step)
	var nodes: Array = []
	for i in matched.get_count():
		var c = matched.get_node(i)
		if not c.is_valid():
			continue
		var key := _key(_node_int(c, "x", 0), _node_int(c, "y", 0))
		var node = _items.get(key, null)
		if node == null:
			continue
		_items.erase(key)
		nodes.append({"node": node, "contrib": contrib_map.get(key, null), "cell_key": key})
	if nodes.is_empty():
		return
	var batch := create_tween().set_parallel(true)
	for entry in nodes:
		var node: Control = entry["node"]
		var contrib: GnosisNode = entry["contrib"]
		var cell_key: String = str(entry.get("cell_key", ""))
		if floor_pop_map.has(cell_key):
			var parts := cell_key.split(",")
			if parts.size() == 2:
				_pulse_floor_cell(int(parts[0]), int(parts[1]))
		if show_score:
			_spawn_destroy_score_popups(node, contrib)
		_spawn_floor_bonus_popups(node, floor_pop_map.get(str(entry.get("cell_key", "")), null))
		_spawn_sparkles(node)
		_prep_destroy(node)
		batch.tween_property(node, "scale", Vector2.ZERO, DESTROY_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	batch.finished.connect(func() -> void:
		for entry in nodes:
			var node = entry["node"]
			if is_instance_valid(node):
				node.queue_free()
	)
	await _wait(STEP_PAUSE)


func _build_contribution_lookup(contributions: GnosisNode) -> Dictionary:
	var map: Dictionary = {}
	if contributions == null or not contributions.is_valid() or contributions.get_type() != GnosisValueType.LIST:
		return map
	for i in contributions.get_count():
		var contrib = contributions.get_node(i)
		if not contrib.is_valid():
			continue
		var key := _key(_node_int(contrib, "x", 0), _node_int(contrib, "y", 0))
		map[key] = contrib
	return map


func _build_floor_pop_lookup(step: GnosisNode) -> Dictionary:
	var map: Dictionary = {}
	if step == null or not step.is_valid():
		return map
	var pops := step.get_node("floorFloatPops")
	if not pops.is_valid() or pops.get_type() != GnosisValueType.LIST:
		return map
	for i in pops.get_count():
		var pop = pops.get_node(i)
		if not pop.is_valid():
			continue
		var key := _key(_node_int(pop, "x", 0), _node_int(pop, "y", 0))
		map[key] = pop
	return map


func _spawn_floor_bonus_popups(node: Control, pop: GnosisNode) -> void:
	if node == null or pop == null or not pop.is_valid():
		return
	var anchor := node.position + node.size * 0.5
	var points := _node_int(pop, "pointsDelta", 0)
	var multi := _node_int(pop, "multiDelta", 0)
	var money := _node_int(pop, "moneyDelta", 0)
	if points > 0:
		BoardFloatJuiceScript.spawn_labeled_popup(
			self,
			anchor + Vector2(0, -18),
			Match3ScoreFloatingDisplayText.build_points_add(points),
			BoardFloatJuiceScript.COLOR_POINTS,
			0.08
		)
	if multi > 0:
		BoardFloatJuiceScript.spawn_labeled_popup(
			self,
			anchor + Vector2(0, 10),
			Match3ScoreFloatingDisplayText.build_multi_add(multi),
			BoardFloatJuiceScript.COLOR_MULTI,
			0.12
		)
	if money > 0:
		BoardFloatJuiceScript.spawn_labeled_popup(
			self,
			anchor,
			Match3ScoreFloatingDisplayText.build_points_add(money),
			BoardFloatJuiceScript.COLOR_MONEY,
			0.0
		)


func _spawn_destroy_score_popups(node: Control, contrib: GnosisNode) -> void:
	if node == null:
		return
	var points := 0
	var multi := 0
	var item_type_id := "plain"
	if contrib != null and contrib.is_valid():
		points = _node_int(contrib, "pointsAdded", 0)
		multi = _node_int(contrib, "multiAdded", 0)
		item_type_id = _node_string(contrib, "itemTypeId", "plain")
	if points <= 0 and multi <= 0:
		points = int(node.get_meta("point_for_item", 0))
		multi = int(node.get_meta("multi_for_item", 0))
		if item_type_id == "plain":
			item_type_id = str(node.get_meta("item_type_id", "plain"))
	var anchor := node.position + node.size * 0.5
	BoardFloatJuiceScript.spawn_destroy_gem_popups(self, anchor, points, multi, item_type_id)


func _animate_moves(movements: GnosisNode) -> void:
	if movements == null or not movements.is_valid() or movements.get_type() != GnosisValueType.LIST:
		return
	var collected: Array = []
	var from_keys: Array = []
	for i in movements.get_count():
		var m = movements.get_node(i)
		if not m.is_valid():
			continue
		var from_key := _key(_node_int(m, "fromX", 0), _node_int(m, "fromY", 0))
		var to := Vector2i(_node_int(m, "toX", 0), _node_int(m, "toY", 0))
		var node = _items.get(from_key, null)
		if node == null:
			continue
		collected.append({"node": node, "to": to})
		from_keys.append(from_key)
	if collected.is_empty():
		return
	for from_key in from_keys:
		_items.erase(from_key)
	for entry in collected:
		var node = entry["node"]
		var to: Vector2i = entry["to"]
		node.set_meta("cell", to)
		var dest := _item_position(to.x, to.y)
		node.set_meta("rest_position", dest)
		_reset_item_visual(node)
		_items[_key(to.x, to.y)] = node
		_tween_item_move(node, dest, true, to.y)
	await _wait(STEP_PAUSE)


func _animate_spawns(spawns: GnosisNode) -> void:
	if spawns == null or not spawns.is_valid() or spawns.get_type() != GnosisValueType.LIST:
		return
	var drop := (cell_size.y + cell_gap) * 2.0
	for i in spawns.get_count():
		var s = spawns.get_node(i)
		if not s.is_valid():
			continue
		var coord := Vector2i(_node_int(s, "x", 0), _node_int(s, "y", 0))
		var item_id := _node_string(s, "itemId", "")
		if item_id.is_empty():
			continue
		var key := _key(coord.x, coord.y)
		var existing = _items.get(key, null)
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		var node := _make_item_node(item_id)
		_items[key] = node
		_place_node(node, coord.x, coord.y)
		var dest := _item_position(coord.x, coord.y)
		node.position.y -= drop
		_tween_item_move(node, dest, true, coord.y)
	if spawns.get_count() > 0:
		await _wait(STEP_PAUSE)


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout


# --- Item nodes / layout -----------------------------------------------------

func _make_item_node(item_id: String) -> Control:
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sprite := TextureRect.new()
	sprite.name = &"Sprite"
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if _textures.has(item_id):
		sprite.texture = _textures[item_id]
	else:
		sprite.modulate = ITEM_COLORS.get(item_id, Color.WHITE)
	wrap.add_child(sprite)
	wrap.set_meta("item_id", item_id)
	add_child(wrap)
	return wrap


func _item_sprite(wrap: Control) -> TextureRect:
	if wrap == null:
		return null
	var sprite := wrap.get_node_or_null("Sprite")
	return sprite as TextureRect


func _reset_item_visual(wrap: Control) -> void:
	if wrap == null:
		return
	wrap.scale = Vector2.ONE
	wrap.modulate = Color.WHITE
	wrap.rotation = 0.0
	var sprite := _item_sprite(wrap)
	if sprite:
		sprite.scale = Vector2.ONE
		sprite.modulate = Color.WHITE
		sprite.pivot_offset = Vector2.ZERO
		sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
		sprite.offset_left = 0.0
		sprite.offset_top = 0.0
		sprite.offset_right = 0.0
		sprite.offset_bottom = 0.0
	if wrap.has_meta("rest_position"):
		wrap.position = wrap.get_meta("rest_position")
		wrap.pivot_offset = Vector2.ZERO
	else:
		wrap.pivot_offset = Vector2.ZERO


## Snap to rest pose and scale from the tile center (not top-left).
func _prep_destroy(wrap: Control) -> void:
	if wrap == null:
		return
	_kill_node_tweens(wrap)
	wrap.scale = Vector2.ONE
	wrap.rotation = 0.0
	wrap.modulate = Color.WHITE
	if wrap.has_meta("rest_position"):
		wrap.position = wrap.get_meta("rest_position")
	var sprite := _item_sprite(wrap)
	if sprite:
		_kill_node_tweens(sprite)
		sprite.scale = Vector2.ONE
		sprite.modulate = Color.WHITE
	# Pivot at tile center while position stays at the cell's top-left corner.
	wrap.pivot_offset = wrap.size * 0.5


func _kill_node_tweens(node: Node) -> void:
	if node == null:
		return
	var tw := node.create_tween()
	tw.kill()


func _layout_sprite(wrap: Control, tile: Rect2) -> void:
	var sprite := _item_sprite(wrap)
	if sprite == null:
		return
	sprite.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.offset_left = 0.0
	sprite.offset_top = 0.0
	sprite.offset_right = 0.0
	sprite.offset_bottom = 0.0
	sprite.size = tile.size
	sprite.custom_minimum_size = tile.size


## Template tile.gd move_to: TRANS_BACK slide + elastic squash on the sprite.
func _tween_item_move(wrap: Control, dest: Vector2, play_land_sfx: bool, gameplay_y: int) -> void:
	if wrap == null:
		return
	var sprite := _item_sprite(wrap)
	var tw: Tween = wrap.create_tween().set_parallel(true)
	tw.tween_property(wrap, "position", dest, MOVE_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if sprite:
		sprite.scale = Vector2(1.2, 0.8)
		tw.tween_property(sprite, "scale", Vector2.ONE, MOVE_DURATION) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if play_land_sfx:
		tw.finished.connect(func() -> void: _play_land_sfx(gameplay_y))


func _tween_item_move_pair(a: Control, dest_a: Vector2, b: Control, dest_b: Vector2, play_land_sfx: bool) -> Tween:
	var tw: Tween = create_tween().set_parallel(true)
	if a:
		tw.tween_property(a, "position", dest_a, MOVE_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var sprite_a := _item_sprite(a)
		if sprite_a:
			sprite_a.scale = Vector2(1.2, 0.8)
			tw.tween_property(sprite_a, "scale", Vector2.ONE, MOVE_DURATION) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if b:
		tw.tween_property(b, "position", dest_b, MOVE_DURATION) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var sprite_b := _item_sprite(b)
		if sprite_b:
			sprite_b.scale = Vector2(1.2, 0.8)
			tw.tween_property(sprite_b, "scale", Vector2.ONE, MOVE_DURATION) \
				.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tw


func _spawn_sparkles(wrap: Control) -> void:
	if wrap == null or SparklesScene == null:
		return
	var fx = SparklesScene.instantiate()
	fx.position = wrap.position + wrap.size * 0.5
	add_child(fx)


# --- SFX (templates/match3/scripts/audio.gd) --------------------------------

func _init_sfx_pool() -> void:
	for _i in 8:
		var player := AudioStreamPlayer.new()
		player.bus = &"Master"
		player.volume_db = -10.0
		add_child(player)
		_sfx_players.append(player)
		_sfx_available.append(player)
		player.finished.connect(_on_sfx_finished.bind(player))


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	if player not in _sfx_available:
		_sfx_available.append(player)


func _play_sfx(path: String, allow_overlap: bool = false, pitch: float = 1.0, volume: float = 0.3) -> void:
	if path.is_empty() or not ResourceLoader.exists(path) or _sfx_available.is_empty():
		return
	if not allow_overlap and _is_sfx_playing(path):
		return
	var player: AudioStreamPlayer = _sfx_available.pop_front()
	player.stream = load(path)
	player.pitch_scale = pitch
	player.volume_db = _linear_to_db(volume)
	player.set_meta("sfx_path", path)
	player.play()


func _is_sfx_playing(path: String) -> bool:
	for player in _sfx_players:
		if player.playing and str(player.get_meta("sfx_path", "")) == path:
			return true
	return false


func _play_swap_sfx() -> void:
	_play_sfx(SFX_SWAP, true, randf_range(0.8, 1.2), 0.3)


func _play_match_sfx() -> void:
	_play_sfx(SFX_MATCH, true, 1.0 + float(_combo_count) * 0.1, 1.0)


func _play_land_sfx(gameplay_y: int) -> void:
	_play_sfx(SFX_LAND, true, 1.2 - float(gameplay_y) * 0.05, 0.2)


func _linear_to_db(linear: float) -> float:
	if linear > 0.0:
		return 20.0 * log(linear) / log(10.0)
	return -80.0


func _item_tile_rect(x: int, gameplay_y: int) -> Rect2:
	var rect := _cell_rect(x, gameplay_y)
	if ITEM_INSET_RATIO <= 0.0:
		return rect
	var pad := maxf(1.0, rect.size.x * ITEM_INSET_RATIO)
	return rect.grow(-pad)


func _item_position(x: int, gameplay_y: int) -> Vector2:
	return _item_tile_rect(x, gameplay_y).position


func _place_node(wrap: Control, x: int, gameplay_y: int) -> void:
	var tile := _item_tile_rect(x, gameplay_y)
	wrap.custom_minimum_size = tile.size
	wrap.size = tile.size
	_reset_item_visual(wrap)
	wrap.position = tile.position
	wrap.z_index = 0
	_layout_sprite(wrap, tile)
	wrap.set_meta("cell", Vector2i(x, gameplay_y))
	wrap.set_meta("rest_position", tile.position)
	_sync_item_score_meta(wrap, x, gameplay_y)


func _sync_item_score_meta(wrap: Control, x: int, gameplay_y: int) -> void:
	if wrap == null or _service == null:
		return
	var gameplay = _service.get_gameplay()
	if gameplay == null:
		return
	var data = gameplay.get_tile(x, gameplay_y)
	if data == null:
		return
	wrap.set_meta("point_for_item", data.point_for_item)
	wrap.set_meta("multi_for_item", data.multi_for_item)
	wrap.set_meta("item_type_id", data.item_type_id)


func _clear_items() -> void:
	_kill_swap_tween()
	for node in _items.values():
		if is_instance_valid(node):
			node.queue_free()
	_items.clear()


func _update_layout() -> void:
	if _width <= 0 or _height <= 0:
		queue_redraw()
		return
	var avail := size
	if avail.x <= 0.0 or avail.y <= 0.0:
		return
	var step_x := avail.x / (_width + maxi(0, _width - 1) * CELL_GAP_RATIO)
	var step_y := avail.y / (_height + maxi(0, _height - 1) * CELL_GAP_RATIO)
	var cs := maxf(1.0, minf(step_x, step_y))
	cell_gap = cs * CELL_GAP_RATIO
	cell_size = Vector2(cs, cs)
	var board_w := _width * cs + maxi(0, _width - 1) * cell_gap
	var board_h := _height * cs + maxi(0, _height - 1) * cell_gap
	_origin = Vector2((avail.x - board_w) * 0.5, (avail.y - board_h) * 0.5)
	if _dragging:
		return
	for key in _items:
		var node = _items[key]
		if not is_instance_valid(node):
			continue
		var coord: Vector2i = node.get_meta("cell", Vector2i.ZERO)
		_place_node(node, coord.x, coord.y)
	queue_redraw()


func _sync_cell_floors_from_service() -> void:
	if _service == null or _cells.is_empty():
		return
	var gameplay = _service.get_gameplay()
	if gameplay == null:
		return
	for cell in _cells:
		var x := int(cell.get("x", 0))
		var y := int(cell.get("y", 0))
		var tile = gameplay.get_tile(x, y)
		cell["cellFloorTypeId"] = tile.cell_floor_type_id if tile else ""
	queue_redraw()


func _draw() -> void:
	for cell in _cells:
		var slot_type := int(cell.get("slotType", Match3ModelsScript.SLOT_ACTIVE))
		if slot_type == Match3ModelsScript.SLOT_NONE:
			continue
		var rect := _cell_rect(int(cell.get("x", 0)), int(cell.get("y", 0)))
		draw_rect(rect, Color(0.12, 0.14, 0.2, 0.35), true)
		var floor_type_id := str(cell.get("cellFloorTypeId", "")).strip_edges()
		if floor_type_id.is_empty():
			continue
		var floor_tex: Texture2D = Match3FloorSpritesScript.texture_for_floor_type(floor_type_id)
		if floor_tex:
			_draw_floor_texture(rect, floor_tex)
	if _dragging and _drag_start_cell.x >= 0:
		draw_rect(_cell_rect(_drag_start_cell.x, _drag_start_cell.y), Color(1, 1, 1, 0.45), false, 3.0)
		if _hover_cell.x >= 0 and _hover_cell != _drag_start_cell:
			draw_rect(_cell_rect(_hover_cell.x, _hover_cell.y), Color(1, 1, 0.55, 0.55), false, 3.0)
	elif _hover_cell.x >= 0:
		draw_rect(_cell_rect(_hover_cell.x, _hover_cell.y), Color(1, 1, 1, 0.2), false, 3.0)


# --- Swipe input -------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _busy or _adapter == null or _service == null or not _service.is_board_input_allowed():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = event.position
		if event.pressed:
			var cell := _cell_at_local(local_pos)
			if cell.x < 0 or not _has_item_at(cell):
				return
			_begin_drag(cell, local_pos)
			accept_event()
		elif _dragging:
			_finish_drag(local_pos)
			accept_event()
	elif event is InputEventMouseMotion and not _dragging:
		var cell := _cell_at_local(event.position)
		if cell != _hover_cell:
			_hover_cell = cell
			queue_redraw()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	if event is InputEventMouseMotion:
		_update_drag_preview(_local_from_event(event))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(_local_from_event(event))
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _dragging:
		_update_drag_preview(get_local_mouse_position())


func _local_from_event(event: InputEvent) -> Vector2:
	if event is InputEventMouse:
		return get_global_transform().affine_inverse() * event.global_position
	return get_local_mouse_position()


func _begin_drag(cell: Vector2i, local_pos: Vector2) -> void:
	_dragging = true
	_drag_committed = false
	_drag_start_cell = cell
	_drag_start_pos = local_pos
	_drag_node = _items.get(_key(cell.x, cell.y), null)
	if _drag_node:
		_drag_rest_pos = _drag_node.position
		_drag_rest_z = _drag_node.z_index
		_drag_node.z_index = 10
		_drag_node.modulate = DRAG_HIGHLIGHT
	_hover_cell = cell
	set_process(true)
	queue_redraw()


func _update_drag_preview(local_pos: Vector2) -> void:
	if not _dragging or _drag_node == null or _drag_committed:
		return
	var delta := local_pos - _drag_start_pos
	var neighbor := _neighbor_from_swipe(_drag_start_cell, delta)
	if neighbor.x >= 0 and _has_item_at(neighbor) and _are_adjacent(_drag_start_cell, neighbor):
		_commit_drag_swap(_drag_start_cell, neighbor)
		return
	var max_len := cell_size.x * DRAG_FOLLOW_RATIO
	if delta.length() > max_len:
		delta = delta.normalized() * max_len
	_drag_node.position = _drag_rest_pos + delta
	if neighbor != _hover_cell:
		_hover_cell = neighbor
		queue_redraw()


func _commit_drag_swap(start: Vector2i, neighbor: Vector2i) -> void:
	if _drag_committed or _busy:
		return
	_drag_committed = true
	if _drag_node:
		_drag_node.z_index = _drag_rest_z
		_reset_item_visual(_drag_node)
		_drag_node.position = _drag_rest_pos
	_start_optimistic_swap(start, neighbor)
	_adapter.request_move(start.x, start.y, neighbor.x, neighbor.y)
	_end_drag_state()


func _end_drag_state() -> void:
	_dragging = false
	_drag_committed = false
	_drag_start_cell = Vector2i(-1, -1)
	_drag_node = null
	_hover_cell = Vector2i(-1, -1)
	set_process(false)
	queue_redraw()


func _finish_drag(local_pos: Vector2) -> void:
	if not _dragging:
		return
	if _drag_committed:
		_end_drag_state()
		return
	var delta := local_pos - _drag_start_pos
	var neighbor := _neighbor_from_swipe(_drag_start_cell, delta)
	var valid_swap := neighbor.x >= 0 and _has_item_at(neighbor) and _are_adjacent(_drag_start_cell, neighbor)
	if _drag_node:
		_drag_node.z_index = _drag_rest_z
		_reset_item_visual(_drag_node)
	if valid_swap:
		_commit_drag_swap(_drag_start_cell, neighbor)
		return
	if _drag_node:
		var snap := create_tween().set_parallel(true)
		snap.tween_property(_drag_node, "position", _drag_rest_pos, 0.1) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		snap.tween_property(_drag_node, "modulate", Color.WHITE, 0.1)
	_end_drag_state()


func _cancel_drag() -> void:
	if not _dragging:
		return
	if _drag_node and is_instance_valid(_drag_node):
		_drag_node.position = _drag_rest_pos
		_reset_item_visual(_drag_node)
		_drag_node.z_index = _drag_rest_z
	_end_drag_state()


func _neighbor_from_swipe(start: Vector2i, delta: Vector2) -> Vector2i:
	if delta.length() < MIN_DRAG_PX:
		return Vector2i(-1, -1)
	var other := start
	if absf(delta.x) > absf(delta.y):
		other.x += 1 if delta.x > 0 else -1
	else:
		# Screen down (+y) → visually below → smaller gameplay y.
		# Screen up (−y) → visually above → larger gameplay y.
		if delta.y > 0.0:
			other.y -= 1
		else:
			other.y += 1
	return other


func _has_item_at(cell: Vector2i) -> bool:
	return _items.has(_key(cell.x, cell.y))


func _cell_at_local(local_pos: Vector2) -> Vector2i:
	for x in _width:
		for gy in _height:
			if _cell_rect(x, gy).has_point(local_pos):
				return Vector2i(x, gy)
	return Vector2i(-1, -1)


func _visual_y(gameplay_y: int) -> int:
	return _height - 1 - gameplay_y


func _cell_rect(x: int, gameplay_y: int) -> Rect2:
	var px := _origin.x + x * (cell_size.x + cell_gap)
	var py := _origin.y + _visual_y(gameplay_y) * (cell_size.y + cell_gap)
	return Rect2(Vector2(px, py), cell_size)


func _are_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _preload_textures() -> void:
	for item_id in ITEM_TEXTURES.keys():
		var path: String = ITEM_TEXTURES[item_id]
		if ResourceLoader.exists(path):
			_textures[item_id] = load(path)


func _resolve_adapter() -> void:
	_adapter = get_tree().get_first_node_in_group("match3_play_adapter")
	if _adapter:
		_adapter.bind_dispatcher(self)


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)


func _node_string(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)


func _node_bool(node: GnosisNode, key: String, default_value: bool = false) -> bool:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)


func _key(x: int, y: int) -> String:
	return "%d,%d" % [x, y]


func _draw_floor_texture(rect: Rect2, texture: Texture2D) -> void:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var draw_size := tex_size * scale
	var pos := rect.position + (rect.size - draw_size) * 0.5
	draw_texture_rect(texture, Rect2(pos, draw_size), false)
