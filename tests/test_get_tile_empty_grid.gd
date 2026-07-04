extends SceneTree

## Regression: get_tile must not crash when width/height are set but grid is empty (level select preview).

const Match3Gameplay = preload("res://game/match3/core/match3_gameplay.gd")


func _initialize() -> void:
	var gameplay = Match3Gameplay.new()
	gameplay.width = 9
	gameplay.height = 9
	gameplay.grid = []
	var ok := true
	if gameplay.is_grid_allocated():
		print("[FAIL] is_grid_allocated true on empty grid")
		ok = false
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile != null:
				print("[FAIL] expected null tile before load_level at %d,%d" % [x, y])
				ok = false
	if ok:
		print("[SUCCESS] get_tile safe on empty grid with dimensions set")
	else:
		print("[FAIL] get_tile returned unexpected tiles on empty grid")
	quit(0 if ok else 1)
