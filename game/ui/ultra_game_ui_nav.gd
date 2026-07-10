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
	transition_id: String = "slide_up",
	record_new_run: bool = false
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
	_record_run_activity(ui, record_new_run)

static func _record_run_activity(ui: GnosisGameUIService, record_new_run: bool) -> void:
	if ui == null or ui.context == null or ui.context.engine == null:
		return
	var profile := ui.context.engine.get_service("Profile") as GnosisProfileService
	if profile == null:
		return
	if record_new_run:
		profile.increment_active_runs()
	else:
		profile.touch_last_played()

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


## Standard Back for settings / collection: pop the stack, or return to title
## when the stack is empty (menus opened via transition, not pause push).
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
	var base_view := ui.get_base_view_id().strip_edges().to_lower()
	if base_view == "settings" or base_view == "collection" or base_view == "achievements" or base_view == "profiles" or base_view == "play":
		transition_between(ui, store, base_view, "title", transition_id)
		ui.initialize_navigation_state("title")
		ui.set_base_view("title")
	else:
		return_to_title(ui)

static func go_to_play_profiles(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "title",
	transition_id: String = "slide_left"
) -> void:
	transition_between(ui, store, from_view_id, "profiles", transition_id)

static func go_to_profiles(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "title",
	transition_id: String = "slide_left"
) -> void:
	go_to_play_profiles(ui, store, from_view_id, transition_id)

static func go_to_achievements(
	ui: GnosisGameUIService,
	store: GnosisStore,
	from_view_id: String = "title",
	transition_id: String = "slide_left"
) -> void:
	if ui == null or store == null:
		return
	var params: GnosisNode = store.create_object()
	params.set_key("viewId", "achievements")
	if not from_view_id.strip_edges().is_empty():
		params.set_key("currentViewId", from_view_id.strip_edges())
	params.set_key("transitionId", transition_id)
	params.set_key("inDuration", DEFAULT_DURATION)
	params.set_key("outDuration", DEFAULT_DURATION)
	ui.invoke_function("PushView", params)
