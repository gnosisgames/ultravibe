class_name CatalogLocalizationUi
extends RefCounted

## Resolves catalog presentation strings with nested ${loc:...} and ${arg:...}
## templates. Mirrors Unity MainHud.ResolveLocalizedText / GetStringResolved.

const ScoreCalcTooltipArgsScript = preload("res://game/ui/score_calculation_tooltip_loc_args.gd")


static func resolve_text(
	engine: GnosisEngine,
	key: String,
	fallback: String = "",
	config_section: String = "",
	catalog_item_id: String = "",
	entry: GnosisNode = GnosisNode.new(null),
) -> String:
	var trimmed_key := key.strip_edges()
	if trimmed_key.is_empty():
		return fallback
	if engine == null:
		return fallback
	var localization := engine.get_service("Localization") as GnosisLocalizationService
	if localization == null:
		return fallback
	var named_args := ScoreCalcTooltipArgsScript.resolve_for_catalog_entry(
		engine,
		config_section,
		catalog_item_id,
		entry,
	)
	return localization.get_string_resolved(trimmed_key, fallback, named_args, [])
