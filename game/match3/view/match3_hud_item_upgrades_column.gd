class_name Match3HudItemUpgradesColumn
extends PlayHudUpgradesBar

## Gem level upgrades (Ephemeral.upgrades.itemUpgrades) — bottom of the 48px left rail.


func _ready() -> void:
	show_capacity_dots = false
	float_offset = 0.0
	slot_size = 40.0
	slot_gap = 6.0
	super._ready()


func _bag() -> GnosisNode:
	return _ephemeral().get_node("upgrades").get_node("itemUpgrades")


func _inventory_list() -> GnosisNode:
	var bag := _bag()
	if not bag.is_valid():
		return GnosisNode.new(null)
	return bag.get_node("list")


func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END


func _resolve_item_id(entry: GnosisNode) -> String:
	var upgrade_id := _node_str(entry, "upgradeId")
	if not upgrade_id.is_empty():
		return upgrade_id
	return super._resolve_item_id(entry)


func _slot_size_flags_vertical() -> int:
	return Control.SIZE_SHRINK_END
