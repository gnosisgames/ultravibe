class_name Match3HudRunUpgradesColumn
extends PlayHudUpgradesBar

## Owned run upgrades (Ephemeral.upgrades.run) — top of the 48px left rail.


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_size = 40.0
	slot_gap = 6.0
	super._ready()


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN


func _resolve_item_id(entry: GnosisNode) -> String:
	var upgrade_id := _node_str(entry, "upgradeId")
	if not upgrade_id.is_empty():
		return upgrade_id
	return super._resolve_item_id(entry)


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_BEGIN
