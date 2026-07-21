extends SceneTree

## Regression: bag grow + layout oscillation must resize slots in place.
## force_refresh on every resized/sync_after_hud_layout freezes the game
## (destroy ↔ rebuild ↔ resize loop). Slot Control identities must stay stable.

const Match3ServiceScript := preload("res://game/match3/services/match3_service.gd")
const ConsumablesColumnScript := preload("res://game/match3/view/match3_hud_consumables_column.gd")
const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"

const COLUMN_W := 80.0
const COLUMN_H := 420.0
const LAYOUT_HAMMER := 40

var _finished := false


func _initialize() -> void:
	print("--- HUD Consumables Layout No Rebuild Loop ---")
	call_deferred("_run_async")


func _process(_delta: float) -> bool:
	return _finished


func _run_async() -> void:
	var ok: bool = await _run()
	print("--- HUD Consumables Layout No Rebuild Loop %s ---" % ("Passed" if ok else "FAILED"))
	_finished = true
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
	var match3 = engine.get_service("Match3")
	if consumable == null or match3 == null:
		print("[FAIL] services missing")
		return false

	for consumable_id in ["Morphomania", "Echomania"]:
		var add := store.create_object()
		add.set_key("consumableId", consumable_id)
		var result = consumable.invoke_function("AddConsumable", add)
		if result is GnosisFunctionResult and not result.is_ok:
			print("[FAIL] AddConsumable %s: %s" % [consumable_id, result.error])
			return false

	var column := ConsumablesColumnScript.new()
	column.size = Vector2(COLUMN_W, COLUMN_H)
	root.add_child(column)
	# _ready installs reorder drag; bind before that NPE on is_drag_active.
	await process_frame
	column.bind_service(match3)
	column.force_refresh()
	await process_frame

	var slots: Array = column.get("_slot_nodes")
	if slots.size() != 2:
		print("[FAIL] expected 2 slots after grants, got %d" % slots.size())
		return false

	var ids: Array[int] = []
	for slot in slots:
		ids.append(int(slot.get_instance_id()))

	for i in LAYOUT_HAMMER:
		# Sub-pixel oscillation that previously triggered is_equal_approx misses
		# and force_refresh destroy/rebuild loops.
		column.size = Vector2(COLUMN_W + float(i % 3) * 0.25, COLUMN_H + float(i % 5) * 0.25)
		column.sync_after_hud_layout()
		column._on_slot_layout_dirty()

	var after: Array = column.get("_slot_nodes")
	if after.size() != 2:
		print("[FAIL] slot count changed during layout hammer: %d" % after.size())
		return false
	for i in after.size():
		var id_now := int(after[i].get_instance_id())
		if id_now != ids[i]:
			print("[FAIL] slot %d rebuilt during layout (was %d now %d) — refresh loop" % [i, ids[i], id_now])
			return false

	print("[OK] 2 slots stable across %d layout hammers" % LAYOUT_HAMMER)
	return true
