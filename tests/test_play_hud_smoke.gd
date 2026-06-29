extends SceneTree

## Smoke test: PlayHud scene loads, binds service, and toggles co-op chrome.

var _bootstrap: Node = null
var _frames := 0
var _phase := 0
var _ok := true

func _initialize() -> void:
	print("--- Play HUD Smoke Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _check(label: String, cond: bool) -> void:
	if cond:
		print("[SUCCESS] %s" % label)
	else:
		print("[FAIL] %s" % label)
		_ok = false

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	match _phase:
		0:
			var hud = _bootstrap.get_node_or_null("UI/GameArea/Hud")
			_check("PlayHud instance present", hud != null and hud.has_method("get_board_slot"))
			if hud:
				_check("BoardSlot present", hud.get_board_slot() != null)
			var eng: GnosisEngine = _bootstrap.engine
			var ui := eng.get_service("GameUI") as GnosisGameUIService if eng else null
			if ui:
				ui.set_base_view("gameplay")
			_phase = 1
		1:
			var hud = _bootstrap.get_node_or_null("UI/GameArea/Hud")
			if hud:
				var slot = hud.get_board_slot()
				var renderer = slot.get_child(0) if slot and slot.get_child_count() > 0 else null
				_check("BoardRenderer reparented under BoardSlot", renderer != null)
			var eng: GnosisEngine = _bootstrap.engine
			if eng:
				var eph := eng.state.root.get_node("Ephemeral")
				if eph.is_valid():
					eph.set_key("playerCount", 3)
			_phase = 2
		2:
			var hud = _bootstrap.get_node_or_null("UI/GameArea/Hud")
			if hud:
				var coop := hud.get_node_or_null("Layout/BoardArea/CenterBoard/CoopOverlay") as CanvasItem
				_check("Co-op overlay visible for 3 players", coop != null and coop.visible)
			print("--- Play HUD Smoke Test %s ---" % ("Passed" if _ok else "FAILED"))
			quit(0 if _ok else 1)
	return false
