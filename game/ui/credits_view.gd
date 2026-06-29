class_name UltravibeCreditsView
extends GnosisUIElementView

@onready var _back_button: Button = %BackButton
@onready var _scroll: ScrollContainer = %ScrollContainer

## Pixels/second the credits scroll while up/down is held on a gamepad or the
## keyboard. The credits screen has no focusable scroll target, so directional
## navigation input is repurposed to drive the scroll bar directly.
const SCROLL_SPEED := 700.0
var _scroll_accum := 0.0

var _host: GnosisGodotEngine = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_back_button.pressed.connect(_on_back_pressed)
	set_process(true)
	call_deferred("_resolve_host")

func _process(delta: float) -> void:
	if _scroll == null or not is_visible_in_tree():
		return
	# ui_up/ui_down cover gamepad d-pad + left stick and keyboard arrows.
	var dir := Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if is_zero_approx(dir):
		_scroll_accum = 0.0
		return
	_scroll_accum += dir * SCROLL_SPEED * delta
	var step := int(_scroll_accum)
	if step != 0:
		_scroll.scroll_vertical += step
		_scroll_accum -= float(step)

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			return
		node = node.get_parent()

func _game_ui() -> GnosisGameUIService:
	if _host and _host.engine:
		return _host.engine.get_service("GameUI") as GnosisGameUIService
	return null

func _on_back_pressed() -> void:
	var ui := _game_ui()
	if ui and _host and _host.engine:
		if ui.get_navigation_history_count() > 0:
			var params := _host.engine.store.create_object()
			params.set_key("transitionId", "slide_up")
			params.set_key("inDuration", 0.35)
			params.set_key("outDuration", 0.35)
			ui.invoke_function("PopView", params)
		else:
			ui.set_base_view("title")
