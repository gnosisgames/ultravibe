class_name Match3BoonFoilPreview
extends RefCounted

## Temporary dev hook: starter boons + foil/holographic shader previews on the HUD strip.
## Set ENABLED to false before shipping.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")
const HolographicCardFxScript = preload("res://game/ui/widgets/holographic_card_fx.gd")

const ENABLED := true
const STARTER_BOON_IDS: Array[String] = ["Rizz", "Brainrot", "Slay"]


static func grant_starter_boons_if_needed(service: GnosisService) -> void:
	if not ENABLED or service == null or service.context == null or service.context.store == null:
		return
	if service.context.engine == null:
		return
	var rows := SupportScript.get_active_boon_inventory_slot_rows(service)
	if not rows.is_empty():
		return
	var boon_service = service.context.engine.get_service("Boon")
	if boon_service == null or not boon_service.has_method("invoke_function"):
		return
	for boon_id in STARTER_BOON_IDS:
		if boon_id.is_empty():
			continue
		if SupportScript.read_boon_bag_empty_slot_count_by_capacity(service, "default") < 1:
			break
		var activate_params := service.context.store.create_object()
		activate_params.set_key("bucketId", "default")
		activate_params.set_key("boonId", boon_id)
		SupportScript.apply_shop_buy_price_to_activate_boon_params(service, activate_params, boon_id)
		var result = boon_service.invoke_function("ActivateBoon", activate_params)
		if result == null or not (result is GnosisNode) or not result.is_valid():
			continue
	SupportScript.publish_ephemeral_state(service)


static func foil_settings_for_slot(details: Dictionary, slot_index: int) -> Dictionary:
	if not ENABLED:
		return {}
	var base: Dictionary
	match slot_index:
		0:
			base = HolographicCardFxScript.build_holographic_foil_settings()
		1:
			base = HolographicCardFxScript.build_foil_card_settings()
		2:
			base = HolographicCardFxScript.build_prismatic_foil_settings()
		_:
			return {}
	return _tune_foilcolor_for_boon(base, details, slot_index)


static func _tune_foilcolor_for_boon(settings: Dictionary, details: Dictionary, slot_index: int) -> Dictionary:
	var tuned := settings.duplicate(true)
	var boon_id := str(details.get("name", "")).to_lower()
	if boon_id.is_empty() and slot_index >= 0 and slot_index < STARTER_BOON_IDS.size():
		boon_id = STARTER_BOON_IDS[slot_index].to_lower()
	match boon_id:
		"rizz", "slay":
			tuned["foilcolor"] = Vector3(0.98, 0.88, 0.38)
		"brainrot":
			tuned["foilcolor"] = Vector3(0.45, 0.82, 0.38)
		_:
			pass
	return tuned


static func metallic_settings_for_slot(_slot_index: int) -> Dictionary:
	return {}
