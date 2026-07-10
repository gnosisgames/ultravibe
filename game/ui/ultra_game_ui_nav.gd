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


## Clears the navigation stack and shows the title screen. Use whenever leaving
## gameplay for home (HUD home, pause home, game over) so Back from title menus
## does not restore the abandoned run.
static func return_to_title(ui: GnosisGameUIService, engine: GnosisEngine = null) -> void:
	if ui == null:
		return
	if engine != null:
		reset_theme_to_default(engine)
	ui.initialize_navigation_state("title")
	ui.set_base_view("title")

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


## Pushes a full-screen menu over gameplay so Back returns to the run.
static func push_from_gameplay(
	ui: GnosisGameUIService,
	store: GnosisStore,
	view_id: String,
	transition_id: String = "slide_left"
) -> void:
	if ui == null or store == null or view_id.strip_edges().is_empty():
		return
	var params: GnosisNode = store.create_object()
	params.set_key("viewId", view_id.strip_edges())
	params.set_key("currentViewId", "gameplay")
	params.set_key("transitionId", transition_id)
	params.set_key("inDuration", DEFAULT_DURATION)
	params.set_key("outDuration", DEFAULT_DURATION)
	ui.invoke_function("PushView", params)


## Standard Back for settings / collection: pop the stack, or return to gameplay
## when opened via set_base_view (no history), else title.
static func pop_menu_back(
	ui: GnosisGameUIService,
	store: GnosisStore,
	transition_id: String = "slide_right"
) -> void:
	if ui == null or store == null:
		return
	if ui.get_navigation_history_count() > 0:
		var params: GnosisNode = store.create_object()
		params.set_key("transitionId", transition_id)
		params.set_key("inDuration", DEFAULT_DURATION)
		params.set_key("outDuration", DEFAULT_DURATION)
		ui.invoke_function("PopView", params)
		return
	var current := ui.get_base_view_id().strip_edges().to_lower()
	if current == "settings" or current == "collection" or current == "achievements":
		transition_between(ui, store, current, "gameplay", transition_id)
		ui.initialize_navigation_state("gameplay")
	else:
		return_to_title(ui)

static func go_to_play_profiles(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "title",
	transition_id: String = "slide_left"
) -> void:
	transition_between(ui, store, from_view_id, "play", transition_id)

static func go_to_achievements(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "title",
	transition_id: String = "slide_left"
) -> void:
	transition_between(ui, store, from_view_id, "achievements", transition_id)
