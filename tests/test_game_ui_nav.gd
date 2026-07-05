extends SceneTree

## Home-from-gameplay must reset the GameUI navigation stack so title menus pop
## back to title instead of the abandoned run.

var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Game UI Nav Test ---")
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
	print("--- Game UI Nav Test %s ---" % ("Passed" if ok else "FAILED"))
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

	ui.initialize_navigation_state("gameplay")
	ui.set_base_view("gameplay")
	UltraGameUiNav.return_to_title(ui)

	if ui.get_base_view_id() != "title":
		print("[FAIL] return_to_title base view=%s" % ui.get_base_view_id())
		return false
	if ui.get_navigation_history_count() != 0:
		print("[FAIL] return_to_title should clear history, count=%d" % ui.get_navigation_history_count())
		return false

	ui.navigate_to_view_state("settings", true)
	var pop_target := ui.peek_pop_target_view_id()
	if pop_target != "title":
		print("[FAIL] settings back target=%s expected title" % pop_target)
		return false

	print("[SUCCESS] home-from-gameplay resets nav stack for title menus")
	return true
