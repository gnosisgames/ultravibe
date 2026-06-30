class_name UltravibeShopView
extends GnosisUIElementView

## Match3 shop overlay shell (Unity ShopPanel parity). Lists core offers from
## Match3Shop and advances to the level-select panel on continue.

const SubscreenFrame = preload("res://game/ui/subscreen_frame.gd")
const ROW_BG := Color(0.356863, 0.368627, 0.560784, 1)
const MONEY_COLOR := Color(0.937255, 0.74902, 0.0156863, 1)

@onready var _offers: VBoxContainer = %Offers
@onready var _money_label: Label = %MoneyLabel
@onready var _reroll_button: Button = %RerollButton
@onready var _continue_button: Button = %ContinueButton
@onready var _center: Control = %Center
@onready var _card: PanelContainer = $Center/Card

var _row_font: Font = null
var _host: GnosisGodotEngine = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_row_font = load("res://assets/fonts/Comic Lemon.otf")
	_reroll_button.pressed.connect(_on_reroll_pressed)
	_continue_button.pressed.connect(_on_continue_pressed)
	call_deferred("_resolve_host")

func get_subscreen_slide_holder() -> Control:
	return _center


func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		if _card:
			_card.scale = Vector2.ONE
			_card.modulate.a = 1.0
		SubscreenFrame.connect_changes(self, _apply_frame)
		_apply_frame()
		_refresh()

func _apply_frame() -> void:
	SubscreenFrame.apply(self, _center)

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

func _match3_service():
	var eng := _engine()
	return eng.get_service("Match3") if eng else null

func _shop_service():
	var eng := _engine()
	return eng.get_service("Match3Shop") if eng else null

func _refresh() -> void:
	var m3 = _match3_service()
	if m3 and m3.has_method("get_money") and _money_label:
		_money_label.text = "$%d" % m3.get_money()
	_clear_offers()
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
		_add_offer_row(
			str(_node_str(offer, "sourceConfigId")),
			str(_node_str(offer, "itemId")),
			_node_int(offer, "price", 0),
			i,
		)

func _clear_offers() -> void:
	if _offers == null:
		return
	for child in _offers.get_children():
		child.queue_free()

func _add_offer_row(source: String, item_id: String, price: int, index: int) -> void:
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
	label.text = "%s / %s" % [source, item_id]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _row_font:
		label.add_theme_font_override("font", _row_font)
	label.add_theme_font_size_override("font_size", 22)
	hbox.add_child(label)
	var buy := JuicyButton.new()
	buy.text = "$%d" % price
	if _row_font:
		buy.add_theme_font_override("font", _row_font)
	buy.add_theme_color_override("font_color", MONEY_COLOR)
	buy.pressed.connect(_on_buy_pressed.bind(index))
	hbox.add_child(buy)
	_offers.add_child(panel)

func _on_buy_pressed(index: int) -> void:
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		return
	var params := eng.store.create_object()
	params.set_key("index", index)
	shop.invoke_function("PurchaseCoreItem", params)
	_refresh()
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("refresh_hud_after_reward"):
		adapter.refresh_hud_after_reward()

func _on_reroll_pressed() -> void:
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		return
	shop.invoke_function("RerollCoreShop", eng.store.create_object())
	_refresh()

func _on_continue_pressed() -> void:
	var eng := _engine()
	var m3 = _match3_service()
	var ui := _game_ui()
	if eng == null or m3 == null or ui == null:
		return
	var params := eng.store.create_object()
	params.set_key("gameStatus", "levelSelectPanel")
	m3.invoke_function("TransitionToState", params)
	ui.invoke_function("PopView", eng.store.create_object())
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("refresh_hud_after_reward"):
		adapter.refresh_hud_after_reward()

func _game_ui() -> GnosisGameUIService:
	var eng := _engine()
	return eng.get_service("GameUI") as GnosisGameUIService if eng else null

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
