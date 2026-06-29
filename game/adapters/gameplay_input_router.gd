class_name UltravibeGameplayInputRouter
extends Node

## Bridges semantic input (GnosisInputService) into FallingBlock gameplay inputs.
##
## Subscribes to the input pipeline instead of reading Godot actions directly so
## gameplay input is data-driven, player-aware, and gated by GameUI context:
## actions are denied (and never routed) while a menu/overlay is on top of the
## gameplay base view, or while a confirmation dialog is pending.

const ACTION_TO_INPUT := {
	"move_left": FallingBlockModels.InputType.MOVE_LEFT,
	"move_right": FallingBlockModels.InputType.MOVE_RIGHT,
	"rotate_cw": FallingBlockModels.InputType.ROTATE_CW,
	"rotate_ccw": FallingBlockModels.InputType.ROTATE_CCW,
	"soft_drop": FallingBlockModels.InputType.SOFT_DROP,
	"hard_drop": FallingBlockModels.InputType.HARD_DROP,
	"discard": FallingBlockModels.InputType.DISCARD,
	"use_consumable": FallingBlockModels.InputType.USE_CONSUMABLE,
	"consumable_next": FallingBlockModels.InputType.CONSUMABLE_NEXT,
	"consumable_previous": FallingBlockModels.InputType.CONSUMABLE_PREVIOUS,
	"ability_use": FallingBlockModels.InputType.ABILITY,
	"ability_next": FallingBlockModels.InputType.ABILITY_NEXT,
	"ability_previous": FallingBlockModels.InputType.ABILITY_PREVIOUS,
}

const HELD_REPEAT := {
	"move_left": {"delay": 0.18, "interval": 0.055},
	"move_right": {"delay": 0.18, "interval": 0.055},
	"soft_drop": {"delay": 0.0, "interval": 0.035},
}

@export var player_id: String = "P0"

var _host: GnosisGodotEngine = null
var _subscriptions: Array = []
var _held_actions: Dictionary = {}

func _ready() -> void:
	call_deferred("_resolve_host")
	set_process(true)

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
	# Gate first (higher priority) so denied gameplay actions never get processed.
	_subscriptions.append(bus.subscribe(GnosisInputService.RequestInputActionEventId, _on_request_input, 10))
	_subscriptions.append(bus.subscribe(GnosisInputService.FactInputActionProcessedEventId, _on_input_processed, 0))

func _on_request_input(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	if not _is_gameplay_action(event.data):
		return
	if not _gameplay_live():
		event.data.set_key("allowed", false)
		event.data.set_key("reason", "gameplay_not_active")
		return
	# Gameplay input is routed by this adapter on FACT_INPUT_ACTION_PROCESSED so
	# it can support held-repeat behavior and GameUI gating. Tell the generic
	# input service not to also dispatch the configured targetEvent for the same
	# semantic action (notably "discard", whose data id matches exactly).
	event.data.set_key("skipConfiguredTargetEvent", true)

func _on_input_processed(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	if not _gameplay_live():
		return
	var action_id: String = _action_id(event.data)
	if not ACTION_TO_INPUT.has(action_id):
		return
	# Held-repeat is tracked per (player, action): in co-op two controllers can
	# hold the same action at once, so a shared per-action entry would let one
	# player's press/release clobber the other's and leave a repeat stuck on.
	var routed_player_id: String = _player_id(event.data)
	var held_key: String = _held_key(routed_player_id, action_id)
	if _is_phase_canceled(event.data):
		_held_actions.erase(held_key)
		return
	if not _is_phase_performed(event.data):
		return
	_route_action(action_id, routed_player_id)
	if HELD_REPEAT.has(action_id):
		var spec: Dictionary = HELD_REPEAT[action_id]
		_held_actions[held_key] = {
			"actionId": action_id,
			"playerId": routed_player_id,
			"nextAt": _now_seconds() + float(spec.get("delay", 0.0))
		}

func _process(_delta: float) -> void:
	if not _gameplay_live():
		_held_actions.clear()
		return
	var now: float = _now_seconds()
	for held_key in _held_actions.keys():
		var state: Dictionary = _held_actions[held_key]
		var action_id: String = str(state.get("actionId", ""))
		if not HELD_REPEAT.has(action_id):
			continue
		var next_at: float = float(state.get("nextAt", now))
		if now < next_at:
			continue
		var routed_player_id: String = str(state.get("playerId", player_id))
		_route_action(action_id, routed_player_id)
		var spec: Dictionary = HELD_REPEAT[action_id]
		state["nextAt"] = now + float(spec.get("interval", 0.05))
		_held_actions[held_key] = state

func _held_key(routed_player_id: String, action_id: String) -> String:
	return "%s/%s" % [routed_player_id, action_id]

func _route_action(action_id: String, routed_player_id: String) -> void:
	var service := _falling_block()
	if service:
		service.publish_input_from_adapter(routed_player_id, ACTION_TO_INPUT[action_id])

func _is_gameplay_action(data: GnosisNode) -> bool:
	return ACTION_TO_INPUT.has(_action_id(data))

func _action_id(data: GnosisNode) -> String:
	var node := data.get_node("actionId")
	return str(node.value).strip_edges().to_lower() if node.is_valid() and node.value != null else ""

func _is_phase_performed(data: GnosisNode) -> bool:
	var node := data.get_node("phase")
	if not node.is_valid() or node.value == null:
		return true
	return str(node.value).strip_edges().to_lower() == "performed"

func _is_phase_canceled(data: GnosisNode) -> bool:
	var node := data.get_node("phase")
	return node.is_valid() and node.value != null and str(node.value).strip_edges().to_lower() == "canceled"

func _player_id(data: GnosisNode) -> String:
	var node := data.get_node("playerId")
	var from_event := str(node.value).strip_edges() if node.is_valid() and node.value != null else ""
	return from_event if not from_event.is_empty() else player_id

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0

func _falling_block() -> FallingBlockService:
	if _host and _host.engine:
		return _host.engine.get_service("FallingBlock") as FallingBlockService
	return null

func _game_ui() -> GnosisGameUIService:
	if _host and _host.engine:
		return _host.engine.get_service("GameUI") as GnosisGameUIService
	return null

## Gameplay only accepts input when the gameplay base view is foremost: no menu
## pushed on top, no pause overlay active, and no confirmation dialog pending.
func _gameplay_live() -> bool:
	var ui := _game_ui()
	if ui == null:
		return false
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	if not ui.get_active_overlay_state_for_view("pause").is_empty():
		return false
	var confirmation := ui.build_confirmation_state_snapshot()
	var active := confirmation.get_node("activeConfirmationId")
	if active.is_valid() and active.value != null and not str(active.value).strip_edges().is_empty():
		return false
	return true

func _dispose_subscriptions() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()
