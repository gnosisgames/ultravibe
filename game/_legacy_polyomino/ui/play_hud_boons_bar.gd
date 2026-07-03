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


func _describe_entry(entry: GnosisNode) -> Dictionary:
	var item_id := _resolve_item_id(entry)
	var engine: GnosisEngine = null
	if _service != null and _service.context != null:
		engine = _service.context.engine
	var presentation := InventoryTooltipUiScript.build_hud_presentation(engine, "boons", entry)
	var metadata := entry.get_node("metadata")
	var sprite_id := _node_str(metadata, "spriteId")
	return {
		"name": str(presentation.get("title", item_id.capitalize())),
		"description": str(presentation.get("description", "")),
		"icon_path": _icon_path(item_id, sprite_id),
		"count": maxi(1, _node_int(entry, "currentCount", 1)),
		"tags": presentation.get("tags", []),
	}
