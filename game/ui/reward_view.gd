class_name UltravibeRewardView
extends GnosisUIElementView

## Round reward overlay (Unity RoundPanel parity). Shows the pending round payout
## as a column of rows — localized reason on the left, money as "$" glyphs on the
## right — over a dimmed board, with a Continue button to proceed to the next round.

## Money glyph color (gold), matching the Unity reward rows and HUD money readout.
const MONEY_COLOR := Color(0.937255, 0.74902, 0.0156863, 1)
const ROW_BG := Color(0.356863, 0.368627, 0.560784, 1)

## Brief lockout so the input burst that wins a round cannot instantly fire
## Continue on the same frame.
const ACTION_COOLDOWN_SEC := 0.6

@onready var _rows: VBoxContainer = %RewardRows
@onready var _empty_label: Label = %EmptyLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _card: PanelContainer = $Center/Card

var _row_font: Font = null
var _host: GnosisGodotEngine = null
var _actions_ready_at := 0.0
var _action_cooldown_timer: SceneTreeTimer = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_row_font = load("res://assets/fonts/Comic Lemon.otf")
	_continue_button.pressed.connect(_on_continue_pressed)
	_set_continue_enabled(false)
	call_deferred("_resolve_host")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_rebuild_rows()

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		_play_card_intro()
		_arm_action_cooldown()
		_rebuild_rows()
	else:
		_cancel_action_cooldown()

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
	_set_continue_enabled(true)

func _set_continue_enabled(enabled: bool) -> void:
	if _continue_button:
		_continue_button.disabled = not enabled

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
	_rebuild_rows()

func _engine() -> GnosisEngine:
	return _host.engine if _host else null

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

## Clears and repopulates the reward rows from the pending payout steps in
## ephemeral state. Each step contributes a "reason -> $glyphs" row.
func _rebuild_rows() -> void:
	if _rows == null:
		return
	for child in _rows.get_children():
		child.queue_free()
	var steps := _read_reward_steps()
	if _empty_label:
		_empty_label.visible = steps.is_empty()
	for step in steps:
		_add_row(step.get("reason", ""), int(step.get("amount", 0)))

## Reads Ephemeral.match3.pendingRoundReward.steps into an array of
## { reason: <localized>, amount: <int> } dictionaries.
func _read_reward_steps() -> Array:
	var result: Array = []
	var eng := _engine()
	if eng == null or eng.state == null or not eng.state.root.is_valid():
		return result
	var ephemeral := eng.state.root.get_node("Ephemeral")
	if not ephemeral.is_valid() or ephemeral.get_type() != GnosisValueType.OBJECT:
		return result
	var match3 := ephemeral.get_node("match3")
	if not match3.is_valid() or match3.get_type() != GnosisValueType.OBJECT:
		return result
	var pending := match3.get_node("pendingRoundReward")
	if not pending.is_valid() or pending.get_type() != GnosisValueType.OBJECT:
		return result
	var steps := pending.get_node("steps")
	if not steps.is_valid() or steps.get_type() != GnosisValueType.LIST:
		return result
	for i in range(steps.get_count()):
		var step := steps.get_node(i)
		if not step.is_valid() or step.get_type() != GnosisValueType.OBJECT:
			continue
		var amount := _node_int(step, "amount", 0)
		if amount <= 0:
			continue
		var reason_key := _node_str(step, "reasonKey")
		result.append({
			"reason": _localized(reason_key, reason_key),
			"amount": amount,
		})
	return result

## Builds a single reward row: a dark rounded panel holding the reason label on
## the left and the gold money glyphs ("$" x amount) on the right.
func _add_row(reason: String, amount: int) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_BG
	box.set_corner_radius_all(14)
	box.content_margin_left = 22
	box.content_margin_right = 22
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", box)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	var reason_label := Label.new()
	reason_label.text = reason
	reason_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason_label.add_theme_color_override("font_color", Color.WHITE)
	if _row_font:
		reason_label.add_theme_font_override("font", _row_font)
	reason_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(reason_label)

	var money_label := Label.new()
	money_label.text = "$".repeat(amount)
	money_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money_label.add_theme_color_override("font_color", MONEY_COLOR)
	if _row_font:
		money_label.add_theme_font_override("font", _row_font)
	money_label.add_theme_font_size_override("font_size", 26)
	hbox.add_child(money_label)

	_rows.add_child(panel)

## Continue: close the reward overlay (revealing gameplay) and advance the run.
## TODO(ultravibe-port): grant pending reward steps + advance to the next round
## once the Match3 round-reward pipeline is ported.
func _on_continue_pressed() -> void:
	if _actions_blocked():
		return
	var ui := _game_ui()
	if ui:
		ui.invoke_function("PopView", _engine().store.create_object())

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

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var translated := tr(key)
	return translated if translated != key else fallback
