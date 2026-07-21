extends SceneTree

## Simulates in-game HUD bind + frame_dirty cycles without manual force_refresh.
## Fails when icon TextureRects have null textures or zero visible global extent.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

const MIN_ICON_EXTENT := 24.0
const MIN_FRAMES_BEFORE_CHECK := 45
const LAYOUT_CYCLES := 8

var _bootstrap: Node = null
var _frames := 0
var _started := false
var _finished := false


func _initialize() -> void:
	print("--- HUD Icon Bars Diagnostic ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	if _finished:
		return true
	_frames += 1
	if _frames < MIN_FRAMES_BEFORE_CHECK:
		return false
	if not _started:
		_started = true
		_run_async()
	return false


func _run_async() -> void:
	var ok: bool = await _run_checks()
	print("--- HUD Icon Bars Diagnostic %s ---" % ("Passed" if ok else "FAILED"))
	_finished = true
	quit(0 if ok else 1)


func _run_checks() -> bool:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3")
	var hud = _bootstrap.get_node_or_null("UI/GameArea/Hud")
	if hud == null:
		hud = _bootstrap.get_tree().get_first_node_in_group("match3_hud")
	if hud == null:
		print("[FAIL] HUD missing")
		return false

	# Match typical gameplay viewport without forcing icon rebuilds.
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.size = Vector2(1920, 1080)
	await process_frame
	if _bootstrap.has_method("restart_ephemeral_run"):
		_bootstrap.restart_ephemeral_run()
		await process_frame
		m3 = engine.get_service("Match3")
	m3.handle_run_started()
	await process_frame
	if hud.has_method("refresh_from_service"):
		hud.refresh_from_service(m3)
		await process_frame

	var boons_row := hud.find_child("BoonsRow", true, false)
	if boons_row and boons_row.get("_service") != hud.get("_service"):
		print("[FAIL] BoonsRow bound to stale Match3 service after restart")
		return false

	for _i in range(LAYOUT_CYCLES):
		if hud.has_method("relayout_content_frame"):
			hud.relayout_content_frame()
		await process_frame

	var boons_bar := hud.find_child("BoonsBar", true, false) as Control
	var boons_chrome := hud.find_child("BoonsChrome", true, false) as Control
	var consumables_col := hud.find_child("ConsumablesColumn", true, false)
	var consumables_bar := hud.find_child("ConsumablesBar", true, false) as Control
	var run_upgrades := hud.find_child("RunUpgradesColumn", true, false)
	var item_upgrades := hud.find_child("ItemUpgradesColumn", true, false)
	var enhanced_tiles := hud.find_child("EnhancedTilesColumn", true, false)

	_dump_layout("BoonsBar", boons_bar)
	_dump_layout("BoonsChrome", boons_chrome)
	_dump_layout("BoonsRow", boons_row)
	_dump_layout("ConsumablesBar", consumables_bar)
	_dump_layout("ConsumablesColumn", consumables_col)
	_dump_layout("RunUpgradesColumn", run_upgrades)
	_dump_layout("EnhancedTilesColumn", enhanced_tiles)

	if boons_chrome == null or boons_chrome.size.x < 8.0 or boons_chrome.size.y < 8.0:
		print("[FAIL] BoonsChrome collapsed: %s" % str(boons_chrome.size if boons_chrome else "missing"))
		return false
	if consumables_col == null or consumables_col.size.x < 8.0 or consumables_col.size.y < 8.0:
		print("[FAIL] ConsumablesColumn collapsed: %s" % str(consumables_col.size if consumables_col else "missing"))
		return false

	var boon_rows := SupportScript.get_active_boon_inventory_slot_rows(m3)
	if boon_rows.is_empty():
		print("[FAIL] no starter boons in ephemeral state")
		return false

	if not _check_icon_bar(
		"boons",
		boons_row,
		boon_rows.size(),
		func(slot: Control) -> TextureRect:
			return slot.get_node_or_null("Icon") as TextureRect
	):
		return false

	if not _check_icon_bar(
		"consumables",
		consumables_col,
		_count_slots_with_icon(consumables_col),
		func(slot: Control) -> TextureRect:
			return slot.get_node_or_null("Icon") as TextureRect,
		true
	):
		return false

	if run_upgrades and _count_slots_with_icon(run_upgrades) > 0:
		if not _check_icon_bar(
			"run_upgrades",
			run_upgrades,
			_count_slots_with_icon(run_upgrades),
			func(slot: Control) -> TextureRect:
				return slot.get_node_or_null("Icon") as TextureRect
		):
			return false

	if item_upgrades and _count_slots_with_icon(item_upgrades) > 0:
		if not _check_icon_bar(
			"item_upgrades",
			item_upgrades,
			_count_slots_with_icon(item_upgrades),
			func(slot: Control) -> TextureRect:
				return slot.get_node_or_null("Icon") as TextureRect
		):
			return false

	if enhanced_tiles and enhanced_tiles is Control and (enhanced_tiles as Control).size.y >= 8.0:
		if enhanced_tiles.get_child_count() > 0:
			if not _check_icon_bar(
				"enhanced_tiles",
				enhanced_tiles,
				enhanced_tiles.get_child_count(),
				func(row: Control) -> TextureRect:
					for child in row.get_children():
						if child is TextureRect:
							return child as TextureRect
					return null
			):
				return false
		else:
			print("[OK] enhanced_tiles column sized but empty")
	elif enhanced_tiles and enhanced_tiles.get_child_count() > 0:
		print("[WARN] enhanced_tiles has rows but column not laid out yet")

	print("[OK] all checked HUD icon bars have visible textures and extents")
	return true


func _check_icon_bar(
	region: String,
	host: Node,
	expected_count: int,
	get_icon: Callable,
	allow_zero_slots: bool = false
) -> bool:
	if host == null:
		print("[FAIL] %s host missing" % region)
		return false
	if expected_count <= 0:
		if allow_zero_slots:
			print("[OK] %s empty (allowed)" % region)
			return true
		print("[FAIL] %s expected slots > 0, got %d" % [region, expected_count])
		return false

	var icon_count := 0
	var min_extent := INF
	for child in host.get_children():
		if not (child is Control):
			continue
		if child.name == "ReorderLayoutHost" or str(child.name).ends_with("FloatHost"):
			continue
		var icon: TextureRect = get_icon.call(child)
		if icon == null:
			continue
		var extent: float = _icon_visible_extent(icon)
		var parent_name: String = icon.get_parent().name if icon.get_parent() else "?"
		print(
			"  [%s] slot=%s parent=%s tex=%s global=%s modulate=%s"
			% [
				region,
				child.name,
				parent_name,
				str(icon.texture.resource_path if icon.texture else "null"),
				str(icon.get_global_rect().size),
				str(icon.modulate),
			]
		)
		if icon.texture != null and extent >= MIN_ICON_EXTENT:
			icon_count += 1
			min_extent = minf(min_extent, extent)

	if icon_count != expected_count:
		print(
			"[FAIL] %s expected %d visible icons, got %d (host_size=%s)"
			% [region, expected_count, icon_count, str((host as Control).size if host is Control else "?")]
		)
		return false
	if min_extent < MIN_ICON_EXTENT:
		print("[FAIL] %s smallest icon extent %s < %s" % [region, str(min_extent), str(MIN_ICON_EXTENT)])
		return false
	print("[OK] %s shows %d icons (min_extent=%.1f)" % [region, icon_count, min_extent])
	return true


func _icon_visible_extent(icon: TextureRect) -> float:
	if icon == null or icon.texture == null:
		return 0.0
	var rect := icon.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 0.0
	if icon.modulate.a <= 0.01 or icon.scale.x <= 0.01 or icon.scale.y <= 0.01:
		return 0.0
	return minf(rect.size.x, rect.size.y)


func _count_slots_with_icon(host: Node) -> int:
	if host == null:
		return 0
	var count := 0
	for child in host.get_children():
		if child is Control and child.get_node_or_null("Icon"):
			count += 1
	return count


func _dump_layout(label: String, node: Node) -> void:
	if node == null:
		print("  layout %s: <missing>" % label)
		return
	if not (node is Control):
		print("  layout %s: not a Control" % label)
		return
	var ctrl := node as Control
	print(
		"  layout %s: size=%s global=%s visible=%s"
		% [label, str(ctrl.size), str(ctrl.get_global_rect().size), str(ctrl.is_visible_in_tree())]
	)
