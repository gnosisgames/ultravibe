class_name Match3PlayAdapter
extends GnosisAdapter

## Thin bridge between engine events and the Match3 board view.

const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const ConsumableDbgScript = preload("res://game/match3/debug/match3_consumable_debug.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const Events = Match3EventsScript

var _match3_service = null
var _dispatcher = null
var _subscriptions: Array = []
## Status published mid-animation (win/loss panel) is held until the board view
## finishes the move so the winning/losing match still animates.
var _pending_status: int = -1


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
	if _match3_service != null:
		_set_board_visible(_match3_service.get_current_status() == Match3ModelsScript.STATUS_PLAYING)


## Re-read gameplay into the board view after level-select preview metadata changes.
func resync_board_view() -> void:
	_resolve_dispatcher()
	if _dispatcher and _match3_service:
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
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_MOVE_RESOLVED, _on_move_resolved, 0))
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_SHUFFLE_USED, _on_shuffle_used, 0))
	_subscriptions.append(bus.subscribe(Events.FACT_MATCH3_STATUS_CHANGED, _on_status_fact, 0))
	_subscriptions.append(bus.subscribe(GnosisGameUIService.FactBaseViewChanged, _on_game_ui_base_view_changed, 0))


func _on_board_fact(event: GnosisEvent) -> void:
	if _dispatcher == null or event == null:
		return
	ConsumableDbgScript.log_external("PlayAdapter._on_board_fact", "event=%s busy=%s" % [
		str(event.id),
		str(_dispatcher.is_busy() if _dispatcher.has_method("is_busy") else "?")
	])
	# Mid-move snapshots would stomp animated item nodes.
	if event.id == Events.FACT_MATCH3_BOARD_CHANGED and _dispatcher.is_busy():
		ConsumableDbgScript.log_external("PlayAdapter._on_board_fact", "skipped BOARD_CHANGED (dispatcher busy)")
		return
	_dispatcher.apply_board_payload(event.data)


func _on_move_resolved(event: GnosisEvent) -> void:
	if _dispatcher and event and _dispatcher.has_method("play_move_sequence"):
		_dispatcher.play_move_sequence(event.data)


func _on_shuffle_used(event: GnosisEvent) -> void:
	if _dispatcher == null or event == null or not event.data.is_valid():
		return
	var spawns := event.data.get_node("spawns")
	if not spawns.is_valid() or spawns.get_type() != GnosisValueType.LIST or spawns.get_count() == 0:
		return
	_play_shuffle_feedback()
	if _dispatcher.has_method("play_shuffle_sequence"):
		_dispatcher.play_shuffle_sequence(event.data)


func _play_shuffle_feedback() -> void:
	if engine == null or engine.store == null:
		return
	var anim := engine.get_service("Animation") as GnosisAnimationService
	if anim == null:
		return
	var params := engine.store.create_object()
	params.set_key("id", "shuffle")
	anim.invoke_function("PlayFeedback", params)


## Called by the dispatcher once a move's swap + cascade animation completes.
## Applies any status (reward / game over panel) that was held during the move.
func on_move_sequence_finished() -> void:
	if _dispatcher:
		_dispatcher.refresh_hud()
	if _pending_status < 0:
		return
	var status := _pending_status
	_pending_status = -1
	_route_status_to_ui(status)


func _should_defer_status_for_busy_dispatcher(status: int) -> bool:
	return status in [
		Match3ModelsScript.STATUS_WIN,
		Match3ModelsScript.STATUS_LOSS,
		Match3ModelsScript.STATUS_REWARD_PANEL,
		Match3ModelsScript.STATUS_LOSE_PANEL,
	]


func _on_status_fact(event: GnosisEvent) -> void:
	if event == null or not event.data.is_valid():
		return
	var status := _node_int(event.data, Events.PAYLOAD_GAME_STATUS, Match3ModelsScript.STATUS_LEVEL_SELECT_PANEL)
	if status in [Match3ModelsScript.STATUS_PLAYING, Match3ModelsScript.STATUS_LEVEL_SELECT_PANEL]:
		if _dispatcher and _dispatcher.has_method("reset_move_animation_state"):
			_dispatcher.reset_move_animation_state()
	# Hold a post-move result panel until the board view finishes animating, so
	# the winning/losing match is not cut off by the overlay snapping in.
	if _dispatcher and _dispatcher.has_method("is_busy") and _dispatcher.is_busy() \
			and _should_defer_status_for_busy_dispatcher(status):
		_pending_status = status
		return
	if _dispatcher:
		_dispatcher.refresh_hud()
	_route_status_to_ui(status)


func _on_game_ui_base_view_changed(_event: GnosisEvent) -> void:
	if engine == null:
		return
	var game_ui := engine.get_service("GameUI") as GnosisGameUIService
	if game_ui == null:
		return
	if game_ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return
	sync_subscreen_from_status()


func _route_status_to_ui(status: int) -> void:
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
	_relayout_hud_content_frame()
	_apply_status_to_ui(_match3_service.get_current_status(), game_ui)
	if _dispatcher:
		_dispatcher.refresh_hud()
	_relayout_hud_content_frame()


func _relayout_hud_content_frame() -> void:
	var hud = get_tree().get_first_node_in_group("match3_hud") if get_tree() else null
	if hud and hud.has_method("relayout_content_frame"):
		hud.relayout_content_frame()


func _apply_status_to_ui(status: int, game_ui: GnosisGameUIService) -> void:
	# The board grid belongs to the PLAYING substate only; hide it whenever a
	# full-area panel (reward / game over / shop / level select) is shown.
	_set_board_visible(status == Match3ModelsScript.STATUS_PLAYING)
	match status:
		Match3ModelsScript.STATUS_PLAYING:
			_dismiss_match3_overlays(game_ui)
		Match3ModelsScript.STATUS_WIN, Match3ModelsScript.STATUS_REWARD_PANEL:
			_push_overlay(game_ui, "reward")
		Match3ModelsScript.STATUS_LOSS, Match3ModelsScript.STATUS_LOSE_PANEL:
			_push_overlay(game_ui, "game_over")
		Match3ModelsScript.STATUS_SHOP_PANEL, Match3ModelsScript.STATUS_LEVEL_SELECT_PANEL:
			_show_planning_overlay(game_ui)


func _show_planning_overlay(game_ui: GnosisGameUIService) -> void:
	if not game_ui.get_active_overlay_state_for_view("reward").is_empty():
		_switch_overlay(game_ui, "level_select", "reward")
		return
	if not game_ui.get_active_overlay_state_for_view("shop").is_empty():
		_switch_overlay(game_ui, "level_select", "shop")
		return
	if game_ui.get_active_overlay_state_for_view("level_select").is_empty():
		_push_overlay(game_ui, "level_select")
	else:
		_sync_overlay_display("level_select")


func _set_board_visible(is_visible: bool) -> void:
	if _dispatcher:
		_dispatcher.visible = is_visible


func _push_overlay(game_ui: GnosisGameUIService, view_id: String) -> void:
	if game_ui.get_active_overlay_state_for_view(view_id).is_empty():
		var params := engine.store.create_object()
		params.set_key("viewId", view_id)
		params.set_key("overlayStateId", "open")
		game_ui.invoke_function("PushViewAdditive", params)
	else:
		_sync_overlay_display(view_id)


func _sync_overlay_display(view_id: String) -> void:
	var ui_adapter := get_tree().get_first_node_in_group("godot_game_ui_adapter") if get_tree() else null
	if ui_adapter and ui_adapter.has_method("sync_overlay_display"):
		ui_adapter.sync_overlay_display(view_id)


func _switch_overlay(game_ui: GnosisGameUIService, view_id: String, pop_view_id: String) -> void:
	if not game_ui.get_active_overlay_state_for_view(view_id).is_empty():
		_sync_overlay_display(view_id)
		return
	if game_ui.get_active_overlay_state_for_view(pop_view_id).is_empty():
		_push_overlay(game_ui, view_id)
		return
	var ui_adapter := get_tree().get_first_node_in_group("godot_game_ui_adapter") if get_tree() else null
	if ui_adapter and ui_adapter.has_method("switch_additive_overlay"):
		ui_adapter.switch_additive_overlay(pop_view_id, view_id)
		return
	game_ui.invoke_function("PopView", engine.store.create_object())
	_push_overlay(game_ui, view_id)


func _dismiss_match3_overlays(game_ui: GnosisGameUIService) -> void:
	var ui_adapter := get_tree().get_first_node_in_group("godot_game_ui_adapter") if get_tree() else null
	var from_key := ""
	if ui_adapter and ui_adapter.has_method("get_rendered_overlay_key"):
		from_key = str(ui_adapter.get_rendered_overlay_key()).strip_edges().to_lower()
	if from_key.is_empty():
		for view_id in ["level_select", "shop", "reward", "game_over", "pause"]:
			if not game_ui.get_active_overlay_state_for_view(view_id).is_empty():
				from_key = view_id
				break
	for view_id in ["level_select", "shop", "reward", "game_over", "pause"]:
		game_ui.clear_overlay_state_for_view(view_id)
	if ui_adapter and ui_adapter.has_method("dismiss_additive_overlay_with_slide") and not from_key.is_empty():
		ui_adapter.dismiss_additive_overlay_with_slide(from_key)
		return
	_finalize_overlay_dismiss()


func _finalize_overlay_dismiss() -> void:
	var ui_adapter := get_tree().get_first_node_in_group("godot_game_ui_adapter") if get_tree() else null
	if ui_adapter and ui_adapter.has_method("finalize_overlay_dismiss"):
		ui_adapter.finalize_overlay_dismiss()


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
