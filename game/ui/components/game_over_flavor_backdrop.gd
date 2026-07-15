class_name GameOverFlavorBackdrop
extends Control

## Drifting squares behind the title mascot (gon-style debris field).

const SQUARE_COUNT := 16

@export var drift_speed := 0.65

var _squares: Array[Dictionary] = []
var _palette: Array[Color] = [
	Color(0.95, 0.35, 0.72, 1.0),
	Color(0.55, 0.78, 1.0, 1.0),
	Color(0.72, 0.45, 0.98, 1.0),
	Color(0.35, 0.62, 0.95, 1.0),
	Color(1.0, 0.62, 0.82, 1.0),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	set_process(false)

func start_effect() -> void:
	if _squares.is_empty():
		_spawn_squares()
	set_process(true)
	queue_redraw()

func stop_effect() -> void:
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and not _squares.is_empty():
		_respawn_positions()

func _spawn_squares() -> void:
	_squares.clear()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(SQUARE_COUNT):
		_squares.append(_make_square(rng))

func _respawn_positions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for sq in _squares:
		sq["pos"] = _random_point(rng)

func _make_square(rng: RandomNumberGenerator) -> Dictionary:
	var size := rng.randf_range(10.0, 42.0)
	var angle := rng.randf_range(0.0, TAU)
	var speed := rng.randf_range(18.0, 62.0) * drift_speed
	return {
		"pos": _random_point(rng),
		"vel": Vector2(cos(angle), sin(angle)) * speed,
		"size": size,
		"rot": rng.randf_range(0.0, TAU),
		"spin": rng.randf_range(-1.4, 1.4),
		"alpha": rng.randf_range(0.08, 0.34),
		"color": _palette[rng.randi_range(0, _palette.size() - 1)],
	}

func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	return Vector2(rng.randf_range(0.0, w), rng.randf_range(0.0, h))

func _process(delta: float) -> void:
	if _squares.is_empty():
		return
	var w := maxf(size.x, 1.0)
	var h := maxf(size.y, 1.0)
	for sq in _squares:
		var pos: Vector2 = sq["pos"]
		pos += sq["vel"] * delta
		if pos.x < -sq["size"]:
			pos.x = w + sq["size"]
		elif pos.x > w + sq["size"]:
			pos.x = -sq["size"]
		if pos.y < -sq["size"]:
			pos.y = h + sq["size"]
		elif pos.y > h + sq["size"]:
			pos.y = -sq["size"]
		sq["pos"] = pos
		sq["rot"] = float(sq["rot"]) + float(sq["spin"]) * delta
	queue_redraw()

func _draw() -> void:
	for sq in _squares:
		var half: float = sq["size"] * 0.5
		var col: Color = sq["color"]
		col.a = sq["alpha"]
		draw_set_transform(sq["pos"], sq["rot"], Vector2.ONE)
		draw_rect(Rect2(-half, -half, sq["size"], sq["size"]), col)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
