class_name UltravibeGameplayPauseBridge
extends Node

## Toggles the settings menu during gameplay using GameUI navigation.
## On mobile, Android back: first press opens settings; second press quits.
const PAUSE_TOGGLE_COOLDOWN_SEC := 0.3

var _host: GnosisGodotEngine = null
var _subscriptions: Array = []
var _next_pause_toggle_at := 0.0

func _ready() -> void:
	call_deferred("_resolve_host")
	set_process_unhandled_input(true)

func _exit_tree() -> void:
	_dispose_subscriptions()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		handle_android_back_press()

func handle_android_back_press() -> void:
	if not GnosisPlatform.is_mobile():
		return
	_handle_mobile_back()

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
	_subscribe_input_disconnect()

func _unhandled_input(event: InputEvent) -> void:
	if not _ensure_host():
		return
	if GnosisPlatform.is_mobile() and event.is_action_pressed("ui_cancel"):
		_handle_mobile_back()
		return
	if not event.is_action_pressed("pause"):
		return
	_toggle_pause_overlay()

func _handle_mobile_back() -> void:
	if not _ensure_host():
		return
	if _now_seconds() < _next_pause_toggle_at:
		return
	var ui := _game_ui()
	if ui == null:
		return
	var base_view := ui.get_base_view_id().strip_edges().to_lower()
	if base_view != "gameplay":
		get_tree().quit()
		return
	if not _can_pause_context(ui):
		return
	if _is_menu_over_gameplay(ui):
		if ui.get_navigation_history_count() > 0:
			UltraGameUiNav.pop_menu_back(ui, _host.engine.store)
		else:
			get_tree().quit()
		_next_pause_toggle_at = _now_seconds() + PAUSE_TOGGLE_COOLDOWN_SEC
		return
	_open_settings(ui)
	_next_pause_toggle_at = _now_seconds() + PAUSE_TOGGLE_COOLDOWN_SEC

func _toggle_pause_overlay() -> void:
	if not _ensure_host():
		return
	if _now_seconds() < _next_pause_toggle_at:
		get_viewport().set_input_as_handled()
		return
	var ui := _game_ui()
	if ui == null or ui.get_base_view_id().to_lower() != "gameplay":
		return
	if not _can_pause_context(ui):
		return
	if _is_menu_over_gameplay(ui):
		UltraGameUiNav.pop_menu_back(ui, _host.engine.store)
	else:
		_open_settings(ui)
	_next_pause_toggle_at = _now_seconds() + PAUSE_TOGGLE_COOLDOWN_SEC
	get_viewport().set_input_as_handled()

func _open_settings(ui: GnosisGameUIService) -> void:
	UltraGameUiNav.push_from_gameplay(ui, _host.engine.store, "settings", "slide_left")

func _can_pause_context(ui: GnosisGameUIService) -> bool:
	if not ui.get_active_overlay_state_for_view("game_over").is_empty():
		return false
	for view_id in ["level_select", "shop", "reward", "game_over"]:
		if not ui.get_active_overlay_state_for_view(view_id).is_empty():
			return false
	return true

func _is_menu_over_gameplay(ui: GnosisGameUIService) -> bool:
	return ui.get_base_view_id().strip_edges().to_lower() == "gameplay" \
		and ui.get_navigation_history_count() > 0

func _ensure_host() -> bool:
	if _host == null:
		_resolve_host()
	return _host != null and _host.engine != null

func _game_ui() -> GnosisGameUIService:
	if not _ensure_host():
		return null
	return _host.engine.get_service("GameUI") as GnosisGameUIService

func _subscribe_input_disconnect() -> void:
	_dispose_subscriptions()
	if not _host or not _host.engine or not _host.engine.event_bus:
		return
	_subscriptions.append(
		_host.engine.event_bus.subscribe("FACT_INPUT_JOYSTICK_DISCONNECTED", _on_joystick_disconnected, 0)
	)

func _on_joystick_disconnected(_event: GnosisEvent) -> void:
	var ui := _game_ui()
	if ui == null or ui.get_base_view_id().to_lower() != "gameplay":
		return
	if not _can_pause_context(ui):
		return
	if _is_menu_over_gameplay(ui):
		return
	_open_settings(ui)

func _dispose_subscriptions() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()

func _now_seconds() -> float:
	return Time.get_ticks_msec() / 1000.0
