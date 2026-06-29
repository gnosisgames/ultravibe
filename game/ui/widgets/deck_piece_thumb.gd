class_name DeckPieceThumb
extends Control

## Draws a single ultravibe shape scaled to fit inside this control's rect, used
## by the pause-screen deck grid. Each occupied cell is painted with the actual
## block sprite (res://assets/blocks/<variantId>Block.png) -- the same art the
## board renderer uses when the piece spawns -- so custom blocks (moss, gold,
## tnt, ...) read exactly as they do in play. A flat colour is only used as a
## fallback when a variant ships no sprite.

const PADDING := 8.0
const CELL_GAP := 2.0
## Mirrors FallingBlockBoardRenderer.BLOCK_SPRITE_DIR / naming convention.
const BLOCK_SPRITE_DIR := "res://assets/blocks/"
## Reference span (largest piece extent in the game, currently Line5) used to pick
## a *universal* cell size: every block is drawn at the same on-screen size across
## thumbnails instead of each piece stretching to fill its slot, so a single block
## in a long line matches a block in a 2x2 square. Smaller pieces are centred with
## empty space around them; the largest piece still fits without clipping.
const MAX_PIECE_SPAN := 5.0

## Shared across every thumbnail so we only hit the filesystem once per variant;
## a missing sprite is cached as null.
static var _texture_cache := {}

var _offsets: Array[Vector2i] = []
var _color := Color(0.75, 0.75, 0.85)
var _texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func setup(offsets: Array, variant_id: String, color: Color) -> void:
	_offsets.clear()
	for off in offsets:
		if off is Vector2i:
			_offsets.append(off)
	_color = color
	_texture = _resolve_texture(variant_id)
	queue_redraw()

static func _resolve_texture(variant_id: String) -> Texture2D:
	var key := variant_id.strip_edges().to_lower()
	if key.is_empty():
		return null
	if _texture_cache.has(key):
		return _texture_cache[key]
	var texture: Texture2D = null
	var path := "%s%sBlock.png" % [BLOCK_SPRITE_DIR, variant_id]
	if ResourceLoader.exists(path):
		texture = load(path) as Texture2D
	_texture_cache[key] = texture
	return texture

func _draw() -> void:
	if _offsets.is_empty():
		return
	var min_x := _offsets[0].x
	var min_y := _offsets[0].y
	var max_x := _offsets[0].x
	var max_y := _offsets[0].y
	for off in _offsets:
		min_x = mini(min_x, off.x)
		min_y = mini(min_y, off.y)
		max_x = maxi(max_x, off.x)
		max_y = maxi(max_y, off.y)
	var cols := float(max_x - min_x + 1)
	var rows := float(max_y - min_y + 1)
	var avail := size - Vector2(PADDING * 2.0, PADDING * 2.0)
	# Universal cell size: sized so the largest possible piece fits, identical for
	# every thumbnail, rather than per-piece "fit to slot" scaling.
	var cell := minf(avail.x, avail.y) / MAX_PIECE_SPAN
	if cell <= 0.0:
		return
	var origin := (size - Vector2(cols, rows) * cell) * 0.5
	for off in _offsets:
		var cx := origin.x + float(off.x - min_x) * cell
		var cy := origin.y + float(off.y - min_y) * cell
		var rect := Rect2(cx, cy, cell - CELL_GAP, cell - CELL_GAP)
		if _texture != null:
			draw_texture_rect(_texture, rect, false)
		else:
			draw_rect(rect, _color)
