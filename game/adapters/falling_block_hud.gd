class_name FallingBlockHud
extends Control

## Lightweight HUD overlay for Ultravibe. Reads run state straight from the
## FallingBlock service's Ephemeral branch each frame and draws score, round,
## objective progress, pending score, and the next-pieces preview.

const FB := preload("res://game/services/falling_block_ephemeral.gd")

## Horizontal gap between the right edge of the centered board and the HUD panel,
## and the vertical offset from the top of the board.
@export var panel_offset := Vector2(28, 4)
@export var preview_cell := 18

var _service: FallingBlockService = null
var _registry := UltravibeRegistry.new()
var _font: Font = null
var _board_renderer: FallingBlockBoardRenderer = null

var _variant_colors := {
	"blue": Color(0.2, 0.5, 1.0),
	"red": Color(1.0, 0.25, 0.25),
	"green": Color(0.2, 0.85, 0.35),
	"orange": Color(1.0, 0.55, 0.1),
	"disabled": Color(0.45, 0.45, 0.45),
}

func _ready() -> void:
	_registry.load_shapes()
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

func bind_service(service: FallingBlockService) -> void:
	_service = service

func _process(_delta: float) -> void:
	queue_redraw()

func _resolve_panel_origin() -> Vector2:
	if _board_renderer == null:
		_board_renderer = get_tree().get_first_node_in_group(
			FallingBlockBoardRenderer.BOARD_RENDERER_GROUP
		) as FallingBlockBoardRenderer
	if _board_renderer == null:
		return panel_offset
	var board_origin := _board_renderer.get_board_origin()
	var board_width: float = _board_renderer._grid_state.width * _board_renderer.cell_size if _board_renderer._grid_state else 0.0
	return Vector2(
		board_origin.x + board_width + panel_offset.x,
		board_origin.y + panel_offset.y
	)

func _draw() -> void:
	if _service == null or _service.context == null:
		return
	var ctx = _service.context
	var origin := _resolve_panel_origin()
	var x := origin.x
	var y := origin.y

	var run_total := FB.get_fb_scalable(ctx, "runTotalScore")
	var round_no := FB.get_fb_int(ctx, "currentRound", 1)
	var progress := FB.get_fb_int(ctx, "roundLinesCurrent", 0)
	var target := FB.get_fb_int(ctx, "roundLinesNeeded", FallingBlockRoundLines.BASE_LINES_PER_ROUND)

	_text("ULTRAVIBE", Vector2(x, y), 30, Color(0.95, 0.95, 1.0))
	y += 48
	_label_value("SCORE", run_total.to_formatted_string(), Vector2(x, y))
	y += 36
	_label_value("ROUND", str(round_no), Vector2(x, y))
	y += 36
	_label_value("OBJECTIVE", "%d / %d lines" % [progress, target], Vector2(x, y))
	y += 28

	# Round line progress bar.
	var bar_w := 240.0
	var ratio := 0.0 if target <= 0 else clampf(float(progress) / float(target), 0.0, 1.0)
	draw_rect(Rect2(x, y, bar_w, 16), Color(0.12, 0.12, 0.16))
	draw_rect(Rect2(x, y, bar_w * ratio, 16), Color(0.2, 0.85, 0.35))
	draw_rect(Rect2(x, y, bar_w, 16), Color(0.3, 0.3, 0.4), false, 1.0)
	y += 40

	_draw_line_score_legend(Vector2(x, y))
	y += 52

	_text("NEXT", Vector2(x, y), 20, Color(0.8, 0.8, 0.9))
	y += 28
	_draw_next_pieces(ctx, Vector2(x, y))

func _draw_line_score_legend(origin: Vector2) -> void:
	_text("LINE SCORE", origin, 16, Color(0.65, 0.65, 0.75))
	var y := origin.y + 22
	var entries := [
		["1", str(FallingBlockLineScoring.SCORE_SINGLE)],
		["2", str(FallingBlockLineScoring.SCORE_DOUBLE)],
		["3", str(FallingBlockLineScoring.SCORE_TRIPLE)],
		["4", str(FallingBlockLineScoring.SCORE_QUAD)],
		["5+", str(FallingBlockLineScoring.SCORE_PENTA_PLUS)],
	]
	for entry in entries:
		_text("%s -> %s" % [entry[0], entry[1]], Vector2(origin.x, y), 14, Color(0.85, 0.85, 0.92))
		y += 18

func _draw_next_pieces(ctx, origin: Vector2) -> void:
	var queues := FB.get_fb_node(ctx, "nextPiecesQueues")
	if not queues.is_valid() or queues.get_type() != GnosisValueType.OBJECT:
		return
	var queue := queues.get_node("P0")
	if not queue.is_valid() or queue.get_type() != GnosisValueType.LIST:
		return
	var py := origin.y
	for i in range(min(3, queue.get_count())):
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
			var cx := origin.x + float(off.x - min_x) * preview_cell
			var cy := py + float(off.y - min_y) * preview_cell
			draw_rect(Rect2(cx, cy, preview_cell - 1, preview_cell - 1), color)
		py += preview_cell * 4 + 8

func _ratio(progress: GnosisScalableValue, target: GnosisScalableValue) -> float:
	var t: float = target.to_float()
	if t <= 0.0:
		return 0.0
	return clampf(progress.to_float() / t, 0.0, 1.0)

func _label_value(label: String, value: String, pos: Vector2) -> void:
	_text(label, pos, 18, Color(0.65, 0.65, 0.75))
	_text(value, pos + Vector2(125, 0), 20, Color(1.0, 1.0, 1.0))

func _text(s: String, pos: Vector2, size: int, color: Color) -> void:
	if _font == null:
		return
	draw_string(_font, pos + Vector2(0, size), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _node_str(node: GnosisNode, key: String) -> String:
	var n := node.get_node(key)
	if n.is_valid() and n.value != null:
		return str(n.value)
	return ""
