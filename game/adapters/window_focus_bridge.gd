class_name UltravibeWindowFocusBridge
extends Node

## Ultravibe window focus: optional master mute and input gate only (no pause menu).
## Settings: settings.muteOnFocusLost, settings.onLostFocus (0=none, 1=unused, 2=block input).

const AudioService = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_audio_service.gd")
const InputService = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_input_service.gd")

const MUTE_ON_FOCUS_LOST_KEY := "settings.muteOnFocusLost"
const ON_LOST_FOCUS_KEY := "settings.onLostFocus"
const MASTER_BUS_NAME := "Master"

var _host: GnosisGodotEngine = null
var _subscriptions: Array = []
var _block_input_until_focus := false
var _focus_muted := false


func _ready() -> void:
	call_deferred("_resolve_host")
	set_process_input(true)
	set_process_unhandled_input(true)


func _exit_tree() -> void:
	_dispose_subscriptions()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_on_window_focus_out()
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_on_window_focus_in()


func _input(event: InputEvent) -> void:
	if _block_input_until_focus and event is InputEvent:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _block_input_until_focus and event is InputEvent:
		get_viewport().set_input_as_handled()


func _resolve_host() -> void:
	var node: Node = get_parent()
	while node:
		if node is GnosisGodotEngine:
			_host = node as GnosisGodotEngine
			break
		node = node.get_parent()
	_subscribe_input_gate()


func _on_window_focus_out() -> void:
	if _read_setting_bool(MUTE_ON_FOCUS_LOST_KEY, false):
		_focus_muted = true
		_set_master_bus_linear(0.0001)
	var on_lost_focus := _read_setting_int(ON_LOST_FOCUS_KEY, 0)
	if on_lost_focus == 2:
		_block_input_until_focus = true


func _on_window_focus_in() -> void:
	if _focus_muted:
		_focus_muted = false
		_restore_master_bus_volume()
	_block_input_until_focus = false


func _set_master_bus_linear(linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(MASTER_BUS_NAME)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.0001, 10.0)))


func _restore_master_bus_volume() -> void:
	var audio := _audio_service()
	if audio == null:
		return
	_set_master_bus_linear(audio.get_track_volume(AudioService.SoundTrack.Master))


func _audio_service() -> GnosisAudioService:
	if not _host or not _host.engine:
		return null
	return _host.engine.get_service("Audio") as GnosisAudioService


func _read_setting_bool(key: String, default_value: bool) -> bool:
	if not _host or not _host.engine:
		return default_value
	var node := _host.engine.state.root.get_node("Persistent.%s" % key)
	if node.is_valid() and node.value != null:
		return bool(node.value)
	return default_value


func _read_setting_int(key: String, default_value: int) -> int:
	if not _host or not _host.engine:
		return default_value
	var node := _host.engine.state.root.get_node("Persistent.%s" % key)
	if node.is_valid() and node.value != null and typeof(node.value) in [TYPE_INT, TYPE_FLOAT]:
		return int(node.value)
	return default_value


func _subscribe_input_gate() -> void:
	_dispose_subscriptions()
	if not _host or not _host.engine or not _host.engine.event_bus:
		return
	_subscriptions.append(
		_host.engine.event_bus.subscribe(
			InputService.RequestInputActionEventId,
			_on_request_input_action,
			20
		)
	)


func _on_request_input_action(event: GnosisEvent) -> void:
	if not _block_input_until_focus or not event or not event.data.is_valid():
		return
	event.data.set_key("allowed", false)
	event.data.set_key("reason", "window_focus_lost")


func _dispose_subscriptions() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()
