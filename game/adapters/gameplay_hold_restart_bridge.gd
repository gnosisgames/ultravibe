class_name UltravibeGameplayHoldRestartBridge
extends GnosisGameplayHoldRestartBridge

## Ultravibe: quick restart is available during planning overlays and mid-move animations.


func _ready() -> void:
	run_service_id = "Match3"
	post_restart_host_method = "resync_match3_board_view"
	blocked_overlay_ids = PackedStringArray()
	super._ready()


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
