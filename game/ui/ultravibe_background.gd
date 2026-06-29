extends ColorRect

## Drives the animated app background from the active visual theme, mirroring the
## old Unity app:
##   background.main   -> base fill color and the bottom fade gradient
##   background.subtle -> tint of the scrolling checker / tetromino patterns
## Re-applies automatically whenever the Theme service reports a new theme id
## (e.g. when a boss encounter swaps in its theme).

@onready var _checker: ColorRect = $Checker
@onready var _tetrominoes: ColorRect = $Tetrominoes
@onready var _fade: TextureRect = $FadeGradient

var _checker_tint_alpha: float = 0.18
var _tetrominoes_tint_alpha: float = 0.5
var _fade_gradient: Gradient = null
var _last_theme_id := ""

func _ready() -> void:
	_checker_tint_alpha = _read_tint_alpha(_checker, _checker_tint_alpha)
	_tetrominoes_tint_alpha = _read_tint_alpha(_tetrominoes, _tetrominoes_tint_alpha)
	# Use a private copy of the fade gradient so we never mutate shared scene data.
	if _fade and _fade.texture is GradientTexture2D:
		var tex := (_fade.texture as GradientTexture2D).duplicate(true) as GradientTexture2D
		_fade.texture = tex
		_fade_gradient = tex.gradient
	set_process(true)

func _process(_delta: float) -> void:
	var theme_service = _theme_service()
	if theme_service == null:
		return
	var theme_id: String = theme_service.get_current_theme_id()
	if theme_id == _last_theme_id:
		return
	_last_theme_id = theme_id
	_apply_theme(theme_service)

func _apply_theme(theme_service) -> void:
	var main_color := _theme_color(theme_service, "background.main", color)
	var subtle_color := _theme_color(theme_service, "background.subtle", Color(0.55, 0.75, 0.96))
	color = main_color
	_apply_tint(_checker, subtle_color, _checker_tint_alpha)
	_apply_tint(_tetrominoes, subtle_color, _tetrominoes_tint_alpha)
	if _fade_gradient:
		for i in range(_fade_gradient.get_point_count()):
			var existing := _fade_gradient.get_color(i)
			_fade_gradient.set_color(i, Color(main_color.r, main_color.g, main_color.b, existing.a))

func _apply_tint(rect: ColorRect, rgb: Color, alpha: float) -> void:
	if rect == null:
		return
	var mat := rect.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("tint", Color(rgb.r, rgb.g, rgb.b, alpha))

func _read_tint_alpha(rect: ColorRect, fallback: float) -> float:
	if rect:
		var mat := rect.material as ShaderMaterial
		if mat:
			var t = mat.get_shader_parameter("tint")
			if t is Color:
				return (t as Color).a
	return fallback

func _theme_service():
	var host := UltraUiFx.resolve_host(self)
	if host and host.engine:
		return host.engine.get_service("Theme")
	return null

func _theme_color(theme_service, prop: String, default_color: Color) -> Color:
	var hex: String = theme_service.get_theme_property(prop, "")
	if hex.is_empty():
		return default_color
	return Color.from_string(hex, default_color)
