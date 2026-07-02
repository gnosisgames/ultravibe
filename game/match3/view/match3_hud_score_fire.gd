class_name Match3HudScoreFire
extends RefCounted

## Score-panel fire overlay when banked score exceeds round target (Unity MainHud.ScoreFire parity).

const SHADER_POWER_OFF := 100.0
const SHADER_POWER_SUBTLE := 6.0
const SHADER_POWER_STRONG := 2.5
const POST_TARGET_INCREASE_FULL_FIRE := 45.0
const POST_TARGET_INCREASE_CURVE_EXP := 0.7

var _overlay: ColorRect = null
var _material: ShaderMaterial = null
var _post_target_increase_count := 0
var _has_crossed_target := false
var _last_step_points := 0
var _last_step_multi := 0


func setup(host: Control) -> void:
	if host == null or not is_instance_valid(host):
		return
	_overlay = ColorRect.new()
	_overlay.name = "ScoreFireOverlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.show_behind_parent = true
	var shader := load("res://game/match3/view/score_fire.gdshader") as Shader
	if shader:
		_material = ShaderMaterial.new()
		_material.shader = shader
		var fire_tex := load("res://assets/unity/Sprites/Materials/fire.png") as Texture2D
		if fire_tex:
			_material.set_shader_parameter("fire_texture", fire_tex)
		_material.set_shader_parameter("power", SHADER_POWER_OFF)
		_overlay.material = _material
	host.add_child(_overlay)
	host.move_child(_overlay, 0)


func reset_move_ramp(banked_total: int, target_score: int) -> void:
	_post_target_increase_count = 0
	_last_step_points = 0
	_last_step_multi = 0
	_has_crossed_target = target_score > 0 and banked_total >= target_score
	_apply_shader(SHADER_POWER_OFF, -0.1)


func update_from_step(banked_total: int, step_points: int, step_multi: int, target_score: int) -> void:
	if target_score <= 0:
		_apply_shader(SHADER_POWER_OFF, -0.1)
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
	var power := _compute_power(_post_target_increase_count)
	var speed_y := lerpf(-0.1, -0.5, clampf(float(_post_target_increase_count) / POST_TARGET_INCREASE_FULL_FIRE, 0.0, 1.0))
	_apply_shader(power, speed_y)


func fade_toward_off(t01: float) -> void:
	if _material == null:
		return
	var current_power: float = _material.get_shader_parameter("power")
	var current_speed: float = _material.get_shader_parameter("speed_y")
	var t := smoothstep(0.0, 1.0, clampf(t01, 0.0, 1.0))
	_apply_shader(lerpf(current_power, SHADER_POWER_OFF, t), lerpf(current_speed, -0.1, t))


func hide_fire() -> void:
	_apply_shader(SHADER_POWER_OFF, -0.1)


func _compute_power(post_target_increases: int) -> float:
	if post_target_increases <= 0:
		return SHADER_POWER_OFF
	var normalized := pow(
		clampf(float(post_target_increases) / POST_TARGET_INCREASE_FULL_FIRE, 0.0, 1.0),
		POST_TARGET_INCREASE_CURVE_EXP,
	)
	return lerpf(SHADER_POWER_SUBTLE, SHADER_POWER_STRONG, normalized)


func _apply_shader(power: float, speed_y: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("power", power)
	_material.set_shader_parameter("speed_y", speed_y)
