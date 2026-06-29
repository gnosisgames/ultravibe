class_name UltraGameUiNav
extends RefCounted

## Shared GameUI navigation helpers for Ultravibe views.

const DEFAULT_DURATION := 0.35

static func reset_theme_to_default(engine: GnosisEngine) -> void:
	if engine == null:
		return
	var theme := engine.get_service("Theme") as GnosisThemeService
	if theme:
		theme.set_current_theme_id(GnosisThemeService.DEFAULT_THEME_ID)

## Animates to the gameplay view without mutating the navigation stack, then
## re-seeds the stack so gameplay is the root (empty history). Use when
## entering or re-entering a run from play setup, game over, or rewards.
static func transition_to_gameplay(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "",
	transition_id: String = "slide_up"
) -> void:
	if ui == null or store == null:
		return
	var params: GnosisNode = store.create_object()
	if not from_view_id.strip_edges().is_empty():
		params.set_key("currentViewId", from_view_id.strip_edges())
	params.set_key("nextViewId", "gameplay")
	params.set_key("transitionId", transition_id)
	params.set_key("inDuration", DEFAULT_DURATION)
	params.set_key("outDuration", DEFAULT_DURATION)
	ui.invoke_function("RequestTransition", params)
	ui.initialize_navigation_state("gameplay")

## Animates between two full-screen views via RequestTransition (no stack change).
static func transition_between(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String,
	to_view_id: String,
	transition_id: String = "fade"
) -> void:
	if ui == null or store == null or to_view_id.strip_edges().is_empty():
		return
	var params: GnosisNode = store.create_object()
	if not from_view_id.strip_edges().is_empty():
		params.set_key("currentViewId", from_view_id.strip_edges())
	params.set_key("nextViewId", to_view_id.strip_edges())
	params.set_key("transitionId", transition_id)
	params.set_key("inDuration", DEFAULT_DURATION)
	params.set_key("outDuration", DEFAULT_DURATION)
	ui.invoke_function("RequestTransition", params)
