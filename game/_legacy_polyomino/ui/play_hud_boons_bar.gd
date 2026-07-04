class_name PlayHudBoonsBar
extends PlayHudIconBar

## Bottom-bar boons inventory (left zone): read-only icons with hover tooltips.

const BoonFlavorStickerScript = preload("res://game/ui/widgets/boon_flavor_sticker.gd")
const EngineFlavorsScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_flavors.gd")


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
	var props := entry.get_node("properties")
	return {
		"name": str(presentation.get("title", item_id.capitalize())),
		"description": str(presentation.get("description", "")),
		"icon_path": _icon_path(item_id, sprite_id),
		"count": maxi(1, _node_int(entry, "currentCount", 1)),
		"tags": presentation.get("tags", []),
		"positive_flavor_id": _node_str(props, EngineFlavorsScript.POSITIVE_FLAVOR_ID_PROPERTY),
		"negative_flavor_id": _node_str(props, EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY),
	}


func _make_slot(index: int, details: Dictionary) -> Control:
	var slot := super._make_slot(index, details)
	BoonFlavorStickerScript.apply_to_slot(slot, details, _resolve_slot_size())
	return slot


func _build_signature() -> String:
	if _service == null or _service.context == null:
		return ""
	var parts: Array[String] = _extra_signature_parts()
	var list := _inventory_list()
	if list.is_valid() and list.get_type() == GnosisValueType.LIST:
		for i in range(list.get_count()):
			var entry := list.get_node(i)
			parts.append("%s:%d" % [_resolve_item_id(entry), _node_int(entry, "currentCount", 1)])
			var props := entry.get_node("properties")
			parts.append(
				"+%s-%s" % [
					_node_str(props, EngineFlavorsScript.POSITIVE_FLAVOR_ID_PROPERTY),
					_node_str(props, EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY),
				]
			)
	return "|".join(parts)
