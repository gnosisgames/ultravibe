class_name UltravibeGameOverView
extends GnosisUIElementView

## Final run summary screen shown after FallingBlock publishes game over.

## Brief lockout so a hard-drop key (space) that also maps to UI submit cannot
## instantly trigger Play Again / Home on the same input burst.
const ACTION_COOLDOWN_SEC := 1.0

@onready var _score_value: Label = %ScoreValue
@onready var _round_value: Label = %RoundValue
@onready var _time_value: Label = %TimeValue
@onready var _objective_value: Label = %ObjectiveValue
@onready var _discards_value: Label = %DiscardsValue
@onready var _fall_speed_value: Label = %FallSpeedValue
@onready var _negative_value: Label = %NegativeValue
@onready var _deck_value: Label = %DeckValue
@onready var _play_again_button: Button = %PlayAgainButton
@onready var _home_button: Button = %HomeButton
@onready var _card: PanelContainer = $Center/Layout/Card

var _host: GnosisGodotEngine = null
var _actions_ready_at := 0.0
var _action_cooldown_timer: SceneTreeTimer = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_play_again_button.pressed.connect(_on_play_again_pressed)
	_home_button.pressed.connect(_on_title_pressed)
	_set_action_buttons_enabled(false)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		_play_card_intro()
		_arm_action_cooldown()
		_refresh()
	else:
		_cancel_action_cooldown()

func _arm_action_cooldown() -> void:
	_cancel_action_cooldown()
	_actions_ready_at = Time.get_ticks_msec() / 1000.0 + ACTION_COOLDOWN_SEC
	_set_action_buttons_enabled(false)
	_action_cooldown_timer = get_tree().create_timer(ACTION_COOLDOWN_SEC)
	_action_cooldown_timer.timeout.connect(_on_action_cooldown_finished, CONNECT_ONE_SHOT)

func _cancel_action_cooldown() -> void:
	_action_cooldown_timer = null
	_actions_ready_at = 0.0

func _on_action_cooldown_finished() -> void:
	_action_cooldown_timer = null
	_actions_ready_at = 0.0
	_set_action_buttons_enabled(true)

func _set_action_buttons_enabled(enabled: bool) -> void:
	if _play_again_button:
		_play_again_button.disabled = not enabled
	if _home_button:
		_home_button.disabled = not enabled

func _actions_blocked() -> bool:
	if _action_cooldown_timer != null:
		return true
	if _actions_ready_at > 0.0:
		return Time.get_ticks_msec() / 1000.0 < _actions_ready_at
	return false

func _play_card_intro() -> void:
	if _card == null:
		return
	var tween_node := _card.get_node_or_null("AutoTween")
	if tween_node and tween_node.has_method("show"):
		tween_node.show()

func _resolve_host() -> void:
	var node: Node = self
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_refresh()

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _falling_block() -> FallingBlockService:
	var eng := _engine()
	return eng.get_service("FallingBlock") as FallingBlockService if eng else null

func _refresh() -> void:
	var fb := _falling_block()
	if fb == null:
		return
	var result = fb.invoke_function("GetRunSummary", GnosisNode.new(null))
	if not (result is GnosisFunctionResult) or not result.is_ok or result.payload == null:
		return
	var summary: GnosisNode = result.payload
	_score_value.text = _formatted(summary.get_node("runTotalScore"), "0")
	_round_value.text = str(_int(summary.get_node("roundNumber"), 1))
	_time_value.text = _format_time(_int(summary.get_node("elapsedSec"), 0))
	_objective_value.text = "%04d" % maxi(0, _int(summary.get_node("linesClearedTotal"), 0))
	# Extra HUD-parity stats (mirroring the topbar/sidebar readouts).
	_discards_value.text = "%04d" % maxi(0, _int(summary.get_node("currentDiscards"), 0))
	_fall_speed_value.text = "%04d" % maxi(0, _int(summary.get_node("fallSpeedDisplay"), 0))
	_negative_value.text = "%04d" % maxi(0, _int(summary.get_node("negativeChanceDisplay"), 0))
	_deck_value.text = "%04d" % maxi(0, _int(summary.get_node("deckSize"), 0))

## Play Again: close the game-over overlay (revealing gameplay) and restart the
## run in place, mirroring the pause menu's restart.
func _on_play_again_pressed() -> void:
	if _actions_blocked():
		return
	GnosisRunSave.clear_run_save()
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", _engine().store.create_object())
	if _host:
		_host.restart_ephemeral_run()
	var falling_block := _falling_block()
	if falling_block:
		falling_block.handle_run_started()

func _on_title_pressed() -> void:
	if _actions_blocked():
		return
	var eng := _engine()
	var ui := _game_ui()
	if eng == null or ui == null:
		return
	# Leave the game-over context entirely before returning to the title so the
	# overlay state doesn't linger into the next run.
	UltraGameUiNav.reset_theme_to_default(eng)
	ui.invoke_function("PopView", eng.store.create_object())
	ui.set_base_view("title")

func _formatted(node: GnosisNode, fallback: String) -> String:
	if node.is_valid() and node.get_type() == GnosisValueType.OBJECT:
		var formatted := node.get_node("formatted")
		if formatted.is_valid() and formatted.value != null:
			return str(formatted.value)
	return fallback

func _int(node: GnosisNode, fallback: int) -> int:
	if not node.is_valid() or node.value == null:
		return fallback
	return int(node.value)

func _format_time(seconds: int) -> String:
	var safe := maxi(0, seconds)
	return "%02d:%02d" % [safe / 60, safe % 60]
