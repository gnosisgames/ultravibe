class_name Match3Dispatcher
extends Control

## Board view + swap input (initial port of Unity Match3Dispatcher).

const GROUP := "match3_dispatcher"
const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Match3EventsScript = preload("res://game/match3/match3_events.gd")
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

@export var cell_size: Vector2 = Vector2(56, 56)
@export var cell_gap: float = 4.0

var _service = null
var _adapter = null
var _width: int = 0
var _height: int = 0
var _tiles: Array = []
var _textures: Dictionary = {}
var _drag_start: Vector2i = Vector2i(-1, -1)
var _hover_cell: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_preload_textures()
	call_deferred("_resolve_adapter")


func bind_service(service) -> void:
	_service = service
	_sync_from_service()
	queue_redraw()


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
	if payload == null or not payload.is_valid():
		_sync_from_service()
		return
	_width = _node_int(payload, Events.PAYLOAD_WIDTH, _width)
	_height = _node_int(payload, Events.PAYLOAD_HEIGHT, _height)
	_tiles = _tiles_from_payload(payload)
	_update_layout()
	queue_redraw()
	refresh_hud()


func _sync_from_service() -> void:
	if _service == null:
		return
	var gameplay = _service.get_gameplay()
	_width = gameplay.width
	_height = gameplay.height
	_tiles = []
	for y in _height:
		for x in _width:
			var tile = gameplay.get_tile(x, y)
			_tiles.append({
				"x": x,
				"y": y,
				"itemId": tile.item_id if tile else "",
				"slotType": tile.slot_type if tile else Match3ModelsScript.SLOT_NONE,
			})
	_update_layout()
	queue_redraw()
	refresh_hud()


func _tiles_from_payload(payload: GnosisNode) -> Array:
	var result: Array = []
	var tiles := payload.get_node(Events.PAYLOAD_TILES)
	if not tiles.is_valid() or tiles.get_type() != GnosisValueType.LIST:
		return result
	for i in tiles.get_count():
		var tile_node = tiles.get_node(i)
		if not tile_node.is_valid():
			continue
		result.append({
			"x": _node_int(tile_node, "x", 0),
			"y": _node_int(tile_node, "y", 0),
			"itemId": _node_string(tile_node, "itemId", ""),
			"slotType": _node_int(tile_node, "slotType", Match3ModelsScript.SLOT_ACTIVE),
		})
	return result


func _update_layout() -> void:
	var board_w := _width * cell_size.x + maxi(0, _width - 1) * cell_gap
	var board_h := _height * cell_size.y + maxi(0, _height - 1) * cell_gap
	custom_minimum_size = Vector2(board_w, board_h)
	set_anchors_preset(Control.PRESET_CENTER)
	position = Vector2(-board_w * 0.5, -board_h * 0.5)


func _draw() -> void:
	for tile in _tiles:
		var x := int(tile.get("x", 0))
		var y := int(tile.get("y", 0))
		var rect := _cell_rect(x, y)
		var slot_type := int(tile.get("slotType", Match3ModelsScript.SLOT_ACTIVE))
		if slot_type == Match3ModelsScript.SLOT_NONE:
			continue
		draw_rect(rect, Color(0.12, 0.14, 0.2, 0.35), true)
		var item_id := str(tile.get("itemId", ""))
		if item_id.is_empty():
			continue
		if _textures.has(item_id):
			draw_texture_rect(_textures[item_id], rect.grow(-4), false)
		else:
			var color: Color = ITEM_COLORS.get(item_id, Color.WHITE)
			draw_rect(rect.grow(-6), color, true)
		if _drag_start == Vector2i(x, y) or _hover_cell == Vector2i(x, y):
			draw_rect(rect, Color(1, 1, 1, 0.35), false, 3.0)


func _gui_input(event: InputEvent) -> void:
	if _adapter == null or _service == null or not _service.is_board_input_allowed():
		return
	if event is InputEventMouseMotion:
		_hover_cell = _cell_at_local(event.position)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _cell_at_local(event.position)
		if event.pressed:
			_drag_start = cell
		else:
			if _drag_start.x >= 0 and cell.x >= 0:
				if _drag_start != cell and _are_adjacent(_drag_start, cell):
					_adapter.request_move(_drag_start.x, _drag_start.y, cell.x, cell.y)
			_drag_start = Vector2i(-1, -1)
			queue_redraw()


func _cell_at_local(local_pos: Vector2) -> Vector2i:
	for x in _width:
		for y in _height:
			if _cell_rect(x, y).has_point(local_pos):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _cell_rect(x: int, y: int) -> Rect2:
	var px := x * (cell_size.x + cell_gap)
	var py := y * (cell_size.y + cell_gap)
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
