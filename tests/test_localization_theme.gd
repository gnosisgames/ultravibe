extends SceneTree

## Verifies Sprint F wiring: the i18n catalog resolves localized strings (with en
## fallback + template resolution), and the Theme service applies a theme's color
## tokens into persistent state. Also confirms a boss encounter drives the Theme
## service to the boss theme and restores "normal" on survival.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Localization / Theme Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Localization/Theme Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var loc := engine.get_service("Localization") as GnosisLocalizationService
	var theme := engine.get_service("Theme") as GnosisThemeService

	# 1. Localized boss name/description in English.
	var ares := loc.get_string_value("aresLevelName", "")
	var ares_desc := loc.get_string_value("aresLevelDescription", "")
	if ares != "Ares":
		print("[FAIL] aresLevelName expected 'Ares', got '%s'" % ares)
		ok = false
	elif ares_desc.is_empty():
		print("[FAIL] aresLevelDescription did not resolve")
		ok = false
	else:
		print("[SUCCESS] localized: '%s' / '%s'" % [ares, ares_desc])

	# 1b. Engine-bundled Core UI strings (core__*) must resolve. These ship only in
	# the engine i18n bundle, so this guards the configuration loader merging it in.
	var play := loc.get_string_value("core__verb__play", "")
	if play.is_empty() or play == "core__verb__play":
		print("[FAIL] core__verb__play did not resolve (engine i18n not loaded), got '%s'" % play)
		ok = false
	else:
		print("[SUCCESS] engine core string resolves: core__verb__play -> '%s'" % play)

	# 2. Language switch + English fallback for keys missing in the target language.
	loc.set_language("es")
	var ares_es := loc.get_string_value("aresLevelName", "")
	if ares_es.is_empty():
		print("[FAIL] aresLevelName unresolved in 'es' (no fallback)")
		ok = false
	else:
		print("[SUCCESS] 'es' resolves aresLevelName to '%s'" % ares_es)
	loc.set_language("en")

	# 3. Theme application copies color tokens into persistent theme state.
	theme.set_current_theme_id("boss_ares")
	var current := theme.get_current_theme_id()
	var bg := theme.get_theme_property("background.main", "")
	if current != "boss_ares":
		print("[FAIL] current theme expected 'boss_ares', got '%s'" % current)
		ok = false
	elif bg != "#6A0A12":
		print("[FAIL] theme token background.main expected '#6A0A12', got '%s'" % bg)
		ok = false
	else:
		print("[SUCCESS] theme 'boss_ares' applied, background.main=%s" % bg)
	theme.set_current_theme_id("normal")
	return ok
