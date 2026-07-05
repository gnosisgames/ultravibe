class_name Match3HudHoldRestartButton
extends RoundedSquareBtn

## Hold to drive the shared top-right quick-restart indicator (same as holding R).

const BridgeScript = preload("res://game/adapters/gameplay_hold_restart_bridge.gd")

var _bridge: UltravibeGameplayHoldRestartBridge = null


func _ready() -> void:
	super._ready()
	toggle_mode = false
	button_down.connect(_on_hold_down)
	button_up.connect(_on_hold_up)
	call_deferred("_resolve_bridge")


func _resolve_bridge() -> void:
	if _bridge != null and is_instance_valid(_bridge):
		return
	if get_tree() == null:
		return
	for node in get_tree().get_nodes_in_group("gameplay_hold_restart_bridge"):
		if node is UltravibeGameplayHoldRestartBridge:
			_bridge = node
			return
	_bridge = get_tree().root.find_child("GameplayHoldRestartBridge", true, false) as UltravibeGameplayHoldRestartBridge


func _on_hold_down() -> void:
	if disabled:
		return
	_resolve_bridge()
	if _bridge != null:
		_bridge.begin_ui_hold()


func _on_hold_up() -> void:
	if _bridge != null and is_instance_valid(_bridge):
		_bridge.end_ui_hold()


func _on_pressed() -> void:
	# Short taps do nothing; restart requires a full hold on the shared indicator.
	pass
