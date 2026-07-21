extends SceneTree

## Capture left-rail item upgrades after granting all six color LevelUps.

const LEVEL_UPS := [
	"RedLevelUp",
	"OrangeLevelUp",
	"PurpleLevelUp",
	"BlueLevelUp",
	"GreenLevelUp",
	"PinkLevelUp",
]

var _bootstrap: Node = null
var _frames := 0
var _hud: Control = null


func _initialize() -> void:
	print("--- Capture Kratomania Left Rail ---")
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 30:
		_start_gameplay()
	elif _frames == 50:
		_grant_level_ups()
	elif _frames == 80:
		_save()
		quit(0)
		return true
	elif _frames > 50 and _frames < 80 and _hud and _frames % 5 == 0:
		if _hud.has_method("relayout_content_frame"):
			_hud.relayout_content_frame()
	return false


func _start_gameplay() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	if _bootstrap.has_method("restart_ephemeral_run"):
		_bootstrap.restart_ephemeral_run()
	var m3 := engine.get_service("Match3") as Match3Service
	m3.handle_run_started()
	if _bootstrap.has_method("resync_match3_board_view"):
		_bootstrap.resync_match3_board_view()
	var ui = engine.get_service("GameUI")
	if ui:
		UltraGameUiNav.transition_to_gameplay(ui, engine.store, "play", "slide_up")
	_hud = _bootstrap.get_tree().get_first_node_in_group("match3_hud") as Control
	if _hud == null:
		_hud = _bootstrap.get_node_or_null("UI/GameArea/Hud") as Control
	if _hud:
		_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
		_hud.size = Vector2(1920, 1080)
		if _hud.has_method("refresh_from_service"):
			_hud.refresh_from_service(m3)


func _grant_level_ups() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 := engine.get_service("Match3") as Match3Service
	var upgrade = engine.get_service("Upgrade")
	for upgrade_id in LEVEL_UPS:
		var params := engine.store.create_object()
		params.set_key("categoryId", "itemUpgrades")
		params.set_key("upgradeId", upgrade_id)
		upgrade.invoke_function("AddUpgrade", params)
	if _hud and _hud.has_method("refresh_from_service"):
		_hud.refresh_from_service(m3)
	var item_col := _hud.find_child("ItemUpgradesColumn", true, false) if _hud else null
	if item_col and item_col.has_method("force_refresh"):
		item_col.force_refresh()
	if _hud and _hud.has_method("relayout_content_frame"):
		_hud.relayout_content_frame()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://screenshots")
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no image")
		return
	img.save_png("res://screenshots/_capture_kratomania_left_rail.png")
	print("[SHOT] full (%dx%d)" % [img.get_width(), img.get_height()])
	# Crop left rail strip for easier visual check.
	if _hud:
		var left_rail := _hud.find_child("LeftRail", true, false) as Control
		if left_rail:
			var gr := left_rail.get_global_rect()
			var scale_x := float(img.get_width()) / maxf(1.0, root.size.x)
			var scale_y := float(img.get_height()) / maxf(1.0, root.size.y)
			var x := clampi(int(gr.position.x * scale_x) - 8, 0, img.get_width() - 1)
			var y := clampi(int(gr.position.y * scale_y) - 8, 0, img.get_height() - 1)
			var w := clampi(int(gr.size.x * scale_x) + 24, 1, img.get_width() - x)
			var h := clampi(int(gr.size.y * scale_y) + 16, 1, img.get_height() - y)
			var crop := img.get_region(Rect2i(x, y, w, h))
			crop.save_png("res://screenshots/_capture_kratomania_left_rail_crop.png")
			print("[SHOT] crop (%dx%d) from %s" % [w, h, str(gr)])
			var item_col := _hud.find_child("ItemUpgradesColumn", true, false)
			if item_col:
				print(
					"[info] item_col size=%s slot=%s gap=%s children=%d"
					% [
						str(item_col.size),
						str(item_col.get("slot_size")),
						str(item_col.get("slot_gap")),
						item_col.get_child_count(),
					]
				)
				for child in item_col.get_children():
					print("[info] child %s class=%s size=%s" % [
						child.name,
						child.get_class(),
						str((child as Control).size) if child is Control else "?",
					])
					if child is Control and str(child.name).begins_with("Slot"):
						var slot := child as Control
						var icon := slot.get_node_or_null("Icon") as TextureRect
						print(
							"[info] %s size=%s min=%s stretch=%s"
							% [
								slot.name,
								str(slot.size),
								str(slot.custom_minimum_size),
								str(icon.stretch_mode if icon else -1),
							]
						)
			for child in left_rail.get_children():
				if child is Control:
					print(
						"[info] %s size=%s"
						% [child.name, str((child as Control).size)]
					)
