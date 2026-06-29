class_name PlayHudNextPreview
extends Control

## Draws up to three upcoming ultravibe previews (right-rail queue).

@export var preview_cell := 14

var _service: FallingBlockService = null
var _registry := UltravibeRegistry.new()

var _variant_colors := {
	"blue": Color(0.2, 0.5, 1.0),
	"red": Color(1.0, 0.25, 0.25),
	"green": Color(0.2, 0.85, 0.35),
	"orange": Color(1.0, 0.55, 0.1),
	"disabled": Color(0.45, 0.45, 0.45),
}

func _ready() -> void:
	_registry.load_shapes()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func bind_service(service: FallingBlockService) -> void:
	_service = service

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _service == null or _service.context == null:
		return
	var queues := FallingBlockEphemeral.get_fb_node(_service.context, "nextPiecesQueues")
	if not queues.is_valid() or queues.get_type() != GnosisValueType.OBJECT:
		return
	var queue := queues.get_node("P0")
	if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST:
		return
	var py := 0.0
	for i in range(mini(3, queue.get_count())):
		var entry := queue.get_node(i)
		if not entry.is_valid():
			continue
		var poly_id := _node_str(entry, "ultravibeId")
		var variant_id := _node_str(entry, "variantId")
		var info := _registry.get_shape(poly_id)
		if info == null:
			continue
		var color: Color = _variant_colors.get(variant_id.to_lower(), Color(0.75, 0.75, 0.85))
		var min_x := 0
		var min_y := 0
		for off in info.block_offsets:
			min_x = mini(min_x, off.x)
			min_y = mini(min_y, off.y)
		for off in info.block_offsets:
			var cx := float(off.x - min_x) * preview_cell
			var cy := py + float(off.y - min_y) * preview_cell
			draw_rect(Rect2(cx, cy, preview_cell - 1, preview_cell - 1), color)
		py += preview_cell * 4 + 10.0

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value)
	return ""
