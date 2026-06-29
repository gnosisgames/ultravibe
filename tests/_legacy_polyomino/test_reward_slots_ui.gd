extends SceneTree

## Diagnostic: boots the full game, enters gameplay, and inspects the inline
## RewardSlots node so we can confirm it binds, activates, and positions.

var _bootstrap: Node = null
var _frames := 0
var _started := false

func _initialize() -> void:
	print("--- Reward Slots UI Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 10:
		return false
	var eng: GnosisEngine = _bootstrap.engine
	var ui := eng.get_service("GameUI") as GnosisGameUIService if eng else null
	if not _started:
		var fb := eng.get_service("FallingBlock") as FallingBlockService
		var ctx0 = fb.context if fb else null
		if ctx0:
			print("[BOOT] offers=%d" % _offer_count(ctx0))
		if fb:
			fb.handle_run_started()
		if ctx0:
			print("[AFTER handle_run_started] offers=%d" % _offer_count(ctx0))
		if ui:
			ui.set_base_view("gameplay")
		_started = true
		return false
	if _frames < 30:
		return false
	_run(eng)
	quit(0)
	return true

func _run(eng: GnosisEngine) -> void:
	var hud := _bootstrap.get_node_or_null("UI/GameArea/Hud")
	print("[INFO] hud=%s" % hud)
	var slots := _find_by_class(hud, "PlayHudRewardSlots") if hud else null
	if slots == null:
		print("[FAIL] RewardSlots node not found / wrong class")
		var node := hud.get_node_or_null("Layout/BoardArea/CenterBoard/BoardSlot/BoardRenderer/GridClip/RewardSlots") if hud else null
		print("[INFO] node at path=%s class=%s" % [node, (node.get_class() if node else "<none>")])
		return
	print("[SUCCESS] RewardSlots class=%s" % slots.get_script().resource_path)
	print("[INFO] visible=%s child_count=%d" % [slots.visible, slots.get_child_count()])
	var ctx = eng.get_service("FallingBlock").context
	var ep: GnosisNode = ctx.state.root.get_node("Ephemeral")
	print("[INFO] includeRewards=%s rewardChoiceCount=%s offers=%d" % [
		FallingBlockGameFlags.is_include_rewards(ctx),
		str(ep.get_node("rewardChoiceCount").value),
		_offer_count(ctx),
	])
	var root_node := slots.get_node_or_null("Slots")
	if root_node:
		print("[INFO] Slots root pos=%s size=%s child=%d" % [root_node.position, root_node.size, root_node.get_child_count()])
		for child in root_node.get_children():
			var icon := child.get_node_or_null("Icon")
			var tex = icon.texture if icon else null
			print("    %s visible=%s pos=%s size=%s icon=%s" % [child.name, child.visible, child.position, child.size, tex])
	else:
		print("[FAIL] Slots HBox root missing")

	var renderer := _find_by_class(hud, "FallingBlockBoardRenderer") if hud else null
	var desc_node := renderer.get_node_or_null("GridClip/BossDescription") if renderer else null
	if desc_node == null and renderer:
		desc_node = _find_child_named(renderer, "BossDescription")
	print("[INFO] BossDescription node=%s" % desc_node)
	var loc = eng.get_service("Localization")
	if loc:
		print("[INFO] zeusLevelDescription -> '%s'" % loc.get_string_value("zeusLevelDescription", "<missing>"))

	var bg := _bootstrap.get_node_or_null("Background") as ColorRect
	print("[INFO] Background color (normal theme) = %s" % (bg.color if bg else "<none>"))
	var theme = eng.get_service("Theme")
	if theme and bg:
		theme.set_current_theme_id("boss_helios")
		print("[INFO] background.main(boss_helios) = '%s'" % theme.get_theme_property("background.main", "<missing>"))

func _offer_count(ctx) -> int:
	var offers: GnosisNode = ctx.state.root.get_node("Ephemeral").get_node("rewardOffers")
	return offers.get_count() if offers.is_valid() and offers.get_type() == GnosisValueType.LIST else 0

func _find_child_named(node: Node, target: String) -> Node:
	for child in node.get_children():
		if child.name == target:
			return child
		var found := _find_child_named(child, target)
		if found:
			return found
	return null

func _find_by_class(node: Node, cls: String) -> Node:
	if node == null:
		return null
	if node.get_script() and node.get_script().get_global_name() == cls:
		return node
	for child in node.get_children():
		var found := _find_by_class(child, cls)
		if found:
			return found
	return null
