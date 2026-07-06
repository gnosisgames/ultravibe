extends SceneTree

## Verifies visible GameUI views grab sensible keyboard/controller focus, while
## gameplay releases stale UI focus.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- UI Focus Test ---")
	GnosisRunSave.clear_run_save()
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
	print("--- UI Focus Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		print("[FAIL] GameUI service missing")
		return false

	var ok := true
	ok = _expect_focus("PlayButton", "title view") and ok

	ui.set_base_view("settings")
	ok = _expect_focus("BackButton", "settings view") and ok

	ui.set_base_view("gameplay")
	if _focus_owner() != null:
		print("[FAIL] gameplay view should release UI focus, got %s" % _focus_owner().name)
		ok = false
	else:
		print("[SUCCESS] gameplay releases UI focus")

	var pause_params := engine.store.create_object()
	pause_params.set_key("viewId", "pause")
	pause_params.set_key("overlayStateId", "open")
	ui.invoke_function("PushViewAdditive", pause_params)
	ok = _expect_focus("ResumeButton", "pause overlay") and ok

	return ok

func _expect_focus(expected_name: String, label: String) -> bool:
	var focused := _focus_owner()
	if focused == null:
		print("[FAIL] %s has no focus owner" % label)
		return false
	if focused.name != expected_name:
		print("[FAIL] %s expected focus %s, got %s" % [label, expected_name, focused.name])
		return false
	print("[SUCCESS] %s focuses %s" % [label, expected_name])
	return true

func _focus_owner() -> Control:
	return root.gui_get_focus_owner() as Control
