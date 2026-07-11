class_name UltravibeGameplayHoldRestartBridge
extends GnosisGameplayHoldRestartBridge

## Ultravibe: quick restart is available during planning overlays and mid-move animations.

const UltravibeProgressScript := preload("res://game/ui/ultravibe_hold_restart_progress.gd")

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


func _ensure_progress_widget() -> void:
	if _progress != null and is_instance_valid(_progress):
		return
	if _progress_root == null or not is_instance_valid(_progress_root):
		_progress_root = Control.new()
		_progress_root.name = "HoldRestartRoot"
		_progress_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_progress_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_progress_root)
	_progress = UltravibeProgressScript.new()
	_progress.name = "HoldRestartProgress"
	var panel_size := PROGRESS_PANEL_SIZE
	var margin := PROGRESS_SCREEN_MARGIN
	match progress_corner:
		ProgressCorner.TOP_LEFT:
			_progress.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_progress.grow_horizontal = Control.GROW_DIRECTION_END
			_progress.offset_left = margin
			_progress.offset_top = margin
			_progress.offset_right = margin + panel_size
			_progress.offset_bottom = margin + panel_size
		_:
			_progress.set_anchors_preset(Control.PRESET_TOP_RIGHT)
			_progress.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_progress.offset_left = -(margin + panel_size)
			_progress.offset_top = margin
			_progress.offset_right = -margin
			_progress.offset_bottom = margin + panel_size
	_progress.custom_minimum_size = Vector2(panel_size, panel_size)
	_progress.size = _progress.custom_minimum_size
	_progress_root.add_child(_progress)
