extends SceneTree

## Captures shop HUD + dumps icon bar layout at native window size.

const SupportScript = preload("res://game/match3/boons/match3_boon_support.gd")

var _host: Node = null
var _frames := 0
var _phase := 0


func _initialize() -> void:
	_host = load("res://main.tscn").instantiate()
	root.add_child(_host)


func _engine():
	return _host.engine if _host else null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 25:
		_start_run()
	elif _frames == 90:
		_dump_layout()
		quit(0)
	return false


func _start_run() -> void:
	GnosisRunSave.clear_run_save()
	if _host and _host.has_method("restart_ephemeral_run"):
		_host.restart_ephemeral_run()
	var eng = _engine()
	if eng == null:
		return
	var ephemeral: GnosisNode = eng.state.root.get_node("Ephemeral")
	if ephemeral.is_valid():
		ephemeral.set_key("playerCount", 1)
		ephemeral.set_key("mode", "solo")
	var match3 = eng.get_service("Match3")
	if match3:
		match3.handle_run_started()
	if _host and _host.has_method("resync_match3_board_view"):
		_host.resync_match3_board_view()
	var ui = eng.get_service("GameUI")
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "play", "slide_up")
	var params: GnosisNode = eng.store.create_object()
	params.set_key("gameStatus", "shopPanel")
	match3.invoke_function("TransitionToState", params)


func _dump_layout() -> void:
	var hud = _host.get_tree().get_first_node_in_group("match3_hud") as Control
	if hud == null:
		print("[FAIL] no hud")
		return
	print("=== viewport %s hud.size=%s ===" % [str(get_root().size), str(hud.size)])
	var content := hud.call("get_content_frame_rect") as Rect2
	var planning := hud.call("get_planning_frame_rect") as Rect2
	print("  content_frame global=%s planning_frame global=%s" % [str(content), str(planning)])
	for label in ["BossSection", "BoonsBar", "BoonsChrome", "BoonsRow", "ConsumablesBar", "ConsumablesColumn", "LeftRail"]:
		var node := hud.find_child(label, true, false) as Control
		if node == null:
			print("  %s: missing" % label)
			continue
		print(
			"  %s: size=%s pos=%s global=%s vis=%s children=%d"
			% [
				label,
				str(node.size),
				str(node.position),
				str(node.get_global_rect()),
				str(node.is_visible_in_tree()),
				node.get_child_count(),
			]
		)
	var hud_svc = (hud as Node).get("_service")
	print(
		"  hud.service=%s ctx=%s state=%s"
		% [
			str(hud_svc != null),
			str(hud_svc.context != null if hud_svc else false),
			str(hud_svc.context.state != null if hud_svc and hud_svc.context else false),
		]
	)
	var eph: GnosisNode = _engine().state.root.get_node("Ephemeral")
	var bag := eph.get_node("boons").get_node("default").get_node("list")
	var row := hud.find_child("BoonsRow", true, false) as Control
	print("  boon_bag_count=%d boons_row.service=%s" % [bag.get_count() if bag.is_valid() else -1, str(row.get("_service") if row else "?")])


func _force_refresh_boons() -> void:
	var hud = _host.get_tree().get_first_node_in_group("match3_hud") as Control
	var hud_svc = (hud as Node).get("_service")
	var row := hud.find_child("BoonsRow", true, false) as Control
	if row and row.has_method("force_refresh"):
		var row_svc = row.get("_service")
		print(
			"  row_svc==hud_svc=%s row.ctx=%s row.state=%s"
			% [
				str(row_svc == hud_svc),
				str(row_svc.context != null if row_svc else false),
				str(row_svc.context.state != null if row_svc and row_svc.context else false),
			]
		)
		print(
			"  boons_row entries=%d list_count=%d eph_valid=%s"
			% [
				row.call("_entries").size(),
				row.call("_inventory_list").get_count(),
				str(row.call("_ephemeral").is_valid()),
			]
		)
		row.force_refresh()
	if row:
		print("  after force_refresh BoonsRow children=%d" % row.get_child_count())
		for child in row.get_children():
			if child is Control:
				var icon := child.get_node_or_null("Icon") as TextureRect
				print(
					"  boon_slot %s: slot_size=%s global=%s tex=%s icon_global=%s"
					% [
						child.name,
						str((child as Control).size),
						str((child as Control).get_global_rect()),
						str(icon.texture.resource_path if icon and icon.texture else "null"),
						str(icon.get_global_rect() if icon else "?"),
					]
				)


func _capture() -> void:
	var hud = _host.get_tree().get_first_node_in_group("match3_hud") as Control
	if hud == null:
		return
	var row := hud.find_child("BoonsRow", true, false) as Control
	if row:
		for child in row.get_children():
			if not (child is Control):
				continue
			var icon := child.get_node_or_null("Icon") as TextureRect
			print(
				"  boon_slot %s: slot_size=%s global=%s tex=%s icon_global=%s"
				% [
					child.name,
					str((child as Control).size),
					str((child as Control).get_global_rect()),
					str(icon.texture.resource_path if icon and icon.texture else "null"),
					str(icon.get_global_rect() if icon else "?"),
				]
			)
	var img := root.get_texture().get_image()
	if img:
		img.save_png("res://screenshots/_capture_hud_icon_debug.png")
		print("[SHOT] hud_icon_debug (%dx%d)" % [img.get_width(), img.get_height()])
