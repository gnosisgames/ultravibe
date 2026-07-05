extends SceneTree

## Skip round 1, use the granted floor consumable before PlayLevel (user repro).

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Skip Then Floor Consumable Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 12:
		return false
	if _done:
		return true
	_done = true
	var ok := _check()
	print("--- Skip Then Floor Consumable Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _check() -> bool:
	var host = _bootstrap
	if host.has_method("restart_ephemeral_run"):
		host.restart_ephemeral_run()
	var engine: GnosisEngine = host.engine
	var m3: Match3Service = engine.get_service("Match3") as Match3Service
	if m3 == null:
		print("[FAIL] Match3 missing")
		return false
	m3.handle_run_started()
	if m3.get_gameplay().is_grid_allocated():
		print("[FAIL] grid should not be allocated before PlayLevel")
		return false
	var dispatcher := host.get_tree().get_first_node_in_group("match3_dispatcher")
	if dispatcher and dispatcher.has_method("bind_service"):
		dispatcher.bind_service(m3)
	var skip = m3.invoke_function("SkipLevel", engine.store.create_object())
	if skip == null or not skip.is_ok or not _payload_bool(skip.payload, "success", false):
		print("[FAIL] SkipLevel failed: %s" % str(skip))
		return false
	var consumable: GnosisConsumableService = engine.get_service("Consumable") as GnosisConsumableService
	var slot := _first_consumable_slot(consumable)
	if slot < 0:
		print("[FAIL] no consumable after skip")
		return false
	var consumable_id := _skip_reward_consumable_id(m3)
	if consumable_id.is_empty():
		consumable_id = _consumable_id_at_slot(m3, slot)
	if not m3.try_consume_consumable_at_slot_presentation(slot):
		print("[FAIL] consumable use failed after skip")
		return false
	if dispatcher and dispatcher.has_method("bind_service"):
		dispatcher.bind_service(m3)
	if dispatcher != null and (dispatcher._width > 0 or dispatcher._height > 0):
		print("[FAIL] dispatcher should stay empty before PlayLevel (%dx%d)" % [dispatcher._width, dispatcher._height])
		return false
	if _consumable_adds_floor_pool(consumable_id):
		var counts: Dictionary = m3.get_enhanced_floor_tile_counts()
		var total := 0
		for k in counts.keys():
			total += int(counts[k])
		if total <= 0:
			print("[FAIL] floor pool empty after floor mania consumable '%s': %s" % [consumable_id, str(counts)])
			return false
		print("[SUCCESS] skip + floor consumable before play (id=%s pool=%s)" % [consumable_id, str(counts)])
	else:
		print("[SUCCESS] skip + consumable before play without crash (id=%s)" % consumable_id)
	return true

func _skip_reward_consumable_id(m3: Match3Service) -> String:
	var m3_node := m3.get_node("match3", false)
	if not m3_node.is_valid():
		return ""
	var last := m3_node.get_node("lastRoundActionReward")
	if not last.is_valid():
		return ""
	var id_node := last.get_node("consumableId")
	if id_node.is_valid() and id_node.value != null:
		return str(id_node.value).strip_edges()
	return ""

func _consumable_id_at_slot(m3: Match3Service, slot: int) -> String:
	if m3 == null or not m3.has_method("_read_consumable_id_at_index"):
		return ""
	return str(m3.call("_read_consumable_id_at_index", slot)).strip_edges()

func _consumable_adds_floor_pool(consumable_id: String) -> bool:
	var path := "res://data/Consumables/%s.json" % consumable_id
	if not ResourceLoader.exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var invocations: Array = parsed.get("properties", {}).get("invocations", [])
	for entry in invocations:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		if str(entry.get("function", "")) == "AddFloorModifierPoolDelta":
			return true
	return false

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
