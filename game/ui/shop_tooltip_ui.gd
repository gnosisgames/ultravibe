class_name ShopTooltipUi
extends RefCounted

## Tooltip action rows for shop offers (Unity shop tooltip buy chip parity).

const BUY_ACTION_TYPE := "success"
const BUY_INPUT_ACTION := "UISubmit"
const BUY_LOC_KEY := "core__verb__buy"


static func build_buy_actions(engine: GnosisEngine, price: int) -> Array:
	var action := _make_buy_action(engine, price)
	return [action] if not action.is_empty() else []


static func _make_buy_action(engine: GnosisEngine, price: int) -> Dictionary:
	var amount := maxi(0, price)
	var label := "Buy $%d" % amount
	var localization := engine.get_service("Localization") as GnosisLocalizationService if engine else null
	if localization != null:
		label = localization.get_string_resolved(BUY_LOC_KEY, label, {}, [str(amount)])
	return {
		"type": BUY_ACTION_TYPE,
		"label": label,
		"input_action": BUY_INPUT_ACTION,
		"input_mouse_button": MOUSE_BUTTON_LEFT,
	}
