extends SceneTree

## Verifies GameUI additive overlay state and confirmation display fields.

var _done := false

func _initialize() -> void:
	print("--- GameUI overlay test ---")

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true

	var store := GnosisStore.new()
	var bus := GnosisEventBus.new(store, func(): return null)
	var config := GnosisEngineConfig.new()
	config.register_service("GameUI", GnosisLifetime.SINGLETON, func(): return GnosisGameUIService.new())
	var engine := GnosisEngine.new(config, bus, store)
	engine.initialize_permanent_only()
	var ui := engine.get_service("GameUI") as GnosisGameUIService

	ui.initialize_navigation_state("gameplay")
	ui.set_base_view("gameplay")

	var level_params := store.create_object()
	level_params.set_key("viewId", "level_select")
	level_params.set_key("overlayStateId", "open")
	var push: GnosisFunctionResult = ui.invoke_function("PushViewAdditive", level_params)
	if not push.is_ok:
		push_error("PushViewAdditive failed")
		quit(1)
		return true
	if ui.get_active_overlay_state_for_view("level_select") != "open":
		push_error("Level select overlay not open")
		quit(1)
		return true

	ui.try_set_view_overlay_state("level_select", "")

	var enqueue_params := store.create_object()
	enqueue_params.set_key("title", "RETURN TO TITLE?")
	enqueue_params.set_key("message", "Progress will be lost.")
	enqueue_params.set_key("confirmLabel", "YES")
	enqueue_params.set_key("cancelLabel", "NO")
	enqueue_params.set_key("onConfirmInvocations", store.create_list())
	var enqueue: GnosisFunctionResult = ui.enqueue_confirmation(enqueue_params)
	if not enqueue.is_ok:
		push_error("enqueue_confirmation failed")
		quit(1)
		return true

	var snapshot := ui.build_confirmation_state_snapshot()
	if str(snapshot.get_node("title").value) != "RETURN TO TITLE?":
		push_error("Confirmation title missing")
		quit(1)
		return true

	print("[SUCCESS] GameUI overlay + confirmation fields")
	print("--- GameUI overlay test passed ---")
	quit(0)
	return true
