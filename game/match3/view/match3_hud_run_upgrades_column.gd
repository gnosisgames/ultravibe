class_name Match3HudRunUpgradesColumn
extends PlayHudUpgradesBar

## Owned run upgrades (Ephemeral.upgrades.run) — top of the left rail.


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_gap = 6.0
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_on_rail_layout_changed)
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


func _slot_size_flags_horizontal() -> int:
	return Control.SIZE_EXPAND_FILL


func _slot_icon_fills_cell() -> bool:
	return true


func _resolve_slot_size() -> float:
	return Match3Hud.left_rail_slot_extent_for(self)


func _stack_badge_font_size() -> int:
	return maxi(22, int(round(_resolve_slot_size() * 0.42)))


func _stack_badge_rect(slot_size: float) -> Rect2:
	return Rect2(slot_size - 36.0, slot_size - 28.0, slot_size + 4.0, slot_size + 4.0)


func _on_rail_layout_changed() -> void:
	_last_signature = "__unset__"
	_refresh_if_changed()
