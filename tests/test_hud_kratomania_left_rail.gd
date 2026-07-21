extends SceneTree

## Regression: N item LevelUps must fit inside a fixed section height
## (equal-third rail panel), shrinking like consumables — never overflowing.

const Match3ServiceScript := preload("res://game/match3/services/match3_service.gd")
const Match3HudItemUpgradesColumnScript := preload("res://game/match3/view/match3_hud_item_upgrades_column.gd")
const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const LEVEL_UPS := [
	"RedLevelUp",
	"OrangeLevelUp",
	"PurpleLevelUp",
	"BlueLevelUp",
	"GreenLevelUp",
	"PinkLevelUp",
]
const SECTION_WIDTH := 64.0
const SECTION_HEIGHT := 320.0


func _initialize() -> void:
	print("--- HUD Kratomania Left Rail Layout Test ---")
	var ok := _run()
	print("--- HUD Kratomania Left Rail Layout Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
	# 6 icons in 320px with gap 6 → slot ~= 45 (consumables-style shrink).
	var six := Match3Hud.left_rail_pack_metrics(SECTION_WIDTH, SECTION_HEIGHT, 6)
	if six.x > SECTION_WIDTH + 0.5:
		print("[FAIL] six-pack slot wider than rail: %s" % str(six))
		return false
	var six_span := six.x * 6.0 + six.y * 5.0
	if six_span > SECTION_HEIGHT + 0.5:
		print("[FAIL] six-pack overflows: span=%s pack=%s" % [str(six_span), str(six)])
		return false

	# Many icons: still fit (gap may go negative).
	var many := Match3Hud.left_rail_pack_metrics(SECTION_WIDTH, SECTION_HEIGHT, 40)
	var many_span := many.x * 40.0 + many.y * 39.0
	if many_span > SECTION_HEIGHT + 0.5:
		print("[FAIL] 40-pack overflows: span=%s pack=%s" % [str(many_span), str(many)])
		return false

	var config := GnosisEngineConfig.new()
	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.register_service("Configuration", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_configuration_service.gd"))
	config.register_service("Statistic", GnosisLifetime.SINGLETON, func(): return _svc("gnosis_statistic_service.gd"))
	config.register_service("Seed", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_seed_service.gd"))
	config.register_service("Consumable", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_consumable_service.gd"))
	config.register_service("Upgrade", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_upgrade_service.gd"))
	config.register_service("Audio", GnosisLifetime.TRANSIENT, func(): return _svc("gnosis_audio_service.gd"))
	config.register_service("Match3", GnosisLifetime.TRANSIENT, func(): return Match3ServiceScript.new())

	var store := GnosisStore.new()
	var event_bus := GnosisEventBus.new(store, func(): return null)
	var engine := GnosisEngine.new(config, event_bus, store)
	engine.initialize_permanent_only()
	engine.initialize_non_permanent_services()
	engine.start_run()

	var upgrade = engine.get_service("Upgrade")
	var match3 = engine.get_service("Match3")
	if upgrade == null or match3 == null:
		print("[FAIL] services missing")
		return false

	for upgrade_id in LEVEL_UPS:
		var params := store.create_object()
		params.set_key("categoryId", "itemUpgrades")
		params.set_key("upgradeId", upgrade_id)
		var result = upgrade.invoke_function("AddUpgrade", params)
		if result is GnosisFunctionResult and not result.is_ok:
			print("[FAIL] AddUpgrade %s: %s" % [upgrade_id, result.error])
			return false

	var column := Match3HudItemUpgradesColumnScript.new()
	column.float_offset = 0.0
	column.size = Vector2(SECTION_WIDTH, SECTION_HEIGHT)
	root.add_child(column)
	column.apply_left_rail_pack(six.x, six.y)
	column.set_meta(&"left_rail_budget_h", SECTION_HEIGHT)
	column.bind_service(match3)
	column._relayout_slot_sizes()

	var slot_nodes: Array = column.get("_slot_nodes")
	if slot_nodes.size() < LEVEL_UPS.size():
		print("[FAIL] expected %d slots, got %d" % [LEVEL_UPS.size(), slot_nodes.size()])
		return false

	var slot_size := float(column.get("slot_size"))
	var gap := float(column.get("slot_gap"))
	var span := slot_size * float(slot_nodes.size()) + gap * float(slot_nodes.size() - 1)
	if span > SECTION_HEIGHT + 0.5:
		print("[FAIL] column span overflows section: span=%s h=%s slot=%s gap=%s" % [
			str(span), str(SECTION_HEIGHT), str(slot_size), str(gap)
		])
		return false

	# Gameplay path: inventory force_refresh without a planning-frame dirty.
	# Inflate column height like EXPAND_FILL would, then rebuild — slots must
	# still honor the locked budget, not the inflated size.
	column.size = Vector2(SECTION_WIDTH, SECTION_HEIGHT * 3.0)
	column.force_refresh()
	column.force_refresh()
	column.force_refresh()
	if not _assert_no_slot_dupes(column):
		return false
	slot_nodes = column.get("_slot_nodes")
	slot_size = float(column.get("slot_size"))
	gap = float(column.get("slot_gap"))
	span = slot_size * float(slot_nodes.size()) + gap * float(maxi(slot_nodes.size() - 1, 0))
	if span > SECTION_HEIGHT + 0.5:
		print("[FAIL] post-force_refresh overflow (gameplay path): span=%s budget=%s slot=%s" % [
			str(span), str(SECTION_HEIGHT), str(slot_size)
		])
		return false
	if slot_nodes.size() != LEVEL_UPS.size():
		print("[FAIL] slot count after triple force_refresh: %d" % slot_nodes.size())
		return false
	for slot in slot_nodes:
		if not is_instance_valid(slot):
			continue
		var min_sz: Vector2 = slot.custom_minimum_size
		if absf(min_sz.x - min_sz.y) > 0.5:
			print("[FAIL] non-square slot after force_refresh: %s" % str(min_sz))
			return false
		if min_sz.x > SECTION_WIDTH + 0.5:
			print("[FAIL] slot wider than rail after force_refresh: %s" % str(min_sz))
			return false

	print("[OK] 6 LevelUps fit in section: slot=%.1f gap=%.1f span=%.1f / %.1f" % [
		slot_size, gap, span, SECTION_HEIGHT
	])
	return true


func _assert_no_slot_dupes(column: Control) -> bool:
	var live := 0
	for child in column.get_children():
		if child is Control and str(child.name).begins_with("Slot"):
			live += 1
	var tracked: Array = column.get("_slot_nodes")
	if live != tracked.size():
		print("[FAIL] slot orphan mismatch live=%d tracked=%d" % [live, tracked.size()])
		return false
	return true
