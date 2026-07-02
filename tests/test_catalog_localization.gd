extends SceneTree

## Verifies nested ${loc:...} templates resolve for shop/catalog tooltips.

const CatalogLocalizationUiScript := preload("res://game/ui/catalog_localization_ui.gd")
const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"


func _init() -> void:
	var ok := _run()
	print("test_catalog_localization: %s" % ("OK" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	var config := GnosisEngineConfig.new()
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.register_service("Configuration", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_configuration_service.gd"))
	config.register_service("Statistic", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_statistic_service.gd"))
	config.register_service("Localization", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_localization_service.gd"))

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	var rubymania := CatalogLocalizationUiScript.resolve_text(
		engine,
		"consumableRubymaniaDescription",
		"",
		"consumables",
		"Rubymania",
	)
	if rubymania.contains("${loc:"):
		print("[FAIL] Rubymania description still has unresolved loc tokens: %s" % rubymania)
		return false
	if not rubymania.contains("Ruby"):
		print("[FAIL] Rubymania description missing Ruby tile name: %s" % rubymania)
		return false
	if not rubymania.contains("+4 Multi"):
		print("[FAIL] Rubymania description missing effect text: %s" % rubymania)
		return false

	var clickbait := CatalogLocalizationUiScript.resolve_text(
		engine,
		"boonClickbaitDescription",
		"",
		"boons",
		"Clickbait",
	)
	if clickbait.contains("${loc:") or clickbait.contains("${arg:"):
		print("[FAIL] Clickbait description has unresolved tokens: %s" % clickbait)
		return false
	if not clickbait.contains("Multi"):
		print("[FAIL] Clickbait description missing Multi text: %s" % clickbait)
		return false

	print("[OK] Rubymania -> %s" % rubymania)
	print("[OK] Clickbait -> %s" % clickbait)
	return true
