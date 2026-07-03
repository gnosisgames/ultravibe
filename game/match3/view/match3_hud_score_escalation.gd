class_name Match3HudScoreEscalation
extends Node

## Post-target escalation on points (blue) and multi (red): rising sparkles behind
## the colored metric boxes. Intensity ramps with post-target metric bumps.

const SPARKLE_SHADER_PATH := "res://game/match3/view/score_sparkle.gdshader"
const SPARKLE_SHAPE_COUNT := 3
const SPARKLE_SHAPE_SUFFIXES := ["Square", "Circle", "Triangle"]
const SPARKLE_COLUMN_COUNT := 9
const SPARKLE_CENTER_REACH_BOOST := 1.32
const SPARKLE_COLUMN_REACH_EDGE := 0.2
const SPARKLE_COLUMN_REACH_CURVE := 2.0
const SPARKLE_COLUMN_HALF_W := 10.0
const SPARKLE_COLUMN_SIDE_INSET := 6.0
const SPARKLE_COLUMN_SPAN_FRAC := 0.44
const SPARKLE_LAYOUT_VISUAL_FRACTION := 0.12
const SPARKLE_PARTICLE_QUAD_HALF := 2.5

## Fallbacks match match3_hud.tscn StyleBoxFlat bg_color on PointsBox / MultiBox.
const POINTS_SPARKLE_FALLBACK := Color(0.196078, 0.45098, 0.85098, 1.0)
const MULTI_SPARKLE_FALLBACK := Color(0.831373, 0.180392, 0.317647, 1.0)

const INTENSITY_OFF := 0.0
const INTENSITY_SUBTLE := 0.22
const INTENSITY_STRONG := 0.88
const INTENSITY_VISIBLE_THRESHOLD := 0.04

const POST_TARGET_INCREASE_START := 1.0
const POST_TARGET_INCREASE_FULL_FIRE := 45.0
const POST_TARGET_INCREASE_CEILING := 1_000_000.0
const POST_TARGET_INCREASE_CURVE_EXP := 0.7
const POST_TARGET_MELTDOWN_LOG10_COUNT := 10_000.0

## Particle ramp — low → high intensity (post-target bump count).
const SPARKLE_AMOUNT_MIN := 0
const SPARKLE_AMOUNT_MAX := 220
const SPARKLE_SCALE_MIN := 3.6
const SPARKLE_SCALE_MAX := 14.0
const SPARKLE_SCALE_RAMP_EXP := 1.2
const SPARKLE_LIFETIME_MIN := 0.85
const SPARKLE_LIFETIME_MAX := 2.45
const SPARKLE_VEL_MIN_LO := 14.0
const SPARKLE_VEL_MIN_HI := 38.0
const SPARKLE_VEL_MAX_LO := 34.0
const SPARKLE_VEL_MAX_HI := 98.0
const SPARKLE_GRAVITY_LO := -9.0
const SPARKLE_GRAVITY_HI := -28.0
const SPARKLE_SPREAD := 0.0
const SPARKLE_VIS_HEIGHT_LO := 160.0
const SPARKLE_VIS_HEIGHT_HI := 386.0
const SPARKLE_VIS_WIDTH_LO := 140.0
const SPARKLE_VIS_WIDTH_HI := 220.0
const SPARKLE_ANGULAR_LO := 45.0
const SPARKLE_ANGULAR_HI := 200.0
const SPARKLE_SCALE_LIFE_START_LO := 1.0
const SPARKLE_SCALE_LIFE_START_HI := 1.28
const SPARKLE_SCALE_LIFE_HOLD_LO := 0.9
const SPARKLE_SCALE_LIFE_HOLD_HI := 0.86
const SPARKLE_SCALE_LIFE_LATE_LO := 0.62
const SPARKLE_SCALE_LIFE_LATE_HI := 0.5
const SPARKLE_SCALE_LIFE_END_LO := 0.34
const SPARKLE_SCALE_LIFE_END_HI := 0.16
const SPARKLE_SCALE_LIFE_HOLD_FRAC := 0.55
const SPARKLE_SCALE_LIFE_LATE_FRAC := 0.8

var _points_sparkle_tint := POINTS_SPARKLE_FALLBACK
var _multi_sparkle_tint := MULTI_SPARKLE_FALLBACK
var _points_sparkle_materials: Array[ShaderMaterial] = []
var _multi_sparkle_materials: Array[ShaderMaterial] = []
var _points_host: Control = null
var _multi_host: Control = null
var _points_sparkles: Array[GPUParticles2D] = []
var _multi_sparkles: Array[GPUParticles2D] = []
var _post_target_increase_count := 0
var _has_crossed_target := false
var _last_step_points := 0
var _last_step_multi := 0
var _fade_from_intensity := INTENSITY_OFF
var _fade_capture_valid := false
var _current_intensity := INTENSITY_OFF
var _current_sparkle_visual_half := SPARKLE_PARTICLE_QUAD_HALF * SPARKLE_SCALE_MIN
var _sparkle_scale_curve: CurveTexture = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func setup(points_host: Control, multi_host: Control) -> void:
	_points_host = points_host
	_multi_host = multi_host
	_disable_clipping_upwards(points_host)
	_disable_clipping_upwards(multi_host)
	if _points_host != null and is_instance_valid(_points_host) and _points_sparkles.is_empty():
		_points_sparkle_tint = _panel_fill_color(_points_host, POINTS_SPARKLE_FALLBACK)
		_setup_lane_sparkles(_points_host, _points_sparkle_tint, "Points", _points_sparkles, _points_sparkle_materials)
	if _multi_host != null and is_instance_valid(_multi_host) and _multi_sparkles.is_empty():
		_multi_sparkle_tint = _panel_fill_color(_multi_host, MULTI_SPARKLE_FALLBACK)
		_setup_lane_sparkles(_multi_host, _multi_sparkle_tint, "Multi", _multi_sparkles, _multi_sparkle_materials)
	if _points_host != null and is_instance_valid(_points_host):
		if not _points_host.resized.is_connected(_sync_layouts):
			_points_host.resized.connect(_sync_layouts)
	if _multi_host != null and is_instance_valid(_multi_host):
		if not _multi_host.resized.is_connected(_sync_layouts):
			_multi_host.resized.connect(_sync_layouts)
	reset_move_ramp(0, 0)
	call_deferred("_refresh_sparkle_tints")
	call_deferred("_sync_layouts")


func _process(_delta: float) -> void:
	_sync_layouts()


func reset_move_ramp(banked_total: int, target_score: int) -> void:
	_post_target_increase_count = 0
	_last_step_points = 0
	_last_step_multi = 0
	_has_crossed_target = target_score > 0 and banked_total >= target_score
	_fade_capture_valid = false
	_apply_intensity(INTENSITY_OFF)


func update_from_step(banked_total: int, step_points: int, step_multi: int, target_score: int) -> void:
	if target_score <= 0:
		_apply_intensity(INTENSITY_OFF)
		return
	if step_points <= 0 or step_multi <= 0:
		return
	var move_product := step_points * maxi(1, step_multi)
	var projected := banked_total + move_product
	var passed := banked_total >= target_score or projected >= target_score
	var increased := step_points > _last_step_points or step_multi > _last_step_multi
	if passed:
		if not _has_crossed_target:
			_has_crossed_target = true
		if increased:
			_post_target_increase_count += 1
	_last_step_points = step_points
	_last_step_multi = step_multi
	_fade_capture_valid = false
	_apply_intensity(_compute_intensity(_post_target_increase_count))


func fade_toward_off(t01: float) -> void:
	if not _fade_capture_valid:
		_begin_fade_capture()
	var t := smoothstep(0.0, 1.0, clampf(t01, 0.0, 1.0))
	_apply_intensity(lerpf(_fade_from_intensity, INTENSITY_OFF, t))


func hide_effects() -> void:
	_fade_capture_valid = false
	_apply_intensity(INTENSITY_OFF)


func _setup_lane_sparkles(
	host: Control,
	tint: Color,
	lane_prefix: StringName,
	sparkles_out: Array[GPUParticles2D],
	materials_out: Array[ShaderMaterial]
) -> void:
	for col_idx in SPARKLE_COLUMN_COUNT:
		var reach := _column_reach_factor(col_idx)
		var shape_idx := col_idx % SPARKLE_SHAPE_COUNT
		var material := _create_sparkle_material(tint, shape_idx)
		var particle_name := "%sSparklesC%d%s" % [
			lane_prefix,
			col_idx,
			SPARKLE_SHAPE_SUFFIXES[shape_idx]
		]
		var sparkles := _create_sparkles(particle_name, material)
		sparkles.set_meta("reach_factor", reach)
		sparkles.set_meta("column_index", col_idx)
		materials_out.append(material)
		sparkles_out.append(sparkles)
		_attach_lane_sparkles(host, sparkles)


func _column_signed_offset(col_idx: int) -> float:
	if SPARKLE_COLUMN_COUNT <= 1:
		return 0.0
	return float(col_idx) / float(SPARKLE_COLUMN_COUNT - 1) * 2.0 - 1.0


func _column_reach_factor(col_idx: int) -> float:
	var edge_dist := absf(_column_signed_offset(col_idx))
	return lerpf(
		SPARKLE_CENTER_REACH_BOOST,
		SPARKLE_COLUMN_REACH_EDGE,
		pow(edge_dist, SPARKLE_COLUMN_REACH_CURVE)
	)


func _column_span(host_width: float) -> float:
	var hype_span := host_width * SPARKLE_COLUMN_SPAN_FRAC
	var soft_cap := (
		host_width * 0.5
		- SPARKLE_COLUMN_SIDE_INSET
		- SPARKLE_COLUMN_HALF_W
		- _current_sparkle_visual_half * SPARKLE_LAYOUT_VISUAL_FRACTION
	)
	return maxf(minf(hype_span, soft_cap), 16.0)


func _update_sparkle_scale_curve(t: float) -> CurveTexture:
	if _sparkle_scale_curve == null:
		_sparkle_scale_curve = CurveTexture.new()
		_sparkle_scale_curve.curve = Curve.new()
	var curve := _sparkle_scale_curve.curve
	while curve.point_count > 0:
		curve.remove_point(0)
	var start := lerpf(SPARKLE_SCALE_LIFE_START_LO, SPARKLE_SCALE_LIFE_START_HI, t)
	var hold := lerpf(SPARKLE_SCALE_LIFE_HOLD_LO, SPARKLE_SCALE_LIFE_HOLD_HI, t)
	var late := lerpf(SPARKLE_SCALE_LIFE_LATE_LO, SPARKLE_SCALE_LIFE_LATE_HI, t)
	var end := lerpf(SPARKLE_SCALE_LIFE_END_LO, SPARKLE_SCALE_LIFE_END_HI, t)
	curve.add_point(Vector2(0.0, start))
	curve.add_point(Vector2(SPARKLE_SCALE_LIFE_HOLD_FRAC, hold))
	curve.add_point(Vector2(SPARKLE_SCALE_LIFE_LATE_FRAC, late))
	curve.add_point(Vector2(1.0, end))
	return _sparkle_scale_curve


func _panel_fill_color(host: Control, fallback: Color) -> Color:
	if host == null or not is_instance_valid(host):
		return fallback
	if not host.is_inside_tree() or not host.has_theme_stylebox_override("panel"):
		return fallback
	var style := host.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return fallback
	return Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, 1.0)


func _create_sparkle_material(tint: Color, shape_type: int) -> ShaderMaterial:
	var shader := load(SPARKLE_SHADER_PATH) as Shader
	if shader == null:
		push_error("[ScoreEscalation] failed to load shader: %s" % SPARKLE_SHADER_PATH)
		return ShaderMaterial.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("box_color", tint)
	material.set_shader_parameter("shape_type", shape_type)
	return material


func _apply_sparkle_tint(sparkles: GPUParticles2D, material: ShaderMaterial, tint: Color) -> void:
	if sparkles == null or not is_instance_valid(sparkles):
		return
	sparkles.modulate = Color.WHITE
	if material != null:
		material.set_shader_parameter("box_color", Color(tint.r, tint.g, tint.b, 1.0))
	var process := sparkles.process_material as ParticleProcessMaterial
	if process != null:
		process.color = Color.WHITE
		process.color_ramp = null


func _attach_lane_sparkles(host: Control, sparkles: GPUParticles2D) -> void:
	host.clip_contents = false
	host.clip_children = Control.CLIP_CHILDREN_DISABLED
	host.add_child(sparkles)
	host.move_child(sparkles, 0)
	for child in host.get_children():
		if child is Control and child != sparkles:
			child.z_index = 1


func _create_sparkles(particle_name: StringName, material: ShaderMaterial) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = particle_name
	particles.show_behind_parent = true
	particles.local_coords = true
	particles.amount = 16
	particles.lifetime = 1.4
	particles.preprocess = 1.2
	particles.explosiveness = 0.0
	particles.randomness = 0.4
	particles.fixed_fps = 0
	particles.visibility_rect = Rect2(-90.0, -160.0, 180.0, 180.0)
	particles.emitting = false
	particles.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(SPARKLE_COLUMN_HALF_W, 2.0, 1.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = SPARKLE_SPREAD
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 42.0
	process.gravity = Vector3(0.0, -12.0, 0.0)
	process.angular_velocity_min = -90.0
	process.angular_velocity_max = 90.0
	process.scale_min = 3.5
	process.scale_max = 6.5
	process.color = Color.WHITE
	process.color_ramp = null
	process.scale_curve = _update_sparkle_scale_curve(0.0)
	particles.process_material = process
	return particles


func _disable_clipping_upwards(node: Node) -> void:
	var ancestor: Node = node
	while ancestor != null:
		if ancestor is Control:
			var control := ancestor as Control
			control.clip_contents = false
			control.clip_children = Control.CLIP_CHILDREN_DISABLED
		ancestor = ancestor.get_parent()


func _refresh_sparkle_tints() -> void:
	_points_sparkle_tint = _panel_fill_color(_points_host, POINTS_SPARKLE_FALLBACK)
	_multi_sparkle_tint = _panel_fill_color(_multi_host, MULTI_SPARKLE_FALLBACK)
	for i in _points_sparkles.size():
		_apply_sparkle_tint(_points_sparkles[i], _points_sparkle_materials[i], _points_sparkle_tint)
	for i in _multi_sparkles.size():
		_apply_sparkle_tint(_multi_sparkles[i], _multi_sparkle_materials[i], _multi_sparkle_tint)


func _sync_layouts() -> void:
	_layout_lane(_points_host, _points_sparkles)
	_layout_lane(_multi_host, _multi_sparkles)


func _layout_lane(host: Control, sparkles: Array[GPUParticles2D]) -> void:
	if host == null or not is_instance_valid(host):
		return
	var visible_fx := _current_intensity >= INTENSITY_VISIBLE_THRESHOLD
	for particle in sparkles:
		if particle == null or not is_instance_valid(particle):
			continue
		particle.visible = visible_fx
		particle.emitting = visible_fx
	if not visible_fx or host.size.x < 2.0 or host.size.y < 2.0:
		return
	var span := _column_span(host.size.x)
	for particle in sparkles:
		if particle == null or not is_instance_valid(particle):
			continue
		var col_idx := int(particle.get_meta("column_index", 0))
		var signed_offset := _column_signed_offset(col_idx)
		particle.position = Vector2(host.size.x * 0.5 + signed_offset * span, 0.0)
		var process := particle.process_material as ParticleProcessMaterial
		if process != null:
			process.emission_box_extents = Vector3(SPARKLE_COLUMN_HALF_W, 2.0, 1.0)


func _compute_intensity(post_target_increases: int) -> float:
	if post_target_increases <= 0:
		return INTENSITY_OFF
	var count_for_ramp := minf(float(post_target_increases), POST_TARGET_INCREASE_FULL_FIRE)
	var t_linear := inverse_lerp(
		POST_TARGET_INCREASE_START,
		POST_TARGET_INCREASE_FULL_FIRE,
		count_for_ramp
	)
	var t01 := pow(clampf(t_linear, 0.0, 1.0), POST_TARGET_INCREASE_CURVE_EXP)
	var intensity := lerpf(INTENSITY_SUBTLE, INTENSITY_STRONG, t01)
	var log_count_source := minf(float(post_target_increases), POST_TARGET_INCREASE_CEILING)
	var log_count := log(maxf(log_count_source, POST_TARGET_INCREASE_START + 0.0001)) / log(10.0)
	var log_end := log(POST_TARGET_INCREASE_CEILING) / log(10.0)
	var log_meltdown_start := log(POST_TARGET_MELTDOWN_LOG10_COUNT) / log(10.0)
	var meltdown := 0.0
	if log_count > log_meltdown_start:
		meltdown = clampf(
			(log_count - log_meltdown_start) / maxf(0.00001, log_end - log_meltdown_start),
			0.0,
			1.0
		)
	intensity = lerpf(intensity, 1.0, meltdown)
	return intensity


func _split_sparkle_amount(total_amount: int, sparkles: Array[GPUParticles2D]) -> PackedInt32Array:
	var amounts := PackedInt32Array()
	amounts.resize(sparkles.size())
	if sparkles.is_empty():
		return amounts
	var weights: Array[float] = []
	var weight_sum := 0.0
	for particle in sparkles:
		var reach := float(particle.get_meta("reach_factor", 1.0))
		var weight := lerpf(0.3, 1.0, reach)
		weights.append(weight)
		weight_sum += weight
	if total_amount <= 0 or weight_sum <= 0.0:
		for i in sparkles.size():
			amounts[i] = 1
		return amounts
	var assigned := 0
	for i in sparkles.size():
		amounts[i] = maxi(1, int(floor(float(total_amount) * weights[i] / weight_sum)))
		assigned += amounts[i]
	var remainder := total_amount - assigned
	var order: Array[int] = []
	for i in sparkles.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return weights[a] > weights[b]
	)
	var order_idx := 0
	while remainder > 0 and not order.is_empty():
		amounts[order[order_idx % order.size()]] += 1
		remainder -= 1
		order_idx += 1
	order_idx = 0
	while remainder < 0 and not order.is_empty():
		var slot := order[order.size() - 1 - (order_idx % order.size())]
		if amounts[slot] > 1:
			amounts[slot] -= 1
			remainder += 1
		order_idx += 1
		if order_idx > sparkles.size() * 8:
			break
	return amounts


func _apply_intensity(intensity: float) -> void:
	_current_intensity = clampf(intensity, 0.0, 1.0)
	var t := _current_intensity
	var sparkle_amount := int(lerpf(float(SPARKLE_AMOUNT_MIN), float(SPARKLE_AMOUNT_MAX), t))
	var scale_t := pow(t, SPARKLE_SCALE_RAMP_EXP)
	var sparkle_scale := lerpf(SPARKLE_SCALE_MIN, SPARKLE_SCALE_MAX, scale_t)
	var scale_spread_lo := lerpf(0.96, 0.88, t)
	var scale_spread_hi := lerpf(1.2, 1.48, t)
	var scale_curve := _update_sparkle_scale_curve(t)
	var life_start_scale := lerpf(SPARKLE_SCALE_LIFE_START_LO, SPARKLE_SCALE_LIFE_START_HI, t)
	_current_sparkle_visual_half = (
		SPARKLE_PARTICLE_QUAD_HALF * sparkle_scale * scale_spread_hi * life_start_scale
	)
	var lifetime := lerpf(SPARKLE_LIFETIME_MIN, SPARKLE_LIFETIME_MAX, t)
	var vel_min := lerpf(SPARKLE_VEL_MIN_LO, SPARKLE_VEL_MIN_HI, t)
	var vel_max := lerpf(SPARKLE_VEL_MAX_LO, SPARKLE_VEL_MAX_HI, t)
	var gravity_y := lerpf(SPARKLE_GRAVITY_LO, SPARKLE_GRAVITY_HI, t)
	var vis_height := lerpf(SPARKLE_VIS_HEIGHT_LO, SPARKLE_VIS_HEIGHT_HI, t)
	var vis_half_w := lerpf(SPARKLE_VIS_WIDTH_LO, SPARKLE_VIS_WIDTH_HI, t)
	var angular := lerpf(SPARKLE_ANGULAR_LO, SPARKLE_ANGULAR_HI, t)
	var randomness := lerpf(0.12, 0.22, t)
	for sparkles: Array[GPUParticles2D] in [_points_sparkles, _multi_sparkles]:
		var per_column_amounts := _split_sparkle_amount(sparkle_amount, sparkles)
		for col_idx in sparkles.size():
			var particle: GPUParticles2D = sparkles[col_idx]
			if particle == null or not is_instance_valid(particle):
				continue
			var reach := float(particle.get_meta("reach_factor", 1.0))
			particle.amount = per_column_amounts[col_idx]
			particle.lifetime = lifetime * reach
			particle.randomness = randomness
			particle.preprocess = lerpf(0.6, 1.4, t)
			particle.visibility_rect = Rect2(-vis_half_w, -vis_height, vis_half_w * 2.0, vis_height + 32.0)
			var process := particle.process_material as ParticleProcessMaterial
			if process != null:
				process.scale_min = sparkle_scale * scale_spread_lo * lerpf(0.92, 1.0, reach)
				process.scale_max = sparkle_scale * scale_spread_hi * lerpf(0.92, 1.0, reach)
				process.scale_curve = scale_curve
				process.initial_velocity_min = vel_min * reach
				process.initial_velocity_max = vel_max * reach
				process.gravity = Vector3(0.0, gravity_y * reach, 0.0)
				process.spread = SPARKLE_SPREAD
				process.angular_velocity_min = -angular
				process.angular_velocity_max = angular
	_sync_layouts()


func _begin_fade_capture() -> void:
	_fade_from_intensity = _current_intensity
	_fade_capture_valid = true
