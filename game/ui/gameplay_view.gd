class_name UltravibeGameplayView
extends GnosisUIElementView

## Full-screen gameplay shell (board + HUD). Registered as viewId "gameplay"
## so the transition coordinator can slide it like the menu views.

func _ready() -> void:
	add_to_group("gnosis_ui_view")


func set_view_visible(is_visible: bool) -> void:
	super.set_view_visible(is_visible)
	if is_visible:
		call_deferred("_sync_match3_subscreen")


func _sync_match3_subscreen() -> void:
	var adapter = get_tree().get_first_node_in_group("match3_play_adapter")
	if adapter and adapter.has_method("sync_subscreen_from_status"):
		adapter.sync_subscreen_from_status()
