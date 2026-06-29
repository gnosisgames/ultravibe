extends SceneTree

## Smoke test: GnosisGodotEngine registers Console service and creates the overlay.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Console Overlay Smoke Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Console Overlay Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false

	var console := engine.get_service("Console") as GnosisConsoleService
	if console == null:
		print("[FAIL] Console service not registered")
		ok = false
	else:
		print("[SUCCESS] Console service registered")

	var overlay := _bootstrap.get_adapter(GnosisConsoleOverlay) as GnosisConsoleOverlay
	if overlay == null:
		print("[FAIL] Console overlay adapter missing")
		ok = false
	else:
		print("[SUCCESS] Console overlay adapter present")

	if console:
		var before := console.get_state_snapshot().get_node("isOpen")
		var was_open := bool(before.value) if before.is_valid() else false
		console.toggle_open()
		var after_open := bool(console.get_state_snapshot().get_node("isOpen").value)
		if not after_open:
			print("[FAIL] Console.ToggleOpen did not open overlay")
			ok = false
		else:
			print("[SUCCESS] Console opened via ToggleOpen")
		console.set_open(was_open)

		var help := console.invoke_command("Help")
		if not help.is_ok:
			print("[FAIL] Help command failed: %s" % help.error)
			ok = false
		else:
			print("[SUCCESS] Help command executed")

		var macros := console.invoke_command("Macros")
		var macro_count := 0
		if macros.is_ok and macros.payload:
			var macros_list := macros.payload.get_node("macros")
			macro_count = macros_list.get_count() if macros_list.is_valid() else 0
		if macro_count <= 0:
			print("[FAIL] no console macros listed")
			ok = false
		else:
			print("[SUCCESS] %d console macros listed" % macro_count)

		var macro_run := console.invoke_command("Macro inspect_settings")
		if not macro_run.is_ok:
			print("[FAIL] inspect_settings macro failed: %s" % macro_run.error)
			ok = false
		else:
			print("[SUCCESS] inspect_settings macro executed")

	return ok
