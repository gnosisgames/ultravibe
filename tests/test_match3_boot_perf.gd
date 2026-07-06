extends SceneTree

## Sprint 8: headless boot budget — main.tscn to engine ready.

const BOOT_BUDGET_USEC := 8_000_000 # 8s soft cap (headless dev Mac)

var _t0_usec := 0
var _bootstrap: Node = null
var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Match3 Boot Perf Test ---")
	_t0_usec = Time.get_ticks_usec()
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Match3 Boot Perf Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _run() -> bool:
	var elapsed_usec := Time.get_ticks_usec() - _t0_usec
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing after boot")
		return false
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing after boot")
		return false
	var ms := float(elapsed_usec) / 1000.0
	print("[INFO] boot to engine ready: %.1f ms (%d frames)" % [ms, _frames])
	if elapsed_usec > BOOT_BUDGET_USEC:
		print("[FAIL] boot exceeded budget %.1f ms > %.1f ms" % [ms, float(BOOT_BUDGET_USEC) / 1000.0])
		return false
	print("[OK] headless boot within budget")
	return true
