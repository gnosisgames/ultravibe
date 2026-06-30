class_name UltravibeLevelSelectView
extends GnosisUIElementView

## Match3 level selector overlay (Unity LevelSelectorPanel parity). Shows the
## queued floor preview and starts the next round via Match3.PlayLevel.

const ROW_BG := Color(0.356863, 0.368627, 0.560784, 1)

@onready var _rounds: VBoxContainer = %Rounds
@onready var _play_button: Button = %PlayButton
@onready var _double_down_button: Button = %DoubleDownButton
@onready var _skip_button: Button = %SkipButton
@onready var _card: PanelContainer = $Center/Card

var _row_font: Font = null
var _host: GnosisGodotEngine = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_row_font = load("res://assets/fonts/Comic Lemon.otf")
	_play_button.pressed.connect(_on_play_pressed)
	_double_down_button.pressed.connect(_on_double_down_pressed)
	_skip_button.pressed.connect(_on_skip_pressed)
	call_deferred("_resolve_host")

func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		_refresh()

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
	if _rounds == null:
		return
	for child in _rounds.get_children():
		child.queue_free()
	var eng := _engine()
	if eng == null or eng.state == null:
		return
	var match3 := eng.state.root.get_node("Ephemeral").get_node("match3")
	if not match3.is_valid():
		return
	var planned := match3.get_node("plannedFloor")
	if not planned.is_valid():
		return
	var rounds := planned.get_node("rounds")
	if not rounds.is_valid() or rounds.get_type() != GnosisValueType.LIST:
		return
	var current_skippable := false
	var double_down_mult := 0
	for i in range(rounds.get_count()):
		var row := rounds.get_node(i)
		if not row.is_valid():
			continue
		var stage := _node_str(row, "stageType").to_upper()
		var round_num := _node_int(row, "round", 0)
		var reward := _node_int(row, "rewardAmount", 0)
		var current := _node_bool(row, "isCurrent", false)
		if current:
			current_skippable = _node_bool(row, "isSkippable", false)
			double_down_mult = _node_int(row, "doubleDownTargetScoreMultiplier", 0)
		_add_round_row(stage, round_num, reward, current)
	_configure_action_buttons(current_skippable, double_down_mult)

func _configure_action_buttons(skippable: bool, double_down_mult: int) -> void:
	if _skip_button:
		_skip_button.visible = skippable
	if _double_down_button:
		_double_down_button.visible = double_down_mult > 1
		if double_down_mult > 1:
			_double_down_button.text = "x%d" % double_down_mult

func _add_round_row(stage: String, round_num: int, reward: int, is_current: bool) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = ROW_BG
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	var label := Label.new()
	label.text = "R%d %s%s" % [
		round_num,
		stage,
		" *" if is_current else "",
	]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _row_font:
		label.add_theme_font_override("font", _row_font)
	label.add_theme_font_size_override("font_size", 24)
	hbox.add_child(label)
	var money := Label.new()
	money.text = "$".repeat(maxi(0, reward))
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _row_font:
		money.add_theme_font_override("font", _row_font)
	money.add_theme_font_size_override("font_size", 24)
	hbox.add_child(money)
	_rounds.add_child(panel)

func _on_play_pressed() -> void:
	_play(false)

func _on_double_down_pressed() -> void:
	_play(true)

func _play(double_down: bool) -> void:
	var eng := _engine()
	var m3 = _match3_service()
	var ui := _game_ui()
	if eng == null or m3 == null or ui == null:
		return
	var params := eng.store.create_object()
	params.set_key("doubleDown", double_down)
	m3.invoke_function("PlayLevel", params)
	_dismiss_overlays(ui, eng)

func _on_skip_pressed() -> void:
	var eng := _engine()
	var m3 = _match3_service()
	if eng == null or m3 == null:
		return
	var result = m3.invoke_function("SkipLevel", eng.store.create_object())
	if result is GnosisFunctionResult and result.is_ok and _node_bool(result.payload, "success", false):
		_refresh()

func _dismiss_overlays(ui: GnosisGameUIService, eng: GnosisEngine) -> void:
	for _i in 4:
		var has_overlay := false
		for view_id in ["level_select", "shop", "reward", "game_over"]:
			if not ui.get_active_overlay_state_for_view(view_id).is_empty():
				has_overlay = true
				break
		if not has_overlay:
			return
		ui.invoke_function("PopView", eng.store.create_object())

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
