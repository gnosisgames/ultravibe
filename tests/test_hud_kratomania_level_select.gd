extends SceneTree

## Kratomania (upgrade mania) on level select before PlayLevel — full HUD juice path.

var _bootstrap: Node = null
var _frames := 0
var _phase := 0
var _column: Match3HudConsumablesColumn = null
var _m3: Match3Service = null

func _initialize() -> void:
	print("--- HUD Kratomania Level Select Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 15:
		return false
	match _phase:
		0:
			if not _setup():
				_fail("setup")
				return true
			_phase = 1
			_frames = 0
		1:
			if _frames < 180:
				if _m3 != null and not _m3.is_consumable_use_presentation_active():
					if _verify():
						print("[SUCCESS] Kratomania consumable on level select")
						print("--- HUD Kratomania Level Select Test Passed ---")
						quit(0)
						return true
				return false
			if not _verify():
				_fail("verify")
				return true
			print("[SUCCESS] Kratomania consumable on level select")
			print("--- HUD Kratomania Level Select Test Passed ---")
			quit(0)
			return true
	return false

func _setup() -> bool:
	if _bootstrap.has_method("restart_ephemeral_run"):
		_bootstrap.restart_ephemeral_run()
	var engine: GnosisEngine = _bootstrap.engine
	_m3 = engine.get_service("Match3") as Match3Service
	var consumable: GnosisConsumableService = engine.get_service("Consumable") as GnosisConsumableService
	if _m3 == null or consumable == null:
		return false
	_m3.handle_run_started()
	if _bootstrap.has_method("resync_match3_board_view"):
		_bootstrap.resync_match3_board_view()
	var add := engine.store.create_object()
	add.set_key("consumableId", "Kratomania")
	add.set_key("bucketId", "default")
	consumable.invoke_function("AddConsumable", add)
	var slot := _consumable_slot_for_id(_m3, "Kratomania")
	if slot < 0:
		print("[FAIL] Kratomania not in bag")
		return false
	_column = _find_consumables_column()
	if _column == null:
		print("[FAIL] consumables column missing")
		return false
	_column.bind_service(_m3)
	_column._use_slot_at_index(slot)
	return true

func _verify() -> bool:
	if _m3.is_consumable_use_presentation_active():
		print("[FAIL] presentation still active")
		return false
	var upgrade = _m3.context.engine.get_service("Upgrade")
	if upgrade == null:
		print("[FAIL] Upgrade service missing")
		return false
	var params := _m3.context.store.create_object()
	params.set_key("categoryId", "itemUpgrades")
	params.set_key("upgradeId", "RedLevelUp")
	var result = upgrade.invoke_function("HasUpgrade", params)
	var payload: GnosisNode = result.payload if result is GnosisFunctionResult and result.is_ok else result
	if payload == null or not payload.is_valid() or not bool(payload.get_node("hasUpgrade").value):
		print("[FAIL] RedLevelUp not applied after Kratomania")
		return false
	return true

func _consumable_slot_for_id(m3: Match3Service, consumable_id: String) -> int:
	var count := int(m3.call("_consumable_list_count"))
	for i in count:
		if str(m3.call("_read_consumable_id_at_index", i)).strip_edges() == consumable_id:
			return i
	return -1

func _find_consumables_column() -> Match3HudConsumablesColumn:
	var hud := _bootstrap.get_node_or_null("UI/GameArea/Hud")
	if hud:
		return _find_column_in(hud)
	return null

func _find_column_in(root: Node) -> Match3HudConsumablesColumn:
	if root is Match3HudConsumablesColumn:
		return root as Match3HudConsumablesColumn
	for child in root.get_children():
		var found := _find_column_in(child)
		if found:
			return found
	return null

func _fail(reason: String) -> void:
	print("[FAIL] HUD Kratomania (%s)" % reason)
	print("--- HUD Kratomania Level Select Test FAILED ---")
	quit(1)
