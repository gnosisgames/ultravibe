class_name UltravibeGameplayHoldRestartBridge
extends GnosisGameplayHoldRestartBridge

## Ultravibe: quick restart is available during planning overlays and mid-move animations.

var _ui_hold_active := false


func _ready() -> void:
	add_to_group("gameplay_hold_restart_bridge")
	run_service_id = "Match3"
	post_restart_host_method = "resync_match3_board_view"
	blocked_overlay_ids = PackedStringArray()
	super._ready()


func begin_ui_hold() -> void:
	if _restart_pending:
		return
	_ui_hold_active = true


func end_ui_hold() -> void:
	_ui_hold_active = false
	if not _is_restart_hold_active():
		_reset_hold()


func _is_restart_hold_active() -> bool:
	if _ui_hold_active:
		return true
	return super._is_restart_hold_active()


func _trigger_restart() -> void:
	_ui_hold_active = false
	super._trigger_restart()


func _perform_restart() -> void:
	_abort_in_flight_match3_presentation()
	super._perform_restart()


func _abort_in_flight_match3_presentation() -> void:
	var dispatcher := get_tree().get_first_node_in_group("match3_dispatcher") if get_tree() else null
	if dispatcher != null and dispatcher.has_method("reset_move_animation_state"):
		dispatcher.reset_move_animation_state()
	if _host == null or _host.engine == null:
		return
	var match3 = _host.get_service("Match3")
	if match3 != null and match3.has_method("complete_consumable_use_presentation_hud_step"):
		match3.complete_consumable_use_presentation_hud_step()
