class_name Match3LuckMeter
extends Control

## Read-only bipolar luck meter: red (unlucky) ← slate neutral → green (lucky).
## Arrow marks current cascade assist; no numeric readout.

const LuckyFindScript = preload("res://game/match3/core/match3_lucky_find.gd")

const OUTLINE := Color(0.992157, 0.894118, 0.72549, 1.0)
const SHADOW := Color(0.078431, 0.137255, 0.227451, 0.85)
const ARROW_FILL := Color(0.992157, 0.894118, 0.72549, 1.0)
const ARROW_OUTLINE := Color(0.078431, 0.137255, 0.227451, 1.0)
const ARROW_DIM := Color(0.5, 0.56, 0.66, 1.0)

## Multi-stop spectrum: warm red → neutral grey (center) → mint green.
const _GRAD_STOPS: Array = [
	{"t": 0.0, "color": Color(0.88, 0.30, 0.34)},
	{"t": 0.18, "color": Color(0.62, 0.32, 0.34)},
	{"t": 0.38, "color": Color(0.48, 0.46, 0.46)},
	{"t": 0.5, "color": Color(0.38, 0.38, 0.40)},
	{"t": 0.62, "color": Color(0.40, 0.44, 0.42)},
	{"t": 0.82, "color": Color(0.28, 0.62, 0.48)},
	{"t": 1.0, "color": Color(0.32, 0.86, 0.60)},
]

const TRACK_HEIGHT_MIN := 22.0
const TRACK_HEIGHT_MAX := 28.0
const ARROW_ZONE_MIN := 14.0
const TRACK_BORDER_WIDTH := 2
const TRACK_BORDER_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const TRACK_CORNER_RADIUS := 6.0

var _display_ratio := 0.5
var _meter_active := true
var _pending_force := false
var _pulse := 0.0
var _move_tween: Tween
var _pulse_tween: Tween
var _fill_texture: ImageTexture
var _fill_texture_key := Vector3i(-1, -1, -1)


func _ready() -> void:
	custom_minimum_size = Vector2(96, 58)
	mouse_filter = MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_invalidate_fill_texture()
	resized.connect(_invalidate_fill_texture)


func _invalidate_fill_texture() -> void:
	_fill_texture = null
	_fill_texture_key = Vector3i(-1, -1, -2)
	queue_redraw()


func configure_from_lucky_find(lucky_find: Match3LuckyFind) -> void:
	if lucky_find == null or not lucky_find.enabled:
		set_meter_active(false)
		return
	set_meter_active(true)
	set_pending_force(lucky_find.pending_force)
	set_assist(lucky_find.temporary_assist)


func set_meter_active(active: bool) -> void:
	_meter_active = active
	modulate.a = 1.0 if active else 0.32
	if not active:
		set_pending_force(false)
		_set_display_ratio(0.5, false)
	queue_redraw()


func set_assist(value: float, animate: bool = true) -> void:
	var ratio := assist_to_ratio(value)
	if animate and is_inside_tree():
		_animate_to_ratio(ratio)
	else:
		_set_display_ratio(ratio, false)


func set_pending_force(pending: bool) -> void:
	if _pending_force == pending:
		return
	_pending_force = pending
	if pending and _meter_active:
		_start_pulse()
	else:
		_stop_pulse()
	queue_redraw()


static func assist_to_ratio(assist: float) -> float:
	var span := LuckyFindScript.MAX_ASSIST - LuckyFindScript.MIN_ASSIST
	if span <= 0.0:
		return 0.5
	return clampf((assist - LuckyFindScript.MIN_ASSIST) / span, 0.0, 1.0)


static func _gradient_color_at(t: float) -> Color:
	var ratio := clampf(t, 0.0, 1.0)
	for i in range(_GRAD_STOPS.size() - 1):
		var a: Dictionary = _GRAD_STOPS[i]
		var b: Dictionary = _GRAD_STOPS[i + 1]
		var t0: float = a.t
		var t1: float = b.t
		if ratio <= t1 or i == _GRAD_STOPS.size() - 2:
			var local := (ratio - t0) / maxf(t1 - t0, 0.0001)
			return (a.color as Color).lerp(b.color as Color, clampf(local, 0.0, 1.0))
	return (_GRAD_STOPS.back().color as Color)


func _animate_to_ratio(target: float) -> void:
	if _move_tween and _move_tween.is_running():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_move_tween.tween_method(_set_display_ratio, _display_ratio, target, 0.26)


func _set_display_ratio(value: float, _unused := true) -> void:
	_display_ratio = clampf(value, 0.0, 1.0)
	queue_redraw()


func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_method(_set_pulse, 0.0, 1.0, 0.42).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, 0.42).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _stop_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	_pulse = 0.0


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _layout_metrics() -> Dictionary:
	var pad_x := 4.0
	var arrow_zone := maxf(ARROW_ZONE_MIN, size.y * 0.19)
	var gap := 5.0
	var track_h := clampf(size.y - arrow_zone - gap - 8.0, TRACK_HEIGHT_MIN, TRACK_HEIGHT_MAX)
	var track_y := arrow_zone + gap
	var track_x0 := pad_x
	var track_w := maxf(size.x - pad_x * 2.0, 8.0)
	return {
		"pad_x": pad_x,
		"arrow_zone": arrow_zone,
		"track_h": track_h,
		"track_y": track_y,
		"track_x0": track_x0,
		"track_w": track_w,
		"track_rect": Rect2(track_x0, track_y, track_w, track_h),
		"radius": _track_corner_radius(track_h, track_w),
	}


func _track_corner_radius(track_h: float, track_w: float) -> int:
	var cap := minf(track_h, track_w) * 0.5
	return int(round(clampf(TRACK_CORNER_RADIUS, 4.0, cap)))


func _draw() -> void:
	if size.x < 12.0 or size.y < 12.0:
		return

	var m := _layout_metrics()
	var track_rect: Rect2 = m.get("track_rect", Rect2())
	var radius: int = int(m.get("radius", 0))

	_draw_track(track_rect, radius)

	var marker_x: float = float(m.track_x0) + float(m.track_w) * _display_ratio
	_draw_arrow(Vector2(marker_x, float(m.arrow_zone) * 0.44), float(m.arrow_zone))


func _draw_track(rect: Rect2, radius: int) -> void:
	var shadow_box := StyleBoxFlat.new()
	shadow_box.bg_color = SHADOW
	shadow_box.set_corner_radius_all(radius)
	draw_style_box(shadow_box, Rect2(rect.position + Vector2(2.0, 3.0), rect.size))

	# Fill the full track rect; white border draws on top so corner gaps stay covered.
	if rect.size.x > 2.0 and rect.size.y > 2.0:
		_draw_rounded_gradient(rect, float(radius))

	var border_box := StyleBoxFlat.new()
	border_box.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	border_box.border_color = TRACK_BORDER_COLOR
	border_box.set_border_width_all(TRACK_BORDER_WIDTH)
	border_box.set_corner_radius_all(radius)
	draw_style_box(border_box, rect)


func _draw_rounded_gradient(rect: Rect2, radius: float) -> void:
	var pixel_size := Vector2i(maxi(1, int(ceil(rect.size.x))), maxi(1, int(ceil(rect.size.y))))
	var texture := _fill_texture_for_size(pixel_size, radius)
	if texture == null:
		return
	draw_texture_rect(texture, rect, false)


func _fill_texture_for_size(pixel_size: Vector2i, radius: float) -> ImageTexture:
	var radius_key := int(round(radius * 100.0))
	var key := Vector3i(pixel_size.x, pixel_size.y, radius_key)
	if _fill_texture != null and _fill_texture_key == key:
		return _fill_texture

	var img := Image.create(pixel_size.x, pixel_size.y, false, Image.FORMAT_RGBA8)
	if img == null:
		return null

	var size_v := Vector2(pixel_size)
	for y in range(pixel_size.y):
		for x in range(pixel_size.x):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			if not _inside_rounded_rect(p, size_v, radius):
				img.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
				continue
			var inner_w := maxf(size_v.x - TRACK_BORDER_WIDTH * 2.0, 1.0)
			var t := clampf((p.x - TRACK_BORDER_WIDTH) / inner_w, 0.0, 1.0)
			var base := _gradient_color_at(t)
			var v := p.y / maxf(size_v.y, 1.0)
			var shaded := base.lightened(lerpf(0.12, -0.08, v))
			if v < 0.34:
				shaded = shaded.lerp(Color(1.0, 1.0, 1.0, 1.0), (0.34 - v) * 0.18)
			img.set_pixel(x, y, shaded)

	_fill_texture = ImageTexture.create_from_image(img)
	_fill_texture_key = key
	return _fill_texture


## Rounded-rectangle hit test (not stadium/pill — that caused puzzle-piece end caps).
static func _inside_rounded_rect(p: Vector2, size: Vector2, radius: float) -> bool:
	var w := size.x
	var h := size.y
	if p.x < 0.0 or p.y < 0.0 or p.x >= w or p.y >= h:
		return false
	var r := minf(radius, minf(w, h) * 0.5)
	if p.x >= r and p.x <= w - r:
		return true
	if p.y >= r and p.y <= h - r:
		return true
	var cx := r if p.x < r else w - r
	var cy := r if p.y < r else h - r
	var dx := p.x - cx
	var dy := p.y - cy
	return dx * dx + dy * dy <= r * r


func _draw_arrow(apex: Vector2, height: float) -> void:
	var scale := 1.0 + _pulse * 0.28 if _pending_force else 1.0
	var h := height * scale
	var half_w := h * 0.50
	var tip := apex + Vector2(0.0, h * 0.58)
	var left := apex + Vector2(-half_w, -h * 0.18)
	var right := apex + Vector2(half_w, -h * 0.18)
	var fill := ARROW_FILL if _meter_active else ARROW_DIM
	if _pending_force:
		fill = fill.lerp(OUTLINE, _pulse * 0.45)

	var shadow_pts := PackedVector2Array([
		tip + Vector2(1.5, 3.0),
		left + Vector2(1.5, 3.0),
		right + Vector2(1.5, 3.0),
	])
	draw_colored_polygon(shadow_pts, SHADOW)

	var pts := PackedVector2Array([tip, left, right])
	draw_colored_polygon(pts, fill)
	draw_polyline(PackedVector2Array([tip, left, right, tip]), ARROW_OUTLINE, 2.0, true)
