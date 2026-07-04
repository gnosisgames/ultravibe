extends SceneTree

## Boots a run, opens planning shop, dumps boon icon material state, captures screenshot.

const HolographicCardFxScript = preload("res://game/ui/widgets/holographic_card_fx.gd")
const Match3BoonFoilPreviewScript = preload("res://game/match3/boons/match3_boon_foil_preview.gd")

var _host: Node = null
var _frames := 0


func _initialize() -> void:
	_host = load("res://main.tscn").instantiate()
	root.add_child(_host)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))


func _engine() -> GnosisEngine:
	return _host.engine if _host else null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 20:
		_start_run()
	elif _frames == 55:
		_open_shop()
	elif _frames == 95:
		_diagnose_and_fix_boons()
	elif _frames == 115:
		_save("boons_metallic")
		_save_boons_crop()
		_save_slot_icon_crops()
		_sample_icon_colors()
		quit(0)
	return false


func _start_run() -> void:
	GnosisRunSave.clear_run_save()
	if _host and _host.has_method("restart_ephemeral_run"):
		_host.restart_ephemeral_run()
	var eng := _engine()
	if eng == null:
		return
	var ephemeral: GnosisNode = eng.state.root.get_node("Ephemeral")
	if ephemeral.is_valid():
		ephemeral.set_key("playerCount", 1)
		ephemeral.set_key("mode", "solo")
	var match3 = eng.get_service("Match3")
	if match3:
		match3.handle_run_started()
	var ui = eng.get_service("GameUI")
	if ui and eng:
		UltraGameUiNav.transition_to_gameplay(ui, eng.store, "play", "slide_up")


func _open_shop() -> void:
	var eng := _engine()
	var match3 = eng.get_service("Match3") if eng else null
	if eng == null or match3 == null:
		return
	var params: GnosisNode = eng.store.create_object()
	params.set_key("gameStatus", "shopPanel")
	match3.invoke_function("TransitionToState", params)


func _diagnose_and_fix_boons() -> void:
	var row := _find_boons_row()
	if row == null:
		print("[DIAG] BoonsRow NOT FOUND")
		return
	print("[DIAG] BoonsRow class=%s script=%s slots=%d" % [
		row.get_class(),
		row.get_script(),
		row.get_child_count(),
	])
	for i in range(mini(3, row.get_child_count())):
		var slot: Node = row.get_child(i)
		var icon := slot.get_node_or_null("Icon")
		print("[DIAG] slot %d icon type=%s mat=%s" % [
			i,
			icon.get_class() if icon else "null",
			icon.material if icon else null,
		])
		if icon == null:
			continue
		var settings := Match3BoonFoilPreviewScript.foil_settings_for_slot({}, i)
		if settings.is_empty():
			print("[DIAG] slot %d no preview settings" % i)
			continue
		var mat := HolographicCardFxScript.apply_to(icon, settings)
		print("[DIAG] slot %d applied shader=%s mat_after=%s" % [
			i,
			mat.shader.resource_path if mat and mat.shader else "null",
			icon.material,
		])


func _physical_rect(control: Control) -> Rect2i:
	if control == null:
		return Rect2i()
	var vp := control.get_viewport()
	if vp == null:
		return Rect2i()
	var xform := vp.get_canvas_transform()
	var r: Rect2 = xform * control.get_global_rect()
	return Rect2i(
		Vector2i(int(floor(r.position.x)), int(floor(r.position.y))),
		Vector2i(int(ceil(r.size.x)), int(ceil(r.size.y))),
	)


func _save_boons_crop() -> void:
	var row := _find_boons_row()
	if row == null:
		return
	var rect := _icon_strip_rect(row)
	var full := root.get_texture().get_image()
	if full == null:
		return
	var pad := 12
	var crop := full.get_region(Rect2i(
		maxi(0, rect.position.x - pad),
		maxi(0, rect.position.y - pad),
		mini(full.get_width(), rect.size.x + pad * 2),
		mini(full.get_height(), rect.size.y + pad * 2),
	))
	crop.save_png("res://screenshots/_capture_boons_metallic_crop.png")
	print("[SHOT] saved crop %dx%d rect=%s" % [crop.get_width(), crop.get_height(), rect])


func _icon_strip_rect(row: Node) -> Rect2i:
	var merged := Rect2i()
	var found := false
	for i in range(mini(3, row.get_child_count())):
		var slot: Node = row.get_child(i)
		if not slot is Control:
			continue
		var r := _physical_rect(slot as Control)
		if r.size.x < 4:
			continue
		if not found:
			merged = r
			found = true
		else:
			merged = merged.merge(r)
	if found:
		return merged
	var row_ctrl := row as Control
	return _physical_rect(row_ctrl) if row_ctrl else Rect2i()


func _save_slot_icon_crops() -> void:
	var row := _find_boons_row()
	if row == null:
		return
	var full := root.get_texture().get_image()
	if full == null:
		return
	for i in range(mini(3, row.get_child_count())):
		var slot: Node = row.get_child(i)
		var icon := slot.get_node_or_null("Icon") as Control
		if icon == null:
			continue
		var r := _physical_rect(icon)
		r = r.intersection(Rect2i(Vector2i.ZERO, full.get_size()))
		if r.size.x < 4:
			continue
		var crop := full.get_region(r)
		var path := "res://screenshots/_capture_boon_slot_%d.png" % i
		crop.save_png(path)
		print("[SHOT] saved %s %dx%d" % [path, crop.get_width(), crop.get_height()])


func _sample_icon_colors() -> void:
	var row := _find_boons_row()
	if row == null:
		return
	var full := root.get_texture().get_image()
	if full == null:
		return
	for i in range(mini(3, row.get_child_count())):
		var slot: Node = row.get_child(i)
		var icon := slot.get_node_or_null("Icon") as Control
		if icon == null:
			continue
		var r := _physical_rect(icon)
		r = r.intersection(Rect2i(Vector2i.ZERO, full.get_size()))
		if r.size.x < 4 or r.size.y < 4:
			print("[SAMPLE] slot %d rect too small %s" % [i, r])
			continue
		var sub := full.get_region(r)
		var count := 0
		var sr := 0.0
		var sg := 0.0
		var sb := 0.0
		var min_c := Vector3(999.0, 999.0, 999.0)
		var max_c := Vector3(-1.0, -1.0, -1.0)
		for y in sub.get_height():
			for x in sub.get_width():
				var c := sub.get_pixel(x, y)
				if c.a < 0.15:
					continue
				count += 1
				sr += c.r
				sg += c.g
				sb += c.b
				min_c.x = minf(min_c.x, c.r)
				min_c.y = minf(min_c.y, c.g)
				min_c.z = minf(min_c.z, c.b)
				max_c.x = maxf(max_c.x, c.r)
				max_c.y = maxf(max_c.y, c.g)
				max_c.z = maxf(max_c.z, c.b)
		var mat := icon.material as ShaderMaterial
		var shader_path := mat.shader.resource_path if mat and mat.shader else "none"
		print("[SAMPLE] slot %d shader=%s rect=%s count=%d mean=%s contrast=%s" % [
			i,
			shader_path,
			r,
			count,
			Vector3(sr / maxi(count, 1), sg / maxi(count, 1), sb / maxi(count, 1)),
			max_c - min_c,
		])


func _find_boons_row() -> Node:
	var hud := _host.get_node_or_null("UI/GameArea/Hud")
	if hud == null:
		return null
	return hud.get_node_or_null("BoonsBar/BoonsChrome/BoonsRow")


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	if img == null:
		print("[WARN] no framebuffer image")
		return
	var path := "res://screenshots/_capture_%s.png" % name
	img.save_png(path)
	print("[SHOT] saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
