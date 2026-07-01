class_name PlayHudConsumablesBar
extends PlayHudIconBar

## Bottom-bar consumables inventory (right zone): click-to-select, click-again-to-use.

@export_range(0.0, 1.0) var unselected_alpha: float = 0.55

func _ready() -> void:
	# Consumables have no real (small) slot cap -- the bag is effectively
	# unlimited -- so slot dots would be meaningless. Boons keep theirs.
	show_capacity_dots = false
	super._ready()

## Left-aligned so the consumables cluster hugs the central ability cycler.
func _apply_bar_alignment() -> void:
	alignment = BoxContainer.ALIGNMENT_BEGIN

func _inventory_category() -> String:
	return "consumables"

func _bag() -> GnosisNode:
	return _ephemeral().get_node("consumables").get_node("default")

func _inventory_list() -> GnosisNode:
	var bag := _bag()
	if not bag.is_valid():
		return GnosisNode.new(null)
	return bag.get_node("list")

func _bag_capacity() -> int:
	return _node_int(_bag(), "maxSize", 0)

func _extra_signature_parts() -> Array[String]:
	if _service and _service.has_method("get_selected_consumable_slot"):
		return ["sel:%d" % _service.get_selected_consumable_slot()]
	return []

func _slot_alpha(index: int, _details: Dictionary) -> float:
	if _service == null or not _service.has_method("get_selected_consumable_slot"):
		return 1.0
	return 1.0 if index == _service.get_selected_consumable_slot() else unselected_alpha

func _slot_stack_count(details: Dictionary) -> int:
	return int(details.get("count", 1))

func _on_slot_pressed(index: int) -> void:
	if _service == null or not _service.has_method("select_consumable_slot"):
		return
	var entries := _entries()
	if index < 0 or index >= entries.size():
		return
	if _service.has_method("get_selected_consumable_slot") and index == _service.get_selected_consumable_slot():
		if _service.has_method("request_use_selected_consumable"):
			_service.request_use_selected_consumable()
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -1.0)
	else:
		_service.select_consumable_slot(index)
		UltraUiFx.play_ui_sfx(self, UltraUiFx.CLIP_PRESSED, -3.0)
	force_refresh()
