extends SceneTree

## Diagnose why ModDrizzle may be missing from shop offers (pool vs RNG vs owned).

const MOD_BOON_ID := "ModDrizzle"
const CatalogPolicy := preload("res://game/match3/catalog/match3_run_catalog_offer_policy.gd")
const BoonSupport := preload("res://game/match3/boons/match3_boon_support.gd")
const ModTestEnv := preload("res://tests/helpers/mod_test_env.gd")

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("=== MOD DRIZZLE SHOP DIAGNOSTIC ===")
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
	_run_diagnostic()
	quit(0)
	return true

func _run_diagnostic() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	var shop = engine.get_service("Match3Shop")
	if m3 == null or shop == null:
		print("[FAIL] services missing")
		return

	var config := m3.get_node("configuration", true)
	var boons_root := config.get_node("boons")
	var total := boons_root.get_count() if boons_root.is_valid() else 0
	print("Total boons in catalog: ", total)
	print("ModDrizzle in catalog: ", boons_root.get_node(MOD_BOON_ID).is_valid())

	var all_ids: Array[String] = []
	for key in boons_root.get_keys():
		all_ids.append(str(key))

	var boons_ephemeral := m3.get_node("boons", false)
	var owned := CatalogPolicy.collect_owned_catalog_ids(
		boons_ephemeral,
		m3.get_node("consumables", false),
		m3.get_node("upgrades", false),
	)
	var owned_boons: Dictionary = owned.get("boon", {})
	print("Owned boon count: ", owned_boons.size())
	print("ModDrizzle owned (excluded from shop): ", owned_boons.has(MOD_BOON_ID.to_lower()))

	var pool: Array[String] = CatalogPolicy.build_offer_pool_from_catalog(all_ids, owned_boons, false)
	print("Shop-eligible boon pool size (before legendary filter): ", pool.size())
	print("ModDrizzle in eligible pool: ", pool.has(MOD_BOON_ID))

	# Legendary filter mirrors Match3ShopService._exclude_boons_with_gameplay_tag
	var filtered: Array[String] = []
	for boon_id in pool:
		var entry := config.get_node("boons.%s" % boon_id)
		if entry.is_valid() and BoonSupport.boon_configuration_gameplay_tags_include(entry, "legendary"):
			continue
		filtered.append(boon_id)
	print("After legendary exclusion: ", filtered.size())
	print("ModDrizzle still eligible: ", filtered.has(MOD_BOON_ID))

	var common_pool := BoonSupport.build_boon_catalog_ids_from_configuration(m3, "common")
	print("Common-tier filter count: ", common_pool.size())
	print("ModDrizzle in common filter: ", common_pool.has(MOD_BOON_ID))

	# Monte Carlo: how often does ModDrizzle appear in shop offers?
	var hits := 0
	const TRIALS := 300
	var store := engine.store
	for i in TRIALS:
		shop.invoke_function("RebuildCoreShopOffers", store.create_object())
		var result = shop.invoke_function("GetCoreShop", store.create_object())
		if not (result is GnosisFunctionResult) or not result.is_ok:
			continue
		var core: GnosisNode = result.payload.get_node("core")
		if not core.is_valid():
			continue
		var offers: GnosisNode = core.get_node("offers")
		if not offers.is_valid():
			continue
		for j in offers.get_count():
			var offer: GnosisNode = offers.get_node(j)
			if str(offer.get_node("sourceConfigId").value) == "boons" and str(offer.get_node("itemId").value) == MOD_BOON_ID:
				hits += 1
				break
	var pct := 100.0 * float(hits) / float(TRIALS)
	print("ModDrizzle appeared in %d / %d shop rebuilds (%.1f%%)" % [hits, TRIALS, pct])
	if filtered.has(MOD_BOON_ID) and hits == 0:
		print("[WARN] eligible but 0 hits in %d trials — very unlucky or weighting issue" % TRIALS)
	elif filtered.has(MOD_BOON_ID):
		print("[OK] ModDrizzle is shop-eligible; absence in a single shop is usually RNG (~%.0f%% per visit)." % pct)
	elif owned_boons.has(MOD_BOON_ID.to_lower()):
		print("[INFO] Already owned — shop will not offer it again until sold/removed.")
	else:
		print("[FAIL] ModDrizzle excluded from shop pool — investigate filters.")
	print("--- Mod Drizzle Shop Diagnostic Passed ---")
