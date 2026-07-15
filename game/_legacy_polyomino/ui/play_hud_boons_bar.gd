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


func _describe_entry(entry: GnosisNode, reroll_random_preview: bool = false) -> Dictionary:
	var item_id := _resolve_item_id(entry)
	var engine: GnosisEngine = null
	if _service != null and _service.context != null:
		engine = _service.context.engine
	var presentation := InventoryTooltipUiScript.build_hud_presentation(engine, "boons", entry)
	if reroll_random_preview and engine != null:
		presentation["description"] = InventoryTooltipUiScript.build_description(
			engine, entry, "boons", str(presentation.get("description", "")), true
		)
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


func _tooltip_actions_for_entry(entry: GnosisNode) -> Array:
	if _service == null or _service.context == null or _service.context.engine == null:
		return []
	return InventoryTooltipUiScript.build_inventory_row_actions(
		_service.context.engine,
		entry,
		"boons",
	)


func _try_handle_tooltip_action(action_id: String, entry: GnosisNode) -> bool:
	if action_id != "UISell":
		return false
	if InventoryTooltipUiScript.try_sell_boon_entry(_service, entry):
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -1.0)
		_hide_tooltip()
		_refresh_parent_hud()
		force_refresh()
		return true
	return false


func _try_sell_at_index(index: int) -> bool:
	if _service == null or _service.context == null or _service.context.engine == null:
		return false
	var list := _inventory_list()
	if index < 0 or index >= list.get_count():
		return false
	var entry := list.get_node(index)
	if not InventoryTooltipUiScript.can_sell_boon_entry(_service.context.engine, entry):
		return false
	return _try_handle_tooltip_action("UISell", entry)


func _connect_slot_hit(hit: Button, index: int) -> void:
	super._connect_slot_hit(hit, index)
	hit.gui_input.connect(_on_boon_slot_gui_input.bind(index))


func _on_boon_slot_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _try_sell_at_index(index):
			get_viewport().set_input_as_handled()


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
			var instance_id := _node_str(entry, "instanceId")
			if instance_id.is_empty():
				instance_id = str(i)
			parts.append(
				"%s@%s:%d" % [
					_resolve_item_id(entry),
					instance_id,
					_node_int(entry, "currentCount", 1),
				]
			)
			var props := entry.get_node("properties")
			parts.append(
				"+%s-%s" % [
					_node_str(props, EngineFlavorsScript.POSITIVE_FLAVOR_ID_PROPERTY),
					_node_str(props, EngineFlavorsScript.NEGATIVE_FLAVOR_ID_PROPERTY),
				]
			)
	return "|".join(parts)
