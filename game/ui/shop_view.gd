class_name UltravibeShopView
extends GnosisUIElementView

## Match3 shop overlay (legacy). Shop UI now lives inside the level-select panel;
## this view is kept registered but is no longer pushed by the play adapter.

const SubscreenFrame = preload("res://game/ui/subscreen_frame.gd")
const ShopCatalogUi = preload("res://game/ui/shop_catalog_ui.gd")
const ShopOfferCard = preload("res://game/ui/widgets/shop_offer_card.gd")
const ShopRerollCard = preload("res://game/ui/widgets/shop_reroll_card.gd")

@onready var _offers: HBoxContainer = %Offers
@onready var _continue_button: Button = %ContinueButton
@onready var _center: Control = %Center
@onready var _card: PanelContainer = $Center/Card

var _row_font: Font = null
var _host: GnosisGodotEngine = null
var _shop_reroll_card: ShopRerollCard = null

func _ready() -> void:
	add_to_group("gnosis_ui_view")
	_row_font = load("res://assets/fonts/Comic Lemon.otf")
	_ensure_shop_reroll_card()
	_continue_button.pressed.connect(_on_continue_pressed)
	call_deferred("_resolve_host")


func _ensure_shop_reroll_card() -> void:
	if _shop_reroll_card != null:
		return
	_shop_reroll_card = ShopRerollCard.new()
	_shop_reroll_card.reroll_pressed.connect(_on_reroll_pressed)


func _shop_reroll_title() -> String:
	var key := "core__verb__reroll"
	var translated := tr(key)
	return translated if translated != key else "Reroll"


func _attach_shop_reroll_card() -> void:
	if _shop_reroll_card == null or _offers == null:
		return
	if _shop_reroll_card.get_parent() != _offers:
		_offers.add_child(_shop_reroll_card)
	_offers.move_child(_shop_reroll_card, 0)

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
	else:
		SubscreenFrame.disconnect_changes(self, _apply_frame)

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
	_ensure_shop_reroll_card()
	_clear_offers()
	var shop = _shop_service()
	var eng := _engine()
	if shop == null or eng == null:
		if _shop_reroll_card:
			_shop_reroll_card.configure(_row_font, _shop_reroll_title(), "", false)
		return
	var result = shop.invoke_function("GetCoreShop", eng.store.create_object())
	if not (result is GnosisFunctionResult) or not result.is_ok:
		if _shop_reroll_card:
			_shop_reroll_card.configure(_row_font, _shop_reroll_title(), "", false)
		return
	var core: GnosisNode = result.payload.get_node("core")
	var price := _node_int(core, "currentRerollPrice", -1)
	if price < 0:
		var rerolls := _node_int(core, "rerollCount", 0)
		price = 5 + rerolls * 2
	if _shop_reroll_card:
		_shop_reroll_card.configure(_row_font, _shop_reroll_title(), "$%d" % price, true)
	var offers: GnosisNode = core.get_node("offers")
	if not offers.is_valid() or offers.get_type() != GnosisValueType.LIST:
		return
	for i in range(offers.get_count()):
		var offer: GnosisNode = offers.get_node(i)
		if not offer.is_valid():
			continue
		if _node_bool(offer, "purchased", false):
			continue
		_add_offer_tile(
			str(_node_str(offer, "sourceConfigId")),
			str(_node_str(offer, "itemId")),
			_node_int(offer, "price", 0),
			i,
		)
	_attach_shop_reroll_card()


func _clear_offers() -> void:
	if _offers == null:
		return
	for child in _offers.get_children():
		if child is ShopOfferCard:
			child.queue_free()

func _add_offer_tile(source: String, item_id: String, price: int, index: int) -> void:
	var eng := _engine()
	var presentation := ShopCatalogUi.build_presentation(eng, source, item_id)
	var card := ShopOfferCard.new()
	card.configure(_row_font, presentation, price)
	card.buy_pressed.connect(_on_buy_pressed.bind(index))
	_offers.add_child(card)

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
	var adapter := _host.get_node_or_null("Adapters/Match3PlayAdapter") if _host else null
	if adapter and adapter.has_method("refresh_hud_after_reward"):
		adapter.refresh_hud_after_reward()

func _on_continue_pressed() -> void:
	# Merged planning panel: no separate shop overlay to dismiss.
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
