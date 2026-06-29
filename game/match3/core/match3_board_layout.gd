class_name Match3BoardLayout
extends RefCounted

const Models = preload("res://game/match3/core/match3_models.gd")

## Parses UltraVibe board JSON into a runtime layout.

var id: String = ""
var width: int = 0
var height: int = 0
var squares: Array = []


class Square:
	var x: int
	var y: int
	var slot_type: int = Models.SLOT_ACTIVE
	var slot_health: int = 0
	var item_id: String = ""
	var item_type_id: String = "plain"
	var cell_floor_type_id: String = ""
	var enter_square: bool = false


static func from_json(data: Dictionary) -> Match3BoardLayout:
	var layout := Match3BoardLayout.new()
	layout.id = str(data.get("id", ""))
	layout.width = int(data.get("cols", data.get("width", 0)))
	layout.height = int(data.get("rows", data.get("height", 0)))
	var raw_squares: Variant = data.get("squares", [])
	if raw_squares is Array:
		for raw in raw_squares:
			if raw is Dictionary:
				layout.squares.append(_parse_square(raw))
	return layout


static func _parse_square(raw: Dictionary) -> Square:
	var sq := Square.new()
	var pos: Variant = raw.get("position", {})
	if pos is Dictionary:
		sq.x = int(pos.get("x", 0))
		sq.y = int(pos.get("y", 0))
	var block := int(raw.get("block", 1))
	var obstacle := int(raw.get("obstacle", 0))
	sq.slot_health = maxi(0, int(raw.get("blockLayer", 0)) + int(raw.get("obstacleLayer", 0)))
	if block <= 0 and obstacle <= 0:
		sq.slot_type = Models.SLOT_NONE
	elif sq.slot_health > 0:
		sq.slot_type = Models.SLOT_DESTRUCTIBLE
	else:
		sq.slot_type = Models.SLOT_ACTIVE
	sq.enter_square = bool(raw.get("enterSquare", false))
	sq.cell_floor_type_id = str(raw.get("cellFloorTypeId", "")).strip_edges()
	var item: Variant = raw.get("item", {})
	if item is Dictionary and not item.is_empty():
		sq.item_id = str(item.get("id", item.get("itemId", ""))).strip_edges()
		sq.item_type_id = str(item.get("typeId", item.get("itemTypeId", "plain"))).strip_edges()
	return sq
