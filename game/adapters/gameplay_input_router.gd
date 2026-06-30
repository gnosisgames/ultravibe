class_name UltravibeGameplayInputRouter
extends Node

## Match-3 uses board drag input on Match3Dispatcher; this router only gates pause.

var _host: GnosisGodotEngine = null
var _subscriptions: Array = []

func _ready() -> void:
	call_deferred("_resolve_host")

func _exit_tree() -> void:
	_dispose_subscriptions()

func _resolve_host() -> void:
	var node: Node = get_parent()
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_subscribe()

func _subscribe() -> void:
	_dispose_subscriptions()
	if not _host or not _host.engine or not _host.engine.event_bus:
		return
	var bus := _host.engine.event_bus
	_subscriptions.append(bus.subscribe(GnosisInputService.RequestInputActionEventId, _on_request_input, 10))

func _on_request_input(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	var action := _node_string(event.data, "actionId", "")
	if action != GameInputActions.UI_CANCEL_ACTION:
		return
	if not _gameplay_live():
		event.data.set_key("allowed", false)
		event.data.set_key("reason", "gameplay_not_active")

func _gameplay_live() -> bool:
	var eng := _host.engine if _host else null
	if eng == null:
		return false
	var ui := eng.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return false
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	if not ui.get_active_overlay_state_for_view("pause").is_empty():
		return false
	if not ui.get_active_overlay_state_for_view("game_over").is_empty():
		return false
	if not ui.get_active_overlay_state_for_view("reward").is_empty():
		return false
	if not ui.get_active_overlay_state_for_view("shop").is_empty():
		return false
	if not ui.get_active_overlay_state_for_view("level_select").is_empty():
		return false
	return true

func _dispose_subscriptions() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()

func _node_string(node: GnosisNode, key: String, default_value: String = "") -> String:
	if node == null or not node.is_valid():
		return default_value
	var child := node.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return str(child.value)
