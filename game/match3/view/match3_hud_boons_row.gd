class_name Match3HudBoonsRow
extends PlayHudBoonsBar

## Top-strip boon inventory (centered row, count label handled by Match3Hud).

func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_size = 56.0
	super._ready()


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_CENTER
