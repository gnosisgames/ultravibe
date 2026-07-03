class_name Match3HudScoreEscalation
extends Node

## Post-target escalation on points (blue) and multi (red): rising sparkles behind
## the colored metric boxes. Intensity ramps with post-target metric bumps.

const SPARKLE_SHADER_PATH := "res://game/match3/view/score_sparkle.gdshader"

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

const DEBUG_STEP_COUNT := 10
const DEBUG_KEYCODES_UP := [KEY_9, KEY_KP_9]
const DEBUG_KEYCODES_DOWN := [KEY_8, KEY_KP_8]

var _points_sparkle_tint := POINTS_SPARKLE_FALLBACK
var _multi_sparkle_tint := MULTI_SPARKLE_FALLBACK
var _points_sparkle_material: ShaderMaterial = null
var _multi_sparkle_material: ShaderMaterial = null
var _points_host: Control = null
var _multi_host: Control = null
var _points_sparkles: GPUParticles2D = null
var _multi_sparkles: GPUParticles2D = null
var _post_target_increase_count := 0
var _has_crossed_target := false
var _last_step_points := 0
var _last_step_multi := 0
var _fade_from_intensity := INTENSITY_OFF
var _fade_capture_valid := false
var _debug_step := -1
var _debug_key8_down := false
var _debug_key9_down := false
var _current_intensity := INTENSITY_OFF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func setup(points_host: Control, multi_host: Control) -> void:
	_points_host = points_host
	_multi_host = multi_host
	_disable_clipping_upwards(points_host)
	_disable_clipping_upwards(multi_host)
	if _points_host != null and is_instance_valid(_points_host) and _points_sparkles == null:
		_points_sparkle_tint = _panel_fill_color(_points_host, POINTS_SPARKLE_FALLBACK)
		_points_sparkle_material = _create_sparkle_material(_points_sparkle_tint)
		_points_sparkles = _create_sparkles("PointsSparkles", _points_sparkle_material)
		_attach_lane_sparkles(_points_host, _points_sparkles)
	if _multi_host != null and is_instance_valid(_multi_host) and _multi_sparkles == null:
		_multi_sparkle_tint = _panel_fill_color(_multi_host, MULTI_SPARKLE_FALLBACK)
		_multi_sparkle_material = _create_sparkle_material(_multi_sparkle_tint)
		_multi_sparkles = _create_sparkles("MultiSparkles", _multi_sparkle_material)
		_attach_lane_sparkles(_multi_host, _multi_sparkles)
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
	_poll_debug_keys()


func reset_move_ramp(banked_total: int, target_score: int) -> void:
	if _debug_step >= 0:
		return
	_post_target_increase_count = 0
	_last_step_points = 0
	_last_step_multi = 0
	_has_crossed_target = target_score > 0 and banked_total >= target_score
	_fade_capture_valid = false
	_apply_intensity(INTENSITY_OFF)


func update_from_step(banked_total: int, step_points: int, step_multi: int, target_score: int) -> void:
	if _debug_step >= 0:
		return
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
	if _debug_step >= 0:
		return
	if not _fade_capture_valid:
		_begin_fade_capture()
	var t := smoothstep(0.0, 1.0, clampf(t01, 0.0, 1.0))
	_apply_intensity(lerpf(_fade_from_intensity, INTENSITY_OFF, t))


func hide_effects() -> void:
	if _debug_step >= 0:
		return
	_fade_capture_valid = false
	_apply_intensity(INTENSITY_OFF)


func debug_adjust_intensity(delta: int) -> void:
	if _points_sparkles == null and _multi_sparkles == null:
		push_warning("[ScoreEscalation] debug ignored: sparkles not ready")
		return
	if _debug_step < 0:
		_debug_step = 1 if delta > 0 else DEBUG_STEP_COUNT
	else:
		_debug_step = clampi(_debug_step + delta, 0, DEBUG_STEP_COUNT)
	_apply_debug_step()


func _apply_debug_step() -> void:
	if _debug_step <= 0:
		_fade_capture_valid = false
		_apply_intensity(INTENSITY_OFF)
		print("[ScoreEscalation debug] off (step 0)")
		return
	var t := float(_debug_step) / float(DEBUG_STEP_COUNT)
	var intensity := lerpf(INTENSITY_SUBTLE, INTENSITY_STRONG, t)
	_fade_capture_valid = false
	_apply_intensity(intensity)
	print("[ScoreEscalation debug] step %d/%d intensity=%.2f" % [_debug_step, DEBUG_STEP_COUNT, intensity])


func _poll_debug_keys() -> void:
	var up := _any_debug_key_down(DEBUG_KEYCODES_UP)
	var down := _any_debug_key_down(DEBUG_KEYCODES_DOWN)
	if up and not _debug_key9_down:
		debug_adjust_intensity(1)
	if down and not _debug_key8_down:
		debug_adjust_intensity(-1)
	_debug_key9_down = up
	_debug_key8_down = down


func _any_debug_key_down(keycodes: Array) -> bool:
	for keycode: int in keycodes:
		if Input.is_physical_key_pressed(keycode) or Input.is_key_pressed(keycode):
			return true
	return false


func _panel_fill_color(host: Control, fallback: Color) -> Color:
	if host == null or not is_instance_valid(host):
		return fallback
	if not host.is_inside_tree() or not host.has_theme_stylebox_override("panel"):
		return fallback
	var style := host.get_theme_stylebox("panel") as StyleBoxFlat
	if style == null:
		return fallback
	return Color(style.bg_color.r, style.bg_color.g, style.bg_color.b, 1.0)


func _create_sparkle_material(tint: Color) -> ShaderMaterial:
	var shader := load(SPARKLE_SHADER_PATH) as Shader
	if shader == null:
		push_error("[ScoreEscalation] failed to load shader: %s" % SPARKLE_SHADER_PATH)
		return ShaderMaterial.new()
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("box_color", tint)
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
	particles.amount = 24
	particles.lifetime = 1.1
	particles.preprocess = 1.0
	particles.explosiveness = 0.0
	particles.randomness = 0.35
	particles.fixed_fps = 0
	particles.visibility_rect = Rect2(-80.0, -120.0, 160.0, 140.0)
	particles.emitting = false
	particles.material = material

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(24.0, 2.0, 1.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 28.0
	process.initial_velocity_min = 18.0
	process.initial_velocity_max = 42.0
	process.gravity = Vector3(0.0, -12.0, 0.0)
	process.scale_min = 1.5
	process.scale_max = 3.5
	process.color = Color.WHITE
	process.color_ramp = null
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
	_apply_sparkle_tint(_points_sparkles, _points_sparkle_material, _points_sparkle_tint)
	_apply_sparkle_tint(_multi_sparkles, _multi_sparkle_material, _multi_sparkle_tint)


func _sync_layouts() -> void:
	_layout_lane(_points_host, _points_sparkles)
	_layout_lane(_multi_host, _multi_sparkles)


func _layout_lane(host: Control, sparkles: GPUParticles2D) -> void:
	if host == null or not is_instance_valid(host):
		return
	var visible_fx := _current_intensity >= INTENSITY_VISIBLE_THRESHOLD
	if sparkles != null and is_instance_valid(sparkles):
		sparkles.visible = visible_fx
		sparkles.emitting = visible_fx
	if not visible_fx or host.size.x < 2.0 or host.size.y < 2.0:
		return
	if sparkles != null and is_instance_valid(sparkles):
		sparkles.position = Vector2(host.size.x * 0.5, 0.0)
		var process := sparkles.process_material as ParticleProcessMaterial
		if process != null:
			var half_w := maxf(host.size.x * 0.42, 20.0)
			process.emission_box_extents = Vector3(half_w, 2.0, 1.0)


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


func _apply_intensity(intensity: float) -> void:
	_current_intensity = clampf(intensity, 0.0, 1.0)
	var sparkle_amount := int(lerpf(0.0, 32.0, _current_intensity))
	var sparkle_scale := lerpf(1.2, 3.8, _current_intensity)
	for sparkles in [_points_sparkles, _multi_sparkles]:
		if sparkles == null or not is_instance_valid(sparkles):
			continue
		sparkles.amount = maxi(sparkle_amount, 1 if _current_intensity >= INTENSITY_VISIBLE_THRESHOLD else 0)
		var process := sparkles.process_material as ParticleProcessMaterial
		if process != null:
			process.scale_min = sparkle_scale * 0.85
			process.scale_max = sparkle_scale * 1.15
	_sync_layouts()


func _begin_fade_capture() -> void:
	_fade_from_intensity = _current_intensity
	_fade_capture_valid = true
