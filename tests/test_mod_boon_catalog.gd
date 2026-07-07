extends SceneTree

## Verifies gnosis_demo merges ModDrizzle into the boon catalog.

const BoonSupport := preload("res://game/match3/boons/match3_boon_support.gd")
const ModTestEnv := preload("res://tests/helpers/mod_test_env.gd")

const MOD_BOON_ID := "ModDrizzle"

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Mod Boon Catalog Test ---")
	ModTestEnv.prepare_enabled_demo_mod()
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _check_mod_boon()
	print("--- Mod Boon Catalog Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check_mod_boon() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	if engine == null:
		print("[FAIL] engine missing")
		return false
	var m3 = engine.get_service("Match3")
	if m3 == null:
		print("[FAIL] Match3 service missing")
		return false
	var boons := m3.get_node("configuration", true).get_node("boons")
	if not boons.is_valid():
		print("[FAIL] configuration.boons missing")
		return false
	var mod_boon := boons.get_node(MOD_BOON_ID)
	if not mod_boon.is_valid():
		print("[FAIL] %s not in configuration.boons" % MOD_BOON_ID)
		return false
	var catalog := BoonSupport.build_boon_catalog_ids_from_configuration(m3, "common")
	if not catalog.has(MOD_BOON_ID):
		print("[FAIL] %s not in common boon shop catalog" % MOD_BOON_ID)
		return false
	print("[SUCCESS] %s merged by gnosis_demo and eligible in shop pool" % MOD_BOON_ID)
	return true
