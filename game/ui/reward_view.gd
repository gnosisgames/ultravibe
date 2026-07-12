class_name UltravibeRewardView
extends GnosisUIElementView

## Round reward overlay (Unity RoundPanel parity). Presents pending payout steps one
## row at a time with animated <c>$</c> glyphs, grants money through
## Match3.GrantNextRoundRewardStep after each line, then Continue transitions to shop.

const SubscreenFrame = preload("res://game/ui/subscreen_frame.gd")
const TuningScript = preload("res://game/match3/view/match3_animation_tuning.gd")
const ACTION_COOLDOWN_SEC := 0.6

@onready var _rows: VBoxContainer = %RewardRows
@onready var _reward_scroll: ScrollContainer = %RewardScroll
@onready var _empty_label: Label = %EmptyLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _center: Control = %Center
@onready var _card: PanelContainer = $Center/Card

var _host: GnosisGodotEngine = null
var _actions_ready_at := 0.0
var _action_cooldown_timer: SceneTreeTimer = null
var _presenting := false
var _presentation_gen := 0

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_continue_button.pressed.connect(_on_continue_pressed)
	_set_continue_enabled(false)
	if _rows:
		_rows.child_order_changed.connect(_sync_reward_scroll)
	if _reward_scroll:
		_reward_scroll.resized.connect(_sync_reward_scroll)
	call_deferred("_resolve_host")

func get_subscreen_slide_holder() -> Control:
	return _center


func set_view_visible(is_visible: bool) -> void:
	var was_visible := visible
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		SubscreenFrame.connect_changes(self, _apply_frame)
		_apply_frame()
		_play_card_intro()
		if not was_visible:
			_arm_action_cooldown()
			_start_reward_presentation()
		_sync_reward_scroll()
		call_deferred("_focus_continue_button")
	else:
		_presenting = false
		_presentation_gen += 1
		_cancel_action_cooldown()
		SubscreenFrame.disconnect_changes(self, _apply_frame)

func get_preferred_focus_control() -> Control:
	if _continue_button and not _continue_button.disabled:
		return _continue_button
	return null

func _focus_continue_button() -> void:
	if not is_visible_in_tree():
		return
	var target := get_preferred_focus_control()
	if target:
		target.grab_focus()

func _apply_frame() -> void:
	# Extend to HUD bottom (same line as sidebar buttons + consumables bar).
	SubscreenFrame.apply_planning(self, _center)

func _arm_action_cooldown() -> void:
	_cancel_action_cooldown()
	_actions_ready_at = Time.get_ticks_msec() / 1000.0 + ACTION_COOLDOWN_SEC
	_set_continue_enabled(false)
	_action_cooldown_timer = get_tree().create_timer(ACTION_COOLDOWN_SEC)
	_action_cooldown_timer.timeout.connect(_on_action_cooldown_finished, CONNECT_ONE_SHOT)

func _cancel_action_cooldown() -> void:
	_action_cooldown_timer = null
	_actions_ready_at = 0.0

func _on_action_cooldown_finished() -> void:
	_action_cooldown_timer = null
	_actions_ready_at = 0.0
	if not _presenting:
		_set_continue_enabled(true)

func _set_continue_enabled(enabled: bool) -> void:
	if _continue_button:
		_continue_button.disabled = not enabled
	if enabled:
		call_deferred("_focus_continue_button")

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

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

func _match3_service():
	var eng := _engine()
	return eng.get_service("Match3") if eng else null

func _clear_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	_sync_reward_scroll()


func _sync_reward_scroll() -> void:
	if _reward_scroll == null or _rows == null:
		return
	call_deferred("_apply_reward_scroll_mode")


func _apply_reward_scroll_mode() -> void:
	if _reward_scroll == null or _rows == null:
		return
	var content_h := _rows.get_combined_minimum_size().y
	var viewport_h := _reward_scroll.size.y
	if content_h > viewport_h + 1.0:
		_reward_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	else:
		_reward_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_reward_scroll.scroll_vertical = 0

func _start_reward_presentation() -> void:
	_presentation_gen += 1
	var gen := _presentation_gen
	_clear_rows()
	if _empty_label:
		_empty_label.visible = false
	_presenting = true
	call_deferred("_present_rewards_stepwise", gen)

func _read_pending_payout() -> GnosisNode:
	var eng := _engine()
	if eng == null or eng.state == null or not eng.state.root.is_valid():
		return GnosisNode.new(null)
	var ephemeral := eng.state.root.get_node("Ephemeral")
	if not ephemeral.is_valid():
		return GnosisNode.new(null)
	var match3 := ephemeral.get_node("match3")
	if not match3.is_valid():
		return GnosisNode.new(null)
	return match3.get_node("pendingRoundReward")

## Unity PresentRoundRewardLinesStepwise: one pass over steps — replay granted rows
## instantly, reveal the current step with animated glyphs, then grant it.
func _present_rewards_stepwise(gen: int) -> void:
	if gen != _presentation_gen:
		return
	var pending := _read_pending_payout()
	if not pending.is_valid() or pending.get_type() != GnosisValueType.OBJECT:
		_finish_presentation(gen, true)
		return
	if _node_bool(pending, "isComplete", false):
		_finish_presentation(gen, _rows.get_child_count() == 0)
		return
	var steps := pending.get_node("steps")
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST or steps.get_count() == 0:
		_finish_presentation(gen, true)
		return

	var next_idx := maxi(0, _node_int(pending, "nextStepIndex", 0))
	for i in range(steps.get_count()):
		if gen != _presentation_gen or not _presenting or not is_visible_in_tree():
			return
		var step := steps.get_node(i)
		if not step.is_valid() or step.get_type() != GnosisValueType.OBJECT:
			_finish_presentation(gen, _rows.get_child_count() == 0)
			return

		var reason_key := _node_str(step, "reasonKey")
		var amount := _node_int(step, "amount", 0)
		var granted := _node_bool(step, "granted", false)
		var reason := _localized(reason_key, reason_key)

		if granted:
			if amount > 0:
				await _spawn_row(gen, reason, amount, false)
			continue

		if i != next_idx:
			break
		if amount <= 0 or reason_key.strip_edges().is_empty():
			break

		await _spawn_row(gen, reason, amount, true)
		if gen != _presentation_gen:
			return
		await get_tree().create_timer(
			TuningScript.round_reward_step_pause_seconds(_engine()),
			true,
			false,
			true
		).timeout
		if gen != _presentation_gen:
			return

		var m3 = _match3_service()
		var eng := _engine()
		if m3 == null or eng == null:
			break
		var result = m3.invoke_function("GrantNextRoundRewardStep", eng.store.create_object())
		if not (result is GnosisFunctionResult) or not result.is_ok or not result.payload.is_valid():
			break
		if not _node_bool(result.payload, "success", true):
			break

		pending = _read_pending_payout()
		if not pending.is_valid() or pending.get_type() != GnosisValueType.OBJECT:
			break
		next_idx = maxi(0, _node_int(pending, "nextStepIndex", 0))
		await get_tree().process_frame

	_finish_presentation(gen, _rows.get_child_count() == 0)

func _finish_presentation(gen: int, show_empty: bool) -> void:
	if gen != _presentation_gen:
		return
	_presenting = false
	if _empty_label:
		_empty_label.visible = show_empty
	if not _actions_blocked():
		_set_continue_enabled(true)
	_sync_reward_scroll()
	_sync_reward_scroll()

func _spawn_row(gen: int, reason: String, amount: int, animate_money: bool) -> void:
	if gen != _presentation_gen or _rows == null:
		return
	var row := RewardRowView.new()
	_rows.add_child(row)
	if not row.is_node_ready():
		await row.ready
	await row.reveal_line(reason, amount, animate_money)
	_sync_reward_scroll()

func _on_continue_pressed() -> void:
	if _actions_blocked() or _presenting:
		return
	var eng := _engine()
	var m3 = _match3_service()
	var ui := _game_ui()
	if eng == null or m3 == null or ui == null:
		return
	var params := eng.store.create_object()
	params.set_key("gameStatus", "shopPanel")
	m3.invoke_function("TransitionToState", params)
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("refresh_hud_after_reward"):
		adapter.refresh_hud_after_reward()

func _node_int(node: GnosisNode, key: String, fallback: int) -> int:
	if node == null or not node.is_valid():
		return fallback
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return fallback
	return int(child.value)

func _node_str(node: GnosisNode, key: String) -> String:
	if node == null or not node.is_valid():
		return ""
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return ""
	return str(child.value)

func _node_bool(node: GnosisNode, key: String, fallback: bool) -> bool:
	if node == null or not node.is_valid():
		return fallback
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return fallback
	return bool(child.value)

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var translated := tr(key)
	return translated if translated != key else fallback
