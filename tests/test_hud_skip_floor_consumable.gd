extends SceneTree

## Full scene: skip, use floor mania via consumables column juice path (editor repro).

var _bootstrap: Node = null
var _frames := 0
var _phase := 0
var _column: Match3HudConsumablesColumn = null
var _m3: Match3Service = null
var _dispatcher = null
var _slot := -1

func _initialize() -> void:
	print("--- HUD Skip Floor Consumable Test ---")
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
				if _m3 != null and _m3.has_method("is_consumable_use_presentation_active"):
					if not _m3.is_consumable_use_presentation_active():
						if _verify():
							print("[SUCCESS] HUD skip + floor consumable without crash")
							print("--- HUD Skip Floor Consumable Test Passed ---")
							quit(0)
							return true
				return false
			if not _verify():
				_fail("verify")
				return true
			print("[SUCCESS] HUD skip + floor consumable without crash")
			print("--- HUD Skip Floor Consumable Test Passed ---")
			quit(0)
			return true
	return false

func _setup() -> bool:
	if _bootstrap.has_method("restart_ephemeral_run"):
		_bootstrap.restart_ephemeral_run()
	var engine: GnosisEngine = _bootstrap.engine
	_m3 = engine.get_service("Match3") as Match3Service
	if _m3 == null:
		return false
	_m3.handle_run_started()
	if _bootstrap.has_method("resync_match3_board_view"):
		_bootstrap.resync_match3_board_view()
	var skip = _m3.invoke_function("SkipLevel", engine.store.create_object())
	if skip == null or not skip.is_ok or not _payload_bool(skip.payload, "success", false):
		print("[FAIL] SkipLevel: %s" % str(skip))
		return false
	if _bootstrap.has_method("resync_match3_board_view"):
		_bootstrap.resync_match3_board_view()
	var consumable: GnosisConsumableService = engine.get_service("Consumable") as GnosisConsumableService
	_slot = _first_consumable_slot(consumable)
	if _slot < 0:
		print("[FAIL] no consumable after skip")
		return false
	var add := engine.store.create_object()
	add.set_key("consumableId", "Chrysomania")
	add.set_key("bucketId", "default")
	consumable.invoke_function("AddConsumable", add)
	_slot = _consumable_slot_for_id(_m3, "Chrysomania")
	if _slot < 0:
		print("[FAIL] Chrysomania not in bag")
		return false
	_column = _find_consumables_column()
	if _column == null:
		print("[FAIL] Match3HudConsumablesColumn missing")
		return false
	_column.bind_service(_m3)
	_dispatcher = _bootstrap.get_tree().get_first_node_in_group("match3_dispatcher")
	if _column.has_method("_use_slot_at_index"):
		_column._use_slot_at_index(_slot)
	else:
		print("[FAIL] consumables column missing _use_slot_at_index")
		return false
	return true

func _verify() -> bool:
	if _column != null and _column.has_method("_juice_running") == false:
		pass
	if _m3 != null and _m3.has_method("is_consumable_use_presentation_active"):
		if _m3.is_consumable_use_presentation_active():
			print("[FAIL] consumable presentation still active after juice")
			return false
	if _dispatcher != null and (_dispatcher._width > 0 or _dispatcher._height > 0):
		print("[FAIL] dispatcher not empty: %dx%d" % [_dispatcher._width, _dispatcher._height])
		return false
	var counts: Dictionary = _m3.get_enhanced_floor_tile_counts()
	if int(counts.get("Gold", 0)) < 2:
		print("[FAIL] pool not updated: %s" % str(counts))
		return false
	return true

func _find_consumables_column() -> Match3HudConsumablesColumn:
	for node in _bootstrap.get_tree().get_nodes_in_group("match3_hud"):
		var found := _find_column_in(node)
		if found:
			return found
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

func _consumable_slot_for_id(m3: Match3Service, consumable_id: String) -> int:
	if m3 == null or not m3.has_method("_consumable_list_count"):
		return -1
	var want := consumable_id.strip_edges()
	var count := int(m3.call("_consumable_list_count"))
	for i in count:
		if str(m3.call("_read_consumable_id_at_index", i)).strip_edges() == want:
			return i
	return -1

func _first_consumable_slot(consumable: GnosisConsumableService) -> int:
	var params := consumable.context.store.create_object()
	params.set_key("bucketId", "default")
	var result = consumable.invoke_function("GetCount", params)
	var payload: GnosisNode = result.payload if result is GnosisFunctionResult and result.is_ok else result
	if payload == null or not payload.is_valid():
		return -1
	var count := int(payload.get_node("count").value) if payload.get_node("count").is_valid() else 0
	return 0 if count > 0 else -1

func _payload_bool(payload: GnosisNode, key: String, default_value: bool) -> bool:
	if payload == null or not payload.is_valid():
		return default_value
	var child := payload.get_node(key)
	if not child.is_valid() or child.value == null:
		return default_value
	return bool(child.value)

func _fail(reason: String) -> void:
	print("[FAIL] HUD skip floor consumable (%s)" % reason)
	print("--- HUD Skip Floor Consumable Test FAILED ---")
	quit(1)
