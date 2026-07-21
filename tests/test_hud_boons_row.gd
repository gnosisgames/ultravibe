extends SceneTree

## Focused check: boons row creates visible slots after run start + HUD bind.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

var _bootstrap: Node = null
var _frames := 0
var _started := false
var _finished := false


func _initialize() -> void:
	print("--- HUD Boons Row Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_frames += 1
	if _frames < 30:
		return false
	if not _started:
		_started = true
		_run_async()
	return false


func _run_async() -> void:
	var ok: bool = await _run_checks()
	print("--- HUD Boons Row Test %s ---" % ("Passed" if ok else "FAILED"))
	_finished = true
	quit(0 if ok else 1)


func _run_checks():
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	var hud = _bootstrap.get_node_or_null("UI/GameArea/Hud")
	if hud == null:
		hud = _bootstrap.get_tree().get_first_node_in_group("match3_hud")
	if hud == null:
		print("[FAIL] bootstrap HUD missing")
		return false
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.size = Vector2(1920, 1080)
	await process_frame
	m3.handle_run_started()
	await process_frame
	await process_frame
	for _attempt in range(12):
		if hud.has_method("relayout_content_frame"):
			hud.relayout_content_frame()
		await process_frame

	var boons_row := hud.find_child("BoonsRow", true, false)
	if boons_row == null:
		print("[FAIL] BoonsRow node missing")
		return false
	var bar := hud.find_child("BoonsBar", true, false) as Control
	if boons_row.has_method("force_refresh"):
		boons_row.force_refresh()
	await process_frame
	await process_frame

	var rows := SupportScript.get_active_boon_inventory_slot_rows(m3)
	if rows.is_empty():
		print("[FAIL] dev starter boons not granted")
		return false
	print("[OK] %d equipped boons in ephemeral state" % rows.size())

	if bar == null:
		print("[FAIL] BoonsBar missing")
		return false
	if bar.size.x < 8.0 or bar.size.y < 8.0:
		print("[FAIL] BoonsBar collapsed: %s" % str(bar.size))
		return false
	if boons_row.size.x < 8.0 and _count_boon_slots(boons_row) == 0:
		print("[FAIL] BoonsRow has no width and no slots: %s" % str(boons_row.size))
		return false

	var slot_count := _count_boon_slots(boons_row)
	if slot_count != rows.size():
		print("[FAIL] expected %d slots after refresh, got %d" % [rows.size(), slot_count])
		return false
	if boons_row.slot_size < 32.0:
		print(
			"[FAIL] boons slots too small to read: slot_size=%s bar=%s"
			% [str(boons_row.slot_size), str(bar.size)]
		)
		return false

	var icon_count := 0
	var min_icon_extent := INF
	for child in boons_row.get_children():
		var icon := child.get_node_or_null("Icon") as TextureRect
		if icon == null:
			continue
		if icon.texture != null:
			icon_count += 1
		if child.size.x < 32.0 or child.size.y < 32.0:
			print("[FAIL] slot %s too small: %s" % [child.name, str(child.size)])
			return false
		var icon_rect: Rect2 = icon.get_global_rect()
		if icon.texture != null:
			min_icon_extent = minf(min_icon_extent, minf(icon_rect.size.x, icon_rect.size.y))
		print(
			"  slot %s size=%s icon=%s path=%s" % [
				child.name,
				str(child.size),
				str(icon.texture != null),
				str(icon.texture.resource_path if icon.texture else ""),
			]
		)
		if icon.texture != null and minf(icon_rect.size.x, icon_rect.size.y) < 24.0:
			print("[FAIL] icon on %s has no visible extent: %s" % [child.name, str(icon_rect.size)])
			return false

	if icon_count != rows.size():
		print("[FAIL] expected %d icons with textures, got %d" % [rows.size(), icon_count])
		return false
	if min_icon_extent < 24.0:
		print("[FAIL] smallest icon extent too small: %s" % str(min_icon_extent))
		return false

	print(
		"[OK] boons row shows %d slots with icons; bar=%s row=%s slot_size=%s"
		% [slot_count, str(bar.size), str(boons_row.size), str(boons_row.slot_size)]
	)
	return true


func _count_boon_slots(boons_row: Node) -> int:
	var count := 0
	for child in boons_row.get_children():
		if child is Control and child.get_node_or_null("Icon"):
			count += 1
	return count
