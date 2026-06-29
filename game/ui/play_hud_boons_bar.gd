class_name PlayHudBoonsBar
extends PlayHudIconBar

## Bottom-bar boons inventory (left zone): read-only icons with hover tooltips.

## Right-aligned so the boons cluster hugs the central ability cycler.
func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_END

func _inventory_category() -> String:
	return "boons"

func _bag() -> GnosisNode:
	return _ephemeral().get_node("boons").get_node("default")

func _inventory_list() -> GnosisNode:
	var bag := _bag()
	if not bag.is_valid():
		return GnosisNode.new(null)
	return bag.get_node("list")

func _bag_capacity() -> int:
	return _node_int(_bag(), "maxSize", 5)
