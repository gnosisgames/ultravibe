class_name UltravibeLevelSelectView
extends GnosisUIElementView

## Match3 level selector overlay (Unity LevelSelectorPanel parity). Renders the
## queued floor as a row of level cards in the board play area (to the right of
## the HUD sidebar, not a fullscreen modal). Each card shows difficulty skulls,
## required score, name/description, the round reward and the play / double-down /
## skip actions. The green shop button re-opens the shop panel.

const SubscreenFrame = preload("res://game/ui/subscreen_frame.gd")
const RoundedSquareBtnScene = preload("res://game/ui/widgets/rounded_square_btn.tscn")
const ICON_DIR := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/"
const SKULL_ICON := ICON_DIR + "skull-white.png"
const PLAY_ICON := ICON_DIR + "play.png"
const CHEVRON_UP_ICON := ICON_DIR + "up.png"
const CHEVRON_DOWN_ICON := ICON_DIR + "down.png"
const CONSUMABLE_ICON_DIR := "res://assets/icons/consumables/"

const PANEL_BG := Color(0.415686, 0.415686, 0.658824, 1)
const PANEL_SHADOW := Color(0.0784314, 0.137255, 0.227451, 1)
const PANEL_RADIUS := 27
const PILL_DARK := Color(0.156863, 0.196078, 0.290196, 1)
const PILL_WHITE := Color(0.929412, 0.941176, 0.972549, 1)
const PILL_TEXT_DARK := Color(0.156863, 0.196078, 0.290196, 1)
const YELLOW := Color(0.968627, 0.78, 0.301961, 1)
const RED := Color(0.858824, 0.301961, 0.34902, 1)
const GOLD := Color(0.937255, 0.74902, 0.0156863, 1)
const WHITE := Color(1, 1, 1, 1)
const DESC_COLOR := Color(0.847059, 0.858824, 0.945098, 1)
const CARD_MIN_WIDTH := 240.0

@onready var _region: Control = %Region
@onready var _cards: HBoxContainer = %Cards

var _font: Font = null
var _host: GnosisGodotEngine = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_font = load("res://assets/fonts/Comic Lemon.otf")
	call_deferred("_resolve_host")

func get_subscreen_slide_holder() -> Control:
	return _region


func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		SubscreenFrame.connect_changes(self, _apply_frame)
		_apply_frame()
		_refresh()

func _apply_frame() -> void:
	SubscreenFrame.apply(self, _region)

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
	if _cards == null:
		return
	for child in _cards.get_children():
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
	for i in range(rounds.get_count()):
		var row := rounds.get_node(i)
		if not row.is_valid():
			continue
		_cards.add_child(_build_card(row))

# ---------------------------------------------------------------------------
# Card construction
# ---------------------------------------------------------------------------

func _build_card(row: GnosisNode) -> Control:
	var stage := _node_str(row, "stageType")
	var round_num := _node_int(row, "round", 0)
	var skulls := _node_int(row, "difficultySkulls", 1)
	var objective := _node_int(row, "objectiveTarget", 0)
	var reward := _node_int(row, "rewardAmount", 0)
	var is_current := _node_bool(row, "isCurrent", false)
	var skippable := _node_bool(row, "isSkippable", false)
	var double_down_mult := _node_int(row, "doubleDownTargetScoreMultiplier", 0)
	var consumable_id := _node_str(row, "roundActionRewardConsumableId")
	var name_text := _localized(_node_str(row, "nameKey"), stage.capitalize())
	if stage == "normal" or stage == "advanced":
		name_text = "%s %s" % [name_text, tr("core__noun__level") if tr("core__noun__level") != "core__noun__level" else "Level"]
	var desc_text := _localized(_node_str(row, "descriptionKey"), "")

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_FILL
	card.add_theme_stylebox_override("panel", _card_style(is_current))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	card.add_child(vbox)

	vbox.add_child(_skulls_row(skulls))
	vbox.add_child(_pill(_format_score(objective), PILL_DARK, WHITE, 32))
	vbox.add_child(_title_label(name_text))
	vbox.add_child(_desc_label(desc_text))
	vbox.add_child(_chevron(CHEVRON_UP_ICON))
	vbox.add_child(_reward_row(reward, consumable_id))
	vbox.add_child(_chevron(CHEVRON_DOWN_ICON))
	vbox.add_child(_buttons_row(is_current, skippable, double_down_mult))
	vbox.add_child(_round_pill(round_num))
	return card

func _skulls_row(count: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for _i in range(maxi(1, count)):
		var skull := TextureRect.new()
		skull.texture = load(SKULL_ICON)
		skull.custom_minimum_size = Vector2(38, 38)
		skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		skull.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(skull)
	return row

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(label, 30, WHITE)
	return label

func _desc_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, 84)
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_font(label, 18, DESC_COLOR)
	return label

func _chevron(icon_path: String) -> Control:
	var center := CenterContainer.new()
	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(34, 22)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = Color(1, 1, 1, 0.7)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	return center

func _reward_row(reward: int, consumable_id: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)

	var money_pill := _pill("$%d" % maxi(0, reward), PILL_DARK, GOLD, 34)
	row.add_child(money_pill)

	var consumable_path := _consumable_icon_path(consumable_id)
	if not consumable_path.is_empty():
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", _rounded_style(PILL_DARK, 14, 8))
		var icon := TextureRect.new()
		icon.texture = load(consumable_path)
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		row.add_child(slot)
	return row

func _buttons_row(is_current: bool, skippable: bool, double_down_mult: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)

	var play := _action_button(PLAY_ICON, "", YELLOW, is_current)
	play.pressed.connect(_on_play_pressed)
	row.add_child(play)

	if double_down_mult > 1:
		var dd := _action_button(PLAY_ICON, "x%d" % double_down_mult, YELLOW, is_current)
		dd.pressed.connect(_on_double_down_pressed)
		row.add_child(dd)

	if skippable:
		var skip := _action_button(SKULL_ICON, "", RED, is_current)
		skip.pressed.connect(_on_skip_pressed)
		row.add_child(skip)
	return row

func _action_button(icon_path: String, label: String, color: Color, enabled: bool) -> Button:
	var btn: RoundedSquareBtn = RoundedSquareBtnScene.instantiate()
	btn.custom_minimum_size = Vector2(72, 72)
	btn.icon = load(icon_path)
	btn.expand_icon = true
	btn.text = label
	btn.disabled = not enabled
	btn.add_theme_constant_override("icon_max_width", 36)
	btn.add_theme_color_override("icon_normal_color", WHITE)
	btn.add_theme_color_override("icon_hover_color", WHITE)
	btn.add_theme_color_override("icon_pressed_color", WHITE)
	btn.add_theme_color_override("icon_disabled_color", WHITE)
	btn.add_theme_color_override("font_color", WHITE)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 20)
	var style := _rounded_style(color, 16, 8)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", _rounded_style(color.lightened(0.08), 16, 8))
	btn.add_theme_stylebox_override("pressed", _rounded_style(color.darkened(0.12), 16, 8))
	btn.add_theme_stylebox_override("disabled", _rounded_style(color.darkened(0.25), 16, 8))
	btn.add_theme_stylebox_override("focus", style)
	if not enabled:
		btn.modulate.a = 0.6
	return btn

func _pill(text: String, bg: Color, fg: Color, font_size: int) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.add_theme_stylebox_override("panel", _rounded_style(bg, 18, 10, 22))
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(label, font_size, fg)
	pill.add_child(label)
	return pill

func _round_pill(round_num: int) -> Control:
	var center := CenterContainer.new()
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", _rounded_style(PILL_WHITE, 14, 8, 26))
	var label := Label.new()
	label.text = "-%d-" % round_num
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_apply_font(label, 24, PILL_TEXT_DARK)
	pill.add_child(label)
	center.add_child(pill)
	return center

# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------

func _card_style(_is_current: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(PANEL_RADIUS)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 24
	box.content_margin_bottom = 24
	box.shadow_color = PANEL_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 7)
	return box

func _rounded_style(bg: Color, radius: int, margin_v: int, margin_h: int = -1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(radius)
	box.content_margin_top = margin_v
	box.content_margin_bottom = margin_v
	box.content_margin_left = margin_v if margin_h < 0 else margin_h
	box.content_margin_right = margin_v if margin_h < 0 else margin_h
	return box

func _apply_font(label: Label, size: int, color: Color) -> void:
	if _font:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)

func _consumable_icon_path(consumable_id: String) -> String:
	if consumable_id.strip_edges().is_empty():
		return ""
	var candidates := [consumable_id, consumable_id.capitalize().replace(" ", "")]
	for candidate in candidates:
		var path := "%s%s.png" % [CONSUMABLE_ICON_DIR, candidate]
		if ResourceLoader.exists(path):
			return path
	return ""

func _format_score(value: int) -> String:
	if value >= 1000000:
		var millions := float(value) / 1000000.0
		return ("%.1fM" % millions).replace(".0M", "M")
	if value >= 1000:
		return "%dK" % int(value / 1000.0)
	return str(value)

# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

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

# ---------------------------------------------------------------------------
# Node helpers
# ---------------------------------------------------------------------------

func _localized(key: String, fallback: String) -> String:
	if key.strip_edges().is_empty():
		return fallback
	var translated := tr(key)
	return translated if translated != key else fallback

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
