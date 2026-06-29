class_name UltravibeGameplayView
extends GnosisUIElementView

## Full-screen gameplay shell (board + HUD). Registered as viewId "gameplay"
## so the transition coordinator can slide it like the menu views.

func _ready() -> void:
	add_to_group("gnosis_ui_view")
