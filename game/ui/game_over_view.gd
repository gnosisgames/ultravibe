class_name UltravibeGameOverView
extends GnosisUIElementView

## Final run summary overlay (Unity StatePanel parity) shown after Match3 publishes
## a terminal game status (loss / game over, or victory).

const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const SHUFFLES_LABEL_KEY := "match3__state__label__totalShuffles"

## Brief lockout so an input burst that triggers game over cannot instantly fire
## one of the action buttons on the same frame.
const ACTION_COOLDOWN_SEC := 1.0

@onready var _title: BBCodeEffectTextCombine = $Center/Card/VBox/Title
@onready var _high_score_value: Label = %HighScoreValue
@onready var _moves_value: Label = %MovesValue
@onready var _shuffles_value: Label = %ShufflesValue
@onready var _shuffles_label: RichTextLabel = %ShufflesLabel
@onready var _purchases_value: Label = %PurchasesValue
@onready var _rerolls_value: Label = %RerollsValue
@onready var _round_value: Label = %RoundValue
@onready var _floor_value: Label = %FloorValue
@onready var _seed_value: Label = %SeedValue
@onready var _endless_button: Button = %EndlessButton
@onready var _restart_button: Button = %RestartButton
@onready var _home_button: Button = %HomeButton
@onready var _card: PanelContainer = $Center/Card

var _host: GnosisGodotEngine = null
var _actions_ready_at := 0.0
var _action_cooldown_timer: SceneTreeTimer = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_endless_button.pressed.connect(_on_endless_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_home_button.pressed.connect(_on_title_pressed)
	_set_action_buttons_enabled(false)
	call_deferred("_resolve_host")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_headline()
		_apply_shuffles_label()

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
	if _endless_button:
		_endless_button.disabled = not enabled
	if _restart_button:
		_restart_button.disabled = not enabled
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

func _match3_service():
	var eng := _engine()
	return eng.get_service("Match3") if eng else null

func _refresh() -> void:
	_apply_headline()
	_apply_shuffles_label()
	var m3 = _match3_service()
	if m3 == null:
		return
	var is_victory: bool = m3.has_method("get_current_status") \
		and m3.get_current_status() == Match3ModelsScript.STATUS_WIN
	if _endless_button:
		_endless_button.visible = is_victory
	var gameplay = m3.get_gameplay()
	_high_score_value.text = str(gameplay.current_score) if gameplay else "0"
	_round_value.text = str(m3.get_current_round()) if m3.has_method("get_current_round") else "1"
	_floor_value.text = str(m3.get_current_floor()) if m3.has_method("get_current_floor") else "1"
	# TODO(ultravibe-port): wire run statistics (moves/shuffles/shop purchases/rerolls)
	# once Match3 statistics are ported. Stubbed to 0 for now (matches money/points stubs).
	_moves_value.text = "0"
	_shuffles_value.text = "0"
	_purchases_value.text = "0"
	_rerolls_value.text = "0"
	_seed_value.text = str(_resolve_seed())

func _apply_headline() -> void:
	if _title == null:
		return
	var m3 = _match3_service()
	var is_victory: bool = m3 != null \
		and m3.has_method("get_current_status") \
		and m3.get_current_status() == Match3ModelsScript.STATUS_WIN
	_title.text_clean = "core__state__victory" if is_victory else "core__state__gameOver"

func _apply_shuffles_label() -> void:
	if _shuffles_label == null:
		return
	_shuffles_label.text = TooltipPopup.format_bbcode(tr(SHUFFLES_LABEL_KEY))

func _resolve_seed() -> int:
	var eng := _engine()
	if eng == null:
		return 0
	var seed_service = eng.get_service("Seed")
	if seed_service and seed_service.has_method("get_seed"):
		return int(seed_service.get_seed())
	return 0

## Endless: continue the run past its terminal state. Endless mode is not yet
## ported from Unity, so for now this restarts the run in place as a placeholder.
func _on_endless_pressed() -> void:
	_on_restart_pressed()

## Restart: close the overlay (revealing gameplay) and restart the run in place,
## mirroring the pause menu's restart.
func _on_restart_pressed() -> void:
	if _actions_blocked():
		return
	GnosisRunSave.clear_run_save()
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", _engine().store.create_object())
	if _host:
		_host.restart_ephemeral_run()
	var m3 = _match3_service()
	if m3:
		m3.handle_run_started()
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("begin_level"):
		adapter.begin_level(1)

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
