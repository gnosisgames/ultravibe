extends SceneTree

## Consuming an item-upgrade-grant consumable should add to Ephemeral.upgrades.itemUpgrades.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"
const CatalogSpritePathsScript := preload("res://game/ui/catalog_sprite_paths.gd")
const Match3ServiceScript := preload("res://game/match3/services/match3_service.gd")
const Match3HudItemUpgradesColumnScript := preload("res://game/match3/view/match3_hud_item_upgrades_column.gd")


func _initialize() -> void:
	print("--- Item Upgrade Grant Test ---")
	var ok := _run()
	print("--- Item Upgrade Grant Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _svc(file_name: String):
	return load("%s/%s" % [ADDON, file_name]).new()


func _run() -> bool:
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

	var consumable = engine.get_service("Consumable")
	if consumable == null:
		print("[FAIL] Consumable service missing")
		return false

	var add := store.create_object()
	add.set_key("consumableId", "ItemUpgradeGrantBlueLevelUp")
	var add_res = consumable.invoke_function("AddConsumable", add)
	if add_res is GnosisFunctionResult and not add_res.is_ok:
		print("[FAIL] AddConsumable: %s" % add_res.error)
		return false

	var before := _item_upgrade_count(engine)
	var use := store.create_object()
	use.set_key("consumableId", "ItemUpgradeGrantBlueLevelUp")
	use.set_key("bucketId", "default")
	var use_res = consumable.invoke_function("ConsumeConsumable", use)
	if use_res is GnosisFunctionResult and not use_res.is_ok:
		print("[FAIL] ConsumeConsumable: %s" % use_res.error)
		return false

	var after := _item_upgrade_count(engine)
	if after <= before:
		print("[FAIL] itemUpgrades count did not increase (%d -> %d)" % [before, after])
		return false

	var list := _item_upgrade_list(engine)
	var entry := GnosisNode.new(list.value[0], store)
	var upgrade_id := _read_str(entry, "id")
	if upgrade_id.is_empty():
		upgrade_id = _read_str(entry, "upgradeId")
	if upgrade_id != "BlueLevelUp":
		print("[FAIL] Expected BlueLevelUp entry, got '%s'" % upgrade_id)
		return false

	var sprite_id := ""
	var metadata := entry.get_node("metadata")
	if metadata.is_valid():
		sprite_id = _read_str(metadata, "spriteId")
	var icon_path := CatalogSpritePathsScript.resolve_block_fallback(sprite_id)
	if icon_path.is_empty():
		print("[FAIL] No icon path for spriteId '%s'" % sprite_id)
		return false

	var match3 = engine.get_service("Match3")
	var column := Match3HudItemUpgradesColumnScript.new()
	column.bind_service(match3)
	var entries: Array = column._entries()
	if entries.is_empty():
		print("[FAIL] Item upgrades HUD column returned no entries after grant")
		return false
	var hud_icon := str(entries[0].get("icon_path", ""))
	if hud_icon.is_empty():
		print("[FAIL] Item upgrades HUD column icon_path empty")
		return false

	print("[SUCCESS] itemUpgrades %d -> %d, icon=%s, hud_entries=%d" % [before, after, icon_path, entries.size()])
	return true


func _item_upgrade_list(engine: GnosisEngine) -> GnosisNode:
	var eph: GnosisNode = engine.state.root.get_node("Ephemeral")
	return eph.get_node("upgrades").get_node("itemUpgrades").get_node("list")


func _item_upgrade_count(engine: GnosisEngine) -> int:
	var list := _item_upgrade_list(engine)
	if not list.is_valid() or list.get_type() != GnosisValueType.LIST:
		return 0
	return list.get_count()


func _read_str(node: GnosisNode, key: String) -> String:
	if not node.is_valid():
		return ""
	var child := node.get_node(key)
	if child.is_valid() and child.value != null:
		return str(child.value).strip_edges()
	return ""
