class_name Match3PlayAdapter
extends GnosisAdapter

## Thin bridge between engine events and the Match3 board view.

const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Events = Match3EventsScript

var _match3_service = null
var _dispatcher = null
var _subscriptions: Array = []


func _ready() -> void:
	add_to_group("match3_play_adapter")


func _exit_tree() -> void:
	_dispose_subscriptions()


func _on_service_bound() -> void:
	_match3_service = service
	_resolve_dispatcher()
	_subscribe_facts()
	if _dispatcher:
		_dispatcher.bind_service(_match3_service)
	_set_board_visible(_match3_service != null and _match3_service.get_current_status() == Match3ModelsScript.STATUS_PLAYING)


func bind_dispatcher(dispatcher) -> void:
	_dispatcher = dispatcher
	if _match3_service:
		_dispatcher.bind_service(_match3_service)


func begin_level(level_number: int = 1) -> void:
	if engine == null or engine.event_bus == null or engine.store == null:
		return
	var payload := engine.store.create_object()
	payload.set_key(Events.PAYLOAD_LEVEL_NUMBER, maxi(1, level_number))
	engine.event_bus.publish(GnosisEvent.new(Events.REQUEST_MATCH3_BEGIN_LEVEL, payload, false))


func request_move(x1: int, y1: int, x2: int, y2: int) -> void:
	if engine == null or engine.event_bus == null or engine.store == null:
		return
	if _match3_service and not _match3_service.is_board_input_allowed():
		return
	var payload := engine.store.create_object()
	payload.set_key("x1", x1)
	payload.set_key("y1", y1)
	payload.set_key("x2", x2)
	payload.set_key("y2", y2)
	engine.event_bus.publish(GnosisEvent.new(Events.REQUEST_MATCH3_MOVE, payload, false))


func _resolve_dispatcher() -> void:
	if _dispatcher:
		return
	_dispatcher = get_tree().get_first_node_in_group(Match3Dispatcher.GROUP) as Match3Dispatcher


func _subscribe_facts() -> void:
	_dispose_subscriptions()
	if engine == null or engine.event_bus == null:
		return
	var bus := engine.event_bus
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_BOARD_RESET, _on_board_fact, 0))
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_BOARD_CHANGED, _on_board_fact, 0))
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_STATUS_CHANGED, _on_status_fact, 0))


func _on_board_fact(event: GnosisEvent) -> void:
	if _dispatcher and event:
		_dispatcher.apply_board_payload(event.data)


func _on_status_fact(event: GnosisEvent) -> void:
	if _dispatcher:
		_dispatcher.refresh_hud()
	if event == null or not event.data.is_valid():
		return
	var status := _node_int(event.data, Events.PAYLOAD_GAME_STATUS, Match3ModelsScript.STATUS_LEVEL_SELECT_PANEL)
	if engine == null:
		return
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	if game_ui == null:
		return
	if game_ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return
	_apply_status_to_ui(status, game_ui)


## Re-applies board visibility and subscreen overlays from the current Match3 status.
## Call when entering the gameplay view so a status event published earlier is not missed.
func sync_subscreen_from_status() -> void:
	if engine == null or _match3_service == null:
		return
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	if game_ui == null:
		return
	if game_ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return
	_apply_status_to_ui(_match3_service.get_current_status(), game_ui)
	if _dispatcher:
		_dispatcher.refresh_hud()


func _apply_status_to_ui(status: int, game_ui: GnosisGameUIService) -> void:
	# The board grid belongs to the PLAYING substate only; hide it whenever a
	# full-area panel (reward / game over / shop / level select) is shown.
	_set_board_visible(status == Match3ModelsScript.STATUS_PLAYING)
	match status:
		Match3ModelsScript.STATUS_PLAYING:
			_set_swap_mode("")
			_dismiss_match3_overlays(game_ui)
		Match3ModelsScript.STATUS_WIN, Match3ModelsScript.STATUS_REWARD_PANEL:
			_set_swap_mode("")
			_push_overlay(game_ui, "reward")
		Match3ModelsScript.STATUS_LOSS, Match3ModelsScript.STATUS_LOSE_PANEL:
			_set_swap_mode("")
			_push_overlay(game_ui, "game_over")
		Match3ModelsScript.STATUS_SHOP_PANEL:
			_set_swap_mode("to_level_select")
			_switch_overlay(game_ui, "shop", "level_select")
		Match3ModelsScript.STATUS_LEVEL_SELECT_PANEL:
			# The shop only joins the loop after the first round; keep the green
			# switcher hidden on the opening level select.
			if _match3_service and _match3_service.has_method("is_shop_available") \
					and _match3_service.is_shop_available():
				_set_swap_mode("to_shop")
			else:
				_set_swap_mode("")
			_switch_overlay(game_ui, "level_select", "shop")


func _set_board_visible(is_visible: bool) -> void:
	if _dispatcher:
		_dispatcher.visible = is_visible


func _set_swap_mode(mode: String) -> void:
	var hud = get_tree().get_first_node_in_group("match3_hud") if get_tree() else null
	if hud and hud.has_method("set_subscreen_swap_mode"):
		hud.set_subscreen_swap_mode(mode)


func _push_overlay(game_ui: GnosisGameUIService, view_id: String) -> void:
	if not game_ui.get_active_overlay_state_for_view(view_id).is_empty():
		return
	var params := engine.store.create_object()
	params.set_key("viewId", view_id)
	params.set_key("overlayStateId", "open")
	game_ui.invoke_function("PushViewAdditive", params)


func _switch_overlay(game_ui: GnosisGameUIService, view_id: String, pop_view_id: String) -> void:
	if not game_ui.get_active_overlay_state_for_view(pop_view_id).is_empty():
		game_ui.invoke_function("PopView", engine.store.create_object())
	_push_overlay(game_ui, view_id)


func _dismiss_match3_overlays(game_ui: GnosisGameUIService) -> void:
	for _i in 6:
		var has_overlay := false
		for view_id in ["level_select", "shop", "reward", "game_over", "pause"]:
			if not game_ui.get_active_overlay_state_for_view(view_id).is_empty():
				has_overlay = true
				break
		if not has_overlay:
			return
		game_ui.invoke_function("PopView", engine.store.create_object())


func refresh_hud_after_reward() -> void:
	if _dispatcher:
		_dispatcher.refresh_hud()


func _dispose_subscriptions() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()


func _node_int(node: GnosisNode, key: String, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return int(child.value)
