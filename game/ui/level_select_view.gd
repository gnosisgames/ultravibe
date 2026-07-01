class_name UltravibeLevelSelectView
extends GnosisUIElementView

## Match3 planning overlay: shop shell (empty before round 1) above compact level cards.

const SubscreenFrame = preload("res://game/ui/subscreen_frame.gd")
const LevelCardBadge = preload("res://game/ui/widgets/level_card_badge.gd")
const RoundedSquareBtnScene = preload("res://game/ui/widgets/rounded_square_btn.tscn")
const TooltipPopupScene = preload("res://game/ui/widgets/tooltip_popup.tscn")
const ConsumableCatalogUi = preload("res://game/ui/consumable_catalog_ui.gd")
const SHOP_ROW_BG := Color(0.356863, 0.368627, 0.560784, 1)

const PANEL_BG := Color(0.415686, 0.415686, 0.658824, 1)
const PANEL_SHADOW := Color(0.0784314, 0.137255, 0.227451, 1)
const PANEL_RADIUS := 27
const PILL_DARK := Color(0.156863, 0.196078, 0.290196, 1)
const PILL_WHITE := Color(0.929412, 0.941176, 0.972549, 1)
const PILL_TEXT_DARK := Color(0.156863, 0.196078, 0.290196, 1)
const BTN_BLUE := Color(0.196078, 0.45098, 0.85098, 1)
const BTN_YELLOW := Color(0.968627, 0.78, 0.301961, 1)
const BTN_RED := Color(0.971387, 0.354281, 0.290535, 1)
const BTN_DISABLED_GREY := Color(0.52, 0.52, 0.56, 1)
const BTN_ICON_DISABLED := Color(0.78, 0.78, 0.82, 1)
const DEFAULT_DOUBLE_DOWN_MULT := 10
const GOLD := Color(0.937255, 0.74902, 0.0156863, 1)
const WHITE := Color(1, 1, 1, 1)
const PANEL_TEXT_OUTLINE := Color(0.176471, 0.184314, 0.305882, 1)
const PANEL_TEXT_SHADOW := Color(0.176471, 0.184314, 0.305882, 0.6)
const DESC_COLOR := Color(0.847059, 0.858824, 0.945098, 1)
const CARD_MIN_WIDTH := 240.0
const BADGE_SIDE_INSET := 64
const BADGE_OVERLAP := 18
const ACTION_BTN_SIZE := Vector2(88, 76)
const ACTION_BTN_ICON_MAX := 44
const REWARD_PANEL_HEIGHT := 72.0
const REWARD_ROW_MIN_WIDTH := 292.0
const REWARD_SECTION_TOP_MARGIN := 12
const REWARD_DIVIDER_WIDTH := 3
const REWARD_DIVIDER_INSET := 8.0
const REWARD_DOT_SIZE := 12
const REWARD_DOT_INSET := 4
const REWARD_PANEL_MARGIN_H := 6
const REWARD_PANEL_MARGIN_V := 4
const CHALLENGE_MULT_ROTATION := 30.0
const CHALLENGE_MULT_FONT_SIZE := 20
const REWARD_TOOLTIP_WIDTH := 300.0
const ICON_DIR := "res://addons/com.gnosisgames.gnosisengine/assets/Sprites/Icons/White/"
const SKULL_ICON := ICON_DIR + "skull-white.png"
const PLAY_ICON := ICON_DIR + "play.png"
const SKIP_ICON := ICON_DIR + "skip.png"

@onready var _region: Control = %Region
@onready var _shop_section: PanelContainer = %ShopSection
@onready var _shop_offers: VBoxContainer = %ShopOffers
@onready var _shop_reroll_button: Button = %ShopRerollButton
@onready var _cards: HBoxContainer = %Cards

var _font: Font = null
var _host: GnosisGodotEngine = null
var _tooltip: TooltipPopup = null
var _tooltip_anchor: Control = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_font = load("res://assets/fonts/Comic Lemon.otf")
	if _cards:
		_cards.alignment = BoxContainer.ALIGNMENT_END
	if _shop_reroll_button:
		_shop_reroll_button.pressed.connect(_on_shop_reroll_pressed)
		var reroll_key := "core__verb__reroll"
		_shop_reroll_button.text = tr(reroll_key) if tr(reroll_key) != reroll_key else "Reroll"
	if _shop_section:
		var shop_title := _shop_section.get_node_or_null("ShopVBox/ShopTitle") as Label
		if shop_title:
			shop_title.text = tr("core__noun__shop") if tr("core__noun__shop") != "core__noun__shop" else "Shop"
			_apply_font(shop_title, 40, WHITE)
	_build_tooltip()
	call_deferred("_resolve_host")

func get_subscreen_slide_holder() -> Control:
	return _region


func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		SubscreenFrame.connect_changes(self, _apply_frame)
		_apply_frame()
		_refresh()
	else:
		_hide_consumable_tooltip()

func _apply_frame() -> void:
	SubscreenFrame.apply_planning(self, _region)

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


func _shop_service():
	var eng := _engine()
	return eng.get_service("Match3Shop") if eng else null


func _refresh() -> void:
	_hide_consumable_tooltip()
	_refresh_shop()
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


func _refresh_shop() -> void:
	if _shop_section == null:
		return
	var m3 = _match3_service()
	if m3 == null:
		_shop_section.visible = false
		return
	_shop_section.visible = true
	var shop_available: bool = m3.has_method("is_shop_available") and m3.is_shop_available()
	if _shop_reroll_button:
		_shop_reroll_button.visible = true
		_shop_reroll_button.disabled = not shop_available
	_clear_shop_offers()
	if not shop_available:
		return
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		return
	var result = shop.invoke_function("GetCoreShop", eng.store.create_object())
	if not (result is GnosisFunctionResult) or not result.is_ok:
		return
	var offers: GnosisNode = result.payload.get_node("core.offers")
	if not offers.is_valid() or offers.get_type() != GnosisValueType.LIST:
		return
	for i in range(offers.get_count()):
		var offer: GnosisNode = offers.get_node(i)
		if not offer.is_valid():
			continue
		if _node_bool(offer, "purchased", false):
			continue
		_add_shop_offer_row(
			str(_node_str(offer, "sourceConfigId")),
			str(_node_str(offer, "itemId")),
			_node_int(offer, "price", 0),
			i,
		)


func _clear_shop_offers() -> void:
	if _shop_offers == null:
		return
	for child in _shop_offers.get_children():
		child.queue_free()


func _add_shop_offer_row(source: String, item_id: String, price: int, index: int) -> void:
	var panel := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = SHOP_ROW_BG
	box.set_corner_radius_all(12)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", box)
	var hbox := HBoxContainer.new()
	panel.add_child(hbox)
	var label := Label.new()
	label.text = "%s / %s" % [source, item_id]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_font(label, 22, WHITE)
	hbox.add_child(label)
	var buy := JuicyButton.new()
	buy.text = "$%d" % price
	if _font:
		buy.add_theme_font_override("font", _font)
	buy.add_theme_color_override("font_color", GOLD)
	buy.pressed.connect(_on_shop_buy_pressed.bind(index))
	hbox.add_child(buy)
	_shop_offers.add_child(panel)


func _on_shop_buy_pressed(index: int) -> void:
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		return
	var params := eng.store.create_object()
	params.set_key("index", index)
	shop.invoke_function("PurchaseCoreItem", params)
	_refresh()
	_refresh_hud()


func _on_shop_reroll_pressed() -> void:
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		return
	shop.invoke_function("RerollCoreShop", eng.store.create_object())
	_refresh()


func _refresh_hud() -> void:
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("refresh_hud_after_reward"):
		adapter.refresh_hud_after_reward()

# ---------------------------------------------------------------------------
# Card construction
# ---------------------------------------------------------------------------

func _build_card(row: GnosisNode) -> Control:
	var stage := _node_str(row, "stageType")
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
	var badge_accent := _badge_accent_color(row, stage)

	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(CARD_MIN_WIDTH, 0)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_SHRINK_END
	wrapper.alignment = BoxContainer.ALIGNMENT_CENTER
	wrapper.add_theme_constant_override("separation", -BADGE_OVERLAP)

	var badge := LevelCardBadge.build(
		skulls,
		_format_score(objective),
		badge_accent,
		_font,
		BADGE_OVERLAP
	)
	badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge.z_index = 1

	var badge_host := MarginContainer.new()
	badge_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_host.add_theme_constant_override("margin_left", BADGE_SIDE_INSET)
	badge_host.add_theme_constant_override("margin_right", BADGE_SIDE_INSET)
	badge_host.add_child(badge)
	wrapper.add_child(badge_host)

	var card := PanelContainer.new()
	card.z_index = 0
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _card_style(is_current))

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	vbox.add_child(_title_label(name_text))
	vbox.add_child(_desc_label(desc_text))
	vbox.add_child(_buttons_row(is_current, skippable, double_down_mult))
	vbox.add_child(_action_rewards_row(reward, consumable_id))

	wrapper.add_child(card)

	return wrapper

func _title_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_apply_font(label, 26, WHITE)
	return label

func _desc_label(text: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = TooltipPopup.format_bbcode(text)
	label.add_theme_color_override("default_color", DESC_COLOR)
	if _font:
		label.add_theme_font_override("normal_font", _font)
	label.add_theme_font_size_override("normal_font_size", 16)
	return label

func _action_rewards_row(reward: int, consumable_id: String) -> Control:
	var wrap := MarginContainer.new()
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.add_theme_constant_override("margin_top", REWARD_SECTION_TOP_MARGIN)

	var root := Control.new()
	root.custom_minimum_size = Vector2(REWARD_ROW_MIN_WIDTH, REWARD_PANEL_HEIGHT)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer := PanelContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_stylebox_override("panel", _rounded_style(PILL_DARK, 14, REWARD_PANEL_MARGIN_V, REWARD_PANEL_MARGIN_H))
	root.add_child(outer)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(row)

	row.add_child(_reward_money_side(reward))

	var preview := ConsumableCatalogUi.build_level_preview(_engine(), consumable_id)
	if not preview.is_empty():
		row.add_child(_reward_divider())
		row.add_child(_reward_consumable_side(preview))

	wrap.add_child(root)
	return wrap


func _reward_money_side(reward: int) -> Control:
	var side := Control.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = ConsumableCatalogUi.format_level_money_reward(reward)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_font(label, 30, GOLD)
	center.add_child(label)
	side.add_child(center)
	side.add_child(_reward_corner_dots([BTN_BLUE, BTN_RED], true))
	return side


func _reward_consumable_side(preview: Dictionary) -> Control:
	var side := Control.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_path := str(preview.get("icon_path", ""))
	if not icon_path.is_empty():
		center.add_child(_consumable_reward_button(icon_path, preview))
	side.add_child(center)
	side.add_child(_reward_corner_dots([BTN_YELLOW, BTN_RED], false))
	return side


func _consumable_reward_button(icon_path: String, preview: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.texture = load(icon_path)
	icon.custom_minimum_size = Vector2(42, 42)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_CENTER)
	icon.offset_left = -21.0
	icon.offset_top = -21.0
	icon.offset_right = 21.0
	icon.offset_bottom = 21.0
	btn.add_child(icon)

	btn.mouse_entered.connect(btn.grab_focus)
	btn.focus_entered.connect(func() -> void: _show_consumable_tooltip(btn, preview))
	btn.focus_exited.connect(_on_consumable_focus_exited)
	return btn


func _reward_divider() -> Control:
	var wrap := MarginContainer.new()
	wrap.add_theme_constant_override("margin_top", REWARD_DIVIDER_INSET)
	wrap.add_theme_constant_override("margin_bottom", REWARD_DIVIDER_INSET)
	wrap.custom_minimum_size = Vector2(REWARD_DIVIDER_WIDTH, 0)
	wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(REWARD_DIVIDER_WIDTH, 0)
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.color = Color(1, 1, 1, 0.18)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(line)
	return wrap


func _reward_corner_dots(colors: Array[Color], top_left: bool) -> Control:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 1

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_top", REWARD_DOT_INSET)
	if top_left:
		margin.add_theme_constant_override("margin_left", REWARD_DOT_INSET)
	else:
		margin.add_theme_constant_override("margin_right", REWARD_DOT_INSET)

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if top_left else BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 3)
	for color in colors:
		row.add_child(_reward_dot(color))
	margin.add_child(row)
	layer.add_child(margin)
	return layer


func _reward_dot(color: Color) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(REWARD_DOT_SIZE, REWARD_DOT_SIZE)
	dot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(REWARD_DOT_SIZE / 2)
	dot.add_theme_stylebox_override("panel", style)
	return dot


func _build_tooltip() -> void:
	if _tooltip != null:
		return
	_tooltip = TooltipPopupScene.instantiate() as TooltipPopup
	_tooltip.name = "ConsumableTooltip"
	_tooltip.top_level = true
	_tooltip.z_index = 100
	_tooltip.visible = false
	_tooltip.scale = Vector2.ZERO
	add_child(_tooltip)


func _show_consumable_tooltip(anchor: Control, preview: Dictionary) -> void:
	if _tooltip == null or anchor == null or not is_instance_valid(anchor):
		return
	var description := str(preview.get("description", "")).strip_edges()
	if description.is_empty():
		return
	_tooltip_anchor = anchor
	_tooltip.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tooltip.grow_horizontal = Control.GROW_DIRECTION_END
	_tooltip.grow_vertical = Control.GROW_DIRECTION_END
	_tooltip.visible = true
	_tooltip.set_content(
		str(preview.get("title", "")),
		description,
		REWARD_TOOLTIP_WIDTH,
		preview.get("tags", [])
	)
	call_deferred("_finalize_consumable_tooltip")


func _finalize_consumable_tooltip() -> void:
	if _tooltip == null or _tooltip_anchor == null or not is_instance_valid(_tooltip_anchor):
		return
	_tooltip.reset_size()
	call_deferred("_position_and_appear_consumable_tooltip")


func _position_and_appear_consumable_tooltip() -> void:
	if _tooltip == null or _tooltip_anchor == null or not is_instance_valid(_tooltip_anchor):
		return
	_position_consumable_tooltip(_tooltip_anchor)
	_tooltip.appear()


func _position_consumable_tooltip(anchor: Control) -> void:
	if _tooltip == null or anchor == null or not is_instance_valid(anchor):
		return
	var anchor_rect := anchor.get_global_rect()
	var bounds := _region.get_global_rect() if _region else get_global_rect()
	var tooltip_size := _tooltip.get_combined_minimum_size()
	tooltip_size.x = maxf(tooltip_size.x, _tooltip.size.x)
	tooltip_size.y = maxf(tooltip_size.y, _tooltip.size.y)
	tooltip_size.x = minf(tooltip_size.x, bounds.size.x - 16.0)
	tooltip_size.y = minf(tooltip_size.y, bounds.size.y - 16.0)
	var min_y := bounds.position.y + 8.0
	var max_y := maxf(min_y, bounds.end.y - tooltip_size.y - 8.0)
	var x := anchor_rect.position.x + (anchor_rect.size.x - tooltip_size.x) * 0.5
	var y := anchor_rect.position.y - tooltip_size.y - 12.0
	if y < min_y:
		y = anchor_rect.end.y + 12.0
	x = clampf(x, bounds.position.x + 8.0, maxf(bounds.position.x + 8.0, bounds.end.x - tooltip_size.x - 8.0))
	y = clampf(y, min_y, max_y)
	_tooltip.global_position = Vector2(x, y)
	_tooltip.pivot_offset = Vector2(tooltip_size.x * 0.5, tooltip_size.y)


func _on_consumable_focus_exited() -> void:
	call_deferred("_hide_consumable_tooltip_if_unfocused")


func _hide_consumable_tooltip_if_unfocused() -> void:
	if _tooltip_anchor != null and is_instance_valid(_tooltip_anchor) and _tooltip_anchor.has_focus():
		return
	_hide_consumable_tooltip()


func _hide_consumable_tooltip() -> void:
	_tooltip_anchor = null
	if _tooltip:
		_tooltip.disappear()

func _buttons_row(is_current: bool, skippable: bool, double_down_mult: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var play := _action_button(PLAY_ICON, "", BTN_BLUE, is_current)
	play.pressed.connect(_on_play_pressed)
	row.add_child(_action_button_slot(play))

	var skip := _action_button(SKIP_ICON, "", BTN_YELLOW, is_current and skippable)
	skip.pressed.connect(_on_skip_pressed)
	row.add_child(_action_button_slot(skip))

	var mult := maxi(1, double_down_mult if double_down_mult > 0 else DEFAULT_DOUBLE_DOWN_MULT)
	var challenge := _action_button(SKULL_ICON, "", BTN_RED, is_current)
	challenge.pressed.connect(_on_double_down_pressed)
	row.add_child(_action_button_slot(challenge, "x%d" % mult))
	return row


func _action_button_slot(btn: Button, overlay_label: String = "") -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = ACTION_BTN_SIZE
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE

	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.offset_right = 0.0
	btn.offset_bottom = 0.0
	slot.add_child(btn)

	if not overlay_label.is_empty():
		var mult_label := Label.new()
		mult_label.text = overlay_label
		mult_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mult_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mult_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		mult_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mult_label.offset_left = -56.0
		mult_label.offset_top = 0.0
		mult_label.offset_right = 22.0
		mult_label.offset_bottom = 28.0
		mult_label.rotation_degrees = CHALLENGE_MULT_ROTATION
		mult_label.z_index = 1
		_apply_font(mult_label, CHALLENGE_MULT_FONT_SIZE, WHITE)
		slot.add_child(mult_label)
		mult_label.resized.connect(func() -> void:
			mult_label.pivot_offset = Vector2(mult_label.size.x, 0.0)
		)
		mult_label.pivot_offset = Vector2(48.0, 0.0)

	return slot


func _action_button(icon_path: String, label: String, base_color: Color, enabled: bool) -> Button:
	var btn: RoundedSquareBtn = RoundedSquareBtnScene.instantiate()
	btn.custom_minimum_size = ACTION_BTN_SIZE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.icon = load(icon_path)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.text = label
	btn.disabled = not enabled
	btn.hover_animate = true
	btn.add_theme_constant_override("icon_max_width", ACTION_BTN_ICON_MAX)
	var icon_color := WHITE if enabled else BTN_ICON_DISABLED
	btn.add_theme_color_override("icon_normal_color", icon_color)
	btn.add_theme_color_override("icon_hover_color", icon_color)
	btn.add_theme_color_override("icon_pressed_color", icon_color)
	btn.add_theme_color_override("icon_disabled_color", BTN_ICON_DISABLED)
	btn.add_theme_color_override("font_color", icon_color)
	btn.add_theme_color_override("font_disabled_color", BTN_ICON_DISABLED)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.add_theme_font_size_override("font_size", 20)
	_apply_juicy_button_styles(btn, base_color, enabled)
	return btn


func _apply_juicy_button_styles(btn: Button, base_color: Color, enabled: bool) -> void:
	var inactive_fill := base_color.lerp(BTN_DISABLED_GREY, 0.72)
	var active_shadow := _button_shadow_color(base_color)
	var inactive_shadow := _button_shadow_color(inactive_fill)
	btn.add_theme_stylebox_override("normal", _juicy_button_style(
		base_color if enabled else inactive_fill,
		active_shadow if enabled else inactive_shadow
	))
	btn.add_theme_stylebox_override("hover", _juicy_button_style(
		base_color.lightened(0.08), active_shadow, true
	))
	btn.add_theme_stylebox_override("pressed", _juicy_button_style(
		base_color.darkened(0.12), active_shadow
	))
	btn.add_theme_stylebox_override("disabled", _juicy_button_style(inactive_fill, inactive_shadow))
	btn.add_theme_stylebox_override("focus", _juicy_button_style(
		base_color if enabled else inactive_fill,
		active_shadow if enabled else inactive_shadow,
		true
	))


func _button_shadow_color(base: Color) -> Color:
	return base.darkened(0.42)


func _juicy_button_style(bg: Color, shadow: Color, outlined: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(16)
	box.corner_detail = 12
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	box.shadow_color = shadow
	box.shadow_size = 1
	box.shadow_offset = Vector2(3, 4)
	if outlined:
		box.set_border_width_all(4)
		box.border_color = bg.darkened(0.35)
	return box


# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------

func _card_style(_is_current: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(PANEL_RADIUS)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 22
	box.content_margin_bottom = 20
	box.shadow_color = PANEL_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(5, 7)
	return box


func _badge_accent_color(row: GnosisNode, stage: String) -> Color:
	if stage != "boss":
		return PILL_TEXT_DARK
	var hex := _node_str(row, "textColor").strip_edges()
	if hex.is_empty() or not hex.begins_with("#") or not Color.html_is_valid(hex):
		return PILL_TEXT_DARK
	return Color.html(hex)


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
	var outline_size := maxi(8, int(round(float(size) * 0.38)))
	label.add_theme_color_override("font_outline_color", PANEL_TEXT_OUTLINE)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_shadow_color", PANEL_TEXT_SHADOW)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)

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
