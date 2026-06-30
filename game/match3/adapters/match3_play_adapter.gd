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
	var status := _node_int(event.data, Events.PAYLOAD_GAME_STATUS, Match3ModelsScript.STATUS_PLAYING)
	if status != Match3ModelsScript.STATUS_WIN and status != Match3ModelsScript.STATUS_LOSS:
		return
	if engine == null:
		return
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	if game_ui == null:
		return
	if game_ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return
	# A round win opens the reward payout overlay; a loss ends the run with the
	# game-over summary (Unity parity: win -> rewardPanel, loss -> state panel).
	var overlay_view_id := "reward" if status == Match3ModelsScript.STATUS_WIN else "game_over"
	if not game_ui.get_active_overlay_state_for_view("game_over").is_empty():
		return
	if not game_ui.get_active_overlay_state_for_view("reward").is_empty():
		return
	var params := engine.store.create_object()
	params.set_key("viewId", overlay_view_id)
	params.set_key("overlayStateId", "open")
	game_ui.invoke_function("PushViewAdditive", params)


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
