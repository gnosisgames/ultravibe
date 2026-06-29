extends SceneTree

## Parity: every FallingBlock function referenced in data is registered on the service.

var _bootstrap: Node = null
var _frames := 0
var _done := false

const REQUIRED := [
	"AddBaseDiscardsDelta", "AddDiscards", "AddVariantLevelDelta",
	"ApplyEffect", "ApplyStackGravityAndClear", "ChangeFallSpeed",
	"ClearEntireGridAndRespawn", "ClearRandomNonEmptyLockedRows",
	"ClearRowsAboveLowestNonEmptyColumnHeight", "DestroyCurrentPiece",
	"DuplicateCurrentDeckEntry", "ExecuteGridShiftAbility",
	"FillSingleGapsInNonEmptyRowsAndClear", "GrantRandomEligibleUpgrade",
	"MirrorRightHalfToLeftAndClear", "PlayFallingPieceFeedback",
	"RemoveEffect", "SetFallingPieceVariant", "SpawnTrashLines",
]

func _initialize() -> void:
	print("--- Parity Content Catalog Test ---")
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
	print("--- Parity Content Catalog Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var fb := _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
	var registered: Array = fb.get_functions()
	for fn in REQUIRED:
		if fn not in registered:
			print("[FAIL] missing registered function '%s'" % fn)
			ok = false
		else:
			print("[SUCCESS] registered: %s" % fn)

	var counts := {
		"consumables": _count_dir("res://data/Consumables"),
		"abilities": _count_dir("res://data/Abilities"),
		"upgrades": _count_dir("res://data/Upgrades"),
		"itemUpgrades": _count_dir("res://data/ItemUpgrades"),
		"bosses": _count_dir("res://data/Bosses"),
		"boons": _count_dir("res://data/Boons"),
	}
	for k in counts.keys():
		print("[INFO] %s catalog entries: %d" % [k, counts[k]])
		if counts[k] <= 0:
			print("[FAIL] empty catalog %s" % k)
			ok = false

	return ok

func _count_dir(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var n := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			n += 1
		name = dir.get_next()
	dir.list_dir_end()
	return n
