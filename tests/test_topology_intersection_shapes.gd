extends SceneTree

## Five-tile L/T/+ intersection classification (Unity MatchTopologyAnalyzer parity).

const TopologyScript = preload("res://game/match3/core/match3_match_topology.gd")
const Models = preload("res://game/match3/core/match3_models.gd")


func _initialize() -> void:
	print("--- Topology Intersection Shapes Test ---")
	var ok := _run()
	print("--- Topology Intersection Shapes Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)


func _coord(x: int, y: int) -> Models.TileCoord:
	return Models.TileCoord.new(x, y)


func _run() -> bool:
	var l_tiles := [
		_coord(0, 0), _coord(0, 1), _coord(0, 2), _coord(1, 2), _coord(2, 2),
	]
	var t_tiles := [
		_coord(0, 0), _coord(1, 0), _coord(2, 0), _coord(1, 1), _coord(1, 2),
	]
	var plus_tiles := [
		_coord(1, 0), _coord(0, 1), _coord(1, 1), _coord(2, 1), _coord(1, 2),
	]
	if TopologyScript.classify_five_tile_intersection_shape(l_tiles) != "l":
		print("[FAIL] expected L shape")
		return false
	if TopologyScript.classify_five_tile_intersection_shape(t_tiles) != "t":
		print("[FAIL] expected T shape")
		return false
	if TopologyScript.classify_five_tile_intersection_shape(plus_tiles) != "plus":
		print("[FAIL] expected plus shape")
		return false

	var result := Models.MatchResult.new()
	result.topology_components = [{
		"shapeKind": TopologyScript.SHAPE_INTERSECTION,
		"tileCount": 5,
		"tiles": plus_tiles.duplicate(),
	}]
	var counts := TopologyScript.accumulate_intersection_five_tile_shape_counts([result])
	if int(counts.get("plus", 0)) != 1 or int(counts.get("l", 0)) != 0:
		print("[FAIL] accumulate counts wrong: %s" % str(counts))
		return false

	print("[SUCCESS] L/T/+ classification ok")
	return true
