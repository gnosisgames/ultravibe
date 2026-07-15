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
@onready var _unlock_button: Button = %UnlockButton
@onready var _restore_button: Button = %RestoreButton
@onready var _home_button: Button = %HomeButton
@onready var _card: PanelContainer = $Center/Card

var _host: GnosisGodotEngine = null
var _actions_ready_at := 0.0
var _action_cooldown_timer: SceneTreeTimer = null
var _store_busy := false
var _store_signals_wired := false

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_endless_button.pressed.connect(_on_endless_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	if _unlock_button:
		_unlock_button.pressed.connect(_on_unlock_pressed)
	if _restore_button:
		_restore_button.pressed.connect(_on_restore_pressed)
	_home_button.pressed.connect(_on_title_pressed)
	_set_action_buttons_enabled(false)
	call_deferred("_resolve_host")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_headline()
		_apply_shuffles_label()

@onready var _center: Control = $Center

func get_subscreen_slide_holder() -> Control:
	return _center


func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		_play_card_intro()
		_arm_action_cooldown()
		_refresh()
		_refresh_trial_store_actions()
		call_deferred("_wire_store_signals")
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
	var allow := enabled and not _store_busy
	if _endless_button:
		_endless_button.disabled = not allow
	if _restart_button:
		_restart_button.disabled = not allow
	if _home_button:
		_home_button.disabled = not allow
	if _unlock_button:
		_unlock_button.disabled = not allow or not _should_show_trial_store_actions()
	if _restore_button:
		_restore_button.disabled = not allow or not _should_show_trial_store_actions()

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
	var is_victory: bool = m3 != null and (
		(m3.has_method("is_run_won") and m3.is_run_won()) \
		or (m3.has_method("get_current_status") \
			and m3.get_current_status() == Match3ModelsScript.STATUS_WIN)
	)
	if _endless_button:
		_endless_button.visible = is_victory
	var gameplay = m3.get_gameplay()
	_high_score_value.text = str(gameplay.current_score) if gameplay else "0"
	_round_value.text = str(m3.get_current_round()) if m3.has_method("get_current_round") else "1"
	_floor_value.text = str(m3.get_current_floor()) if m3.has_method("get_current_floor") else "1"
	_moves_value.text = str(m3.get_statistic_int("match3.moves.used")) if m3.has_method("get_statistic_int") else "0"
	_shuffles_value.text = str(m3.get_statistic_int("match3.shuffles.used")) if m3.has_method("get_statistic_int") else "0"
	_purchases_value.text = str(m3.get_statistic_int("match3.shop.purchases.total")) if m3.has_method("get_statistic_int") else "0"
	_rerolls_value.text = str(m3.get_statistic_int("match3.shop.rerolls.total")) if m3.has_method("get_statistic_int") else "0"
	_seed_value.text = str(_resolve_seed())

func _apply_headline() -> void:
	if _title == null:
		return
	var m3 = _match3_service()
	var is_victory: bool = m3 != null and (
		(m3.has_method("is_run_won") and m3.is_run_won()) \
		or (m3.has_method("get_current_status") \
			and m3.get_current_status() == Match3ModelsScript.STATUS_WIN)
	)
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

## Endless: continue the run past round 24 victory (Unity EnableEndlessMode parity).
func _on_endless_pressed() -> void:
	if _actions_blocked():
		return
	GnosisRunSave.clear_run_save()
	var eng := _engine()
	var m3 = _match3_service()
	if eng == null or m3 == null:
		return
	var params := eng.store.create_object()
	params.set_key("enabled", true)
	var result = m3.invoke_function("EnableEndlessMode", params)
	if result is GnosisFunctionResult and not result.is_ok:
		return
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", eng.store.create_object())
	if _host and _host.has_method("resync_match3_board_view"):
		_host.resync_match3_board_view()

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
	if _host and _host.has_method("resync_match3_board_view"):
		_host.resync_match3_board_view()

func _on_title_pressed() -> void:
	if _actions_blocked():
		return
	var eng := _engine()
	var ui := _game_ui()
	if eng == null or ui == null:
		return
	# Leave the game-over context entirely before returning to the title so the
	# overlay state doesn't linger into the next run.
	ui.invoke_function("PopView", eng.store.create_object())
	UltraGameUiNav.return_to_title(ui, eng)


func _edition() -> GnosisEditionService:
	var eng := _engine()
	return eng.get_service("Edition") as GnosisEditionService if eng else null


func _should_show_trial_store_actions() -> bool:
	var edition := _edition()
	return edition != null and edition.should_apply_trial_policy()


func _refresh_trial_store_actions() -> void:
	var show := _should_show_trial_store_actions()
	if _unlock_button:
		_unlock_button.visible = show
	if _restore_button:
		_restore_button.visible = show


func _wire_store_signals() -> void:
	if _store_signals_wired or _host == null:
		return
	var store_host := GnosisEditionStoreHost.find_from(_host)
	if store_host:
		if not store_host.purchase_flow_finished.is_connected(_on_store_purchase_flow_finished):
			store_host.purchase_flow_finished.connect(_on_store_purchase_flow_finished)
		if not store_host.entitlement_granted.is_connected(_on_store_entitlement_granted):
			store_host.entitlement_granted.connect(_on_store_entitlement_granted)
	var edition := _edition()
	if edition:
		if not edition.access_tier_changed.is_connected(_on_access_tier_changed):
			edition.access_tier_changed.connect(_on_access_tier_changed)
		if not edition.purchase_succeeded.is_connected(_on_purchase_succeeded):
			edition.purchase_succeeded.connect(_on_purchase_succeeded)
		if not edition.purchase_failed.is_connected(_on_purchase_failed):
			edition.purchase_failed.connect(_on_purchase_failed)
	_store_signals_wired = true


func _set_store_busy(busy: bool) -> void:
	_store_busy = busy
	_set_action_buttons_enabled(_actions_ready_at <= 0.0 and _action_cooldown_timer == null)


func _on_unlock_pressed() -> void:
	if _actions_blocked() or _store_busy:
		return
	var edition := _edition()
	if edition == null:
		return
	_set_store_busy(true)
	var result: int = edition.try_purchase_full_game()
	if result != GnosisStoreBridge.PurchaseResult.PENDING:
		_set_store_busy(false)


func _on_restore_pressed() -> void:
	if _actions_blocked() or _store_busy:
		return
	var edition := _edition()
	if edition == null:
		return
	_set_store_busy(true)
	var result: int = edition.try_restore_purchases()
	if result != GnosisStoreBridge.PurchaseResult.PENDING:
		_set_store_busy(false)


func _on_store_purchase_flow_finished(success: bool, _reason: String) -> void:
	_set_store_busy(false)
	if success:
		_on_store_entitlement_granted()


func _on_store_entitlement_granted() -> void:
	var edition := _edition()
	if edition:
		edition.try_restore_purchases()
	_refresh_trial_store_actions()


func _on_access_tier_changed(_is_full_access: bool) -> void:
	_refresh_trial_store_actions()


func _on_purchase_succeeded(_product_id: String) -> void:
	_set_store_busy(false)
	_refresh_trial_store_actions()


func _on_purchase_failed(_reason: String) -> void:
	_set_store_busy(false)
