extends SceneTree

const Bridge := preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_mod_loader_bridge.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var err := change_scene_to_file("res://main.tscn")
	if err != OK:
		push_error("Failed to load main.tscn: %s" % err)
		quit(1)
		return
	await process_frame
	await process_frame
	await process_frame
	_print_probe()
	quit(0)

func _print_probe() -> void:
	var root := get_root()
	var store := root.get_node_or_null("/root/ModLoaderStore")
	print("=== MODS PROBE ===")
	print("ModLoaderStore: ", store)
	if store:
		print("mod_load_order size: ", store.mod_load_order.size())
		print("mod_data size: ", store.mod_data.size())
	var scene_root := root.get_node_or_null("Ultravibe")
	if scene_root == null:
		for child in root.get_children():
			if child.name == "Ultravibe":
				scene_root = child
				break
	print("scene root: ", scene_root, " script: ", scene_root.get_script() if scene_root else null)
	if scene_root:
		print("is GnosisGodotEngine: ", scene_root is GnosisGodotEngine)
		print("is UltravibeBootstrap: ", scene_root is UltravibeBootstrap)
	var host := _find_engine(scene_root) if scene_root else null
	print("GnosisGodotEngine host: ", host)
	var perm = null
	if host and host.engine:
		perm = host.engine.get_service("PermanentMod")
	print("PermanentMod service: ", perm)
	if perm:
		print("gnosis loaded mods: ", perm.get_loaded_mods().size())
	var gml := Bridge.get_gml_mod_summaries()
	var all := Bridge.get_all_mod_summaries(perm)
	print("GML summaries: ", gml.size(), " -> ", gml)
	print("All summaries: ", all.size(), " -> ", all)
	var mods_view = root.find_child("ModsView", true, false)
	if mods_view:
		print("ModsView found; visible before: ", mods_view.visible)
		mods_view.visible = true
		print("ModsList children after direct visible=true: ", mods_view.get_node("%ModsList").get_child_count())
		mods_view.set_view_visible(true)
		print("ModsList children after set_view_visible(true): ", mods_view.get_node("%ModsList").get_child_count())

func _find_engine(node: Node) -> Node:
	if node is GnosisGodotEngine:
		return node
	for child in node.get_children():
		var found := _find_engine(child)
		if found:
			return found
	return null
