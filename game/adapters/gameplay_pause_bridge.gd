class_name UltravibeGameplayPauseBridge
extends Node

## Toggles the pause overlay during gameplay using GameUI additive navigation.

var _host: GnosisGodotEngine = null

func _ready() -> void:
	call_deferred("_resolve_host")
	set_process_unhandled_input(true)

func _resolve_host() -> void:
	var node: Node = get_parent()
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	var input := _host.get_adapter(GnosisGodotInputAdapter) as GnosisGodotInputAdapter if _host else null
	if input:
		input.enable_global_pause_toggle = false

func _unhandled_input(event: InputEvent) -> void:
	if not _host or not _host.engine:
		return
	if not Input.is_action_just_pressed("pause"):
		return
	var ui := _host.engine.get_service("GameUI") as GnosisGameUIService
	if ui == null or ui.get_base_view_id().to_lower() != "gameplay":
		return
	# Don't layer pause over the game-over overlay (the run is already finished).
	if not ui.get_active_overlay_state_for_view("game_over").is_empty():
		return
	# Pausing is expressed purely as a GameUI overlay state; the gameplay sim and
	# its input router observe that state and halt, so the scene tree itself is
	# never paused and the pause menu stays fully interactive.
	var pause_open := not ui.get_active_overlay_state_for_view("pause").is_empty()
	if not pause_open:
		var params := _host.engine.store.create_object()
		params.set_key("viewId", "pause")
		params.set_key("overlayStateId", "open")
		ui.invoke_function("PushViewAdditive", params)
	else:
		ui.invoke_function("PopView", _host.engine.store.create_object())
	get_viewport().set_input_as_handled()
