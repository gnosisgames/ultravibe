class_name Match3MatchTopology
extends RefCounted

## Orthogonal match component topology (Unity MatchTopologyAnalyzer parity).

const Models = preload("res://game/match3/core/match3_models.gd")

const SHAPE_UNKNOWN := "unknown"
const SHAPE_H3 := "straight_line_horizontal_three"
const SHAPE_V3 := "straight_line_vertical_three"
const SHAPE_H4 := "straight_line_horizontal_four"
const SHAPE_V4 := "straight_line_vertical_four"
const SHAPE_H5 := "straight_line_horizontal_five"
const SHAPE_V5 := "straight_line_vertical_five"
const SHAPE_H6 := "straight_line_horizontal_six_plus"
const SHAPE_V6 := "straight_line_vertical_six_plus"
const SHAPE_INTERSECTION := "intersection_lt_plus"
const SHAPE_IRREGULAR := "irregular"


static func fill_result_topology(result: Models.MatchResult, matched: Dictionary) -> void:
	if result == null:
		return
	result.topology_components.clear()
	if matched.is_empty():
		return
	var components := _connected_components(matched)
	for component in components:
		var max_h := _max_axis_run_length(component, true)
		var max_v := _max_axis_run_length(component, false)
		var topo := {
			"shapeKind": _classify_shape(max_h, max_v, component.size()),
			"tileCount": component.size(),
			"maxHorizontalRun": max_h,
			"maxVerticalRun": max_v,
			"tiles": component.duplicate(),
		}
		result.topology_components.append(topo)


static func increment_axis_straight_line_run_counts(shape_kind: String) -> Dictionary:
	var out := {"match3": 0, "match4": 0, "match5": 0}
	match shape_kind:
		SHAPE_H3, SHAPE_V3:
			out["match3"] = 1
		SHAPE_H4, SHAPE_V4:
			out["match4"] = 1
		SHAPE_H5, SHAPE_V5, SHAPE_H6, SHAPE_V6:
			out["match5"] = 1
	return out


static func count_match5_plus_components(results: Array) -> int:
	var count := 0
	for step in results:
		if step == null or not ("topology_components" in step):
			continue
		for topo in step.topology_components:
			if topo is Dictionary and int(topo.get("tileCount", 0)) >= 5:
				count += 1
	return count


static func accumulate_intersection_five_tile_shape_counts(results: Array) -> Dictionary:
	var out := {"l": 0, "t": 0, "plus": 0}
	for step in results:
		if step == null or not ("topology_components" in step):
			continue
		for topo in step.topology_components:
			if not (topo is Dictionary):
				continue
			if str(topo.get("shapeKind", "")) != SHAPE_INTERSECTION:
				continue
			if int(topo.get("tileCount", 0)) != 5:
				continue
			var tiles: Array = topo.get("tiles", [])
			match classify_five_tile_intersection_shape(tiles):
				"l":
					out["l"] = int(out.get("l", 0)) + 1
				"t":
					out["t"] = int(out.get("t", 0)) + 1
				"plus":
					out["plus"] = int(out.get("plus", 0)) + 1
	return out


static func classify_five_tile_intersection_shape(tiles: Array) -> String:
	if tiles.size() != 5:
		return ""
	var cells: Dictionary = {}
	for coord in tiles:
		var x := int(coord.x) if coord != null and "x" in coord else -1
		var y := int(coord.y) if coord != null and "y" in coord else -1
		if x < 0 or y < 0:
			return ""
		cells["%d,%d" % [x, y]] = true
	if cells.size() != 5:
		return ""
	var max_deg := 0
	for key in cells.keys():
		var parts: PackedStringArray = str(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var deg := 0
		if cells.has("%d,%d" % [x - 1, y]):
			deg += 1
		if cells.has("%d,%d" % [x + 1, y]):
			deg += 1
		if cells.has("%d,%d" % [x, y - 1]):
			deg += 1
		if cells.has("%d,%d" % [x, y + 1]):
			deg += 1
		max_deg = maxi(max_deg, deg)
	match max_deg:
		4:
			return "plus"
		3:
			return "t"
		2:
			return "l"
		_:
			return ""


static func _connected_components(matched: Dictionary) -> Array:
	var remaining: Dictionary = matched.duplicate()
	var components: Array = []
	while not remaining.is_empty():
		var start_key: String = remaining.keys()[0]
		var start: Models.TileCoord = remaining[start_key]
		remaining.erase(start_key)
		var component: Array = [start]
		var queue: Array = [start]
		while not queue.is_empty():
			var cur: Models.TileCoord = queue.pop_front()
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = cur.x + offset.x
				var ny: int = cur.y + offset.y
				var key := "%d,%d" % [nx, ny]
				if remaining.has(key):
					var next: Models.TileCoord = remaining[key]
					remaining.erase(key)
					component.append(next)
					queue.append(next)
		components.append(component)
	return components


static func _max_axis_run_length(component: Array, horizontal: bool) -> int:
	var groups: Dictionary = {}
	for coord in component:
		var axis: int = coord.y if horizontal else coord.x
		var line: int = coord.x if horizontal else coord.y
		if not groups.has(axis):
			groups[axis] = []
		(groups[axis] as Array).append(line)
	var max_run := 0
	for axis in groups.keys():
		var ordered: Array = groups[axis]
		ordered.sort()
		var run := 1
		max_run = maxi(max_run, 1)
		for i in range(1, ordered.size()):
			if int(ordered[i]) == int(ordered[i - 1]) + 1:
				run += 1
				max_run = maxi(max_run, run)
			else:
				run = 1
	return max_run


static func _classify_shape(max_h: int, max_v: int, tile_count: int) -> String:
	if tile_count <= 0:
		return SHAPE_UNKNOWN
	if max_h >= 3 and max_v >= 3:
		return SHAPE_INTERSECTION
	if max_h == tile_count and max_v <= 1 and tile_count >= 4:
		if tile_count >= 6:
			return SHAPE_H6
		if tile_count == 5:
			return SHAPE_H5
		return SHAPE_H4
	if max_v == tile_count and max_h <= 1 and tile_count >= 4:
		if tile_count >= 6:
			return SHAPE_V6
		if tile_count == 5:
			return SHAPE_V5
		return SHAPE_V4
	if max_h >= 4 or max_v >= 4:
		return SHAPE_IRREGULAR
	if tile_count == 3 and max_h == 3 and max_v <= 1:
		return SHAPE_H3
	if tile_count == 3 and max_v == 3 and max_h <= 1:
		return SHAPE_V3
	if tile_count <= 2:
		return SHAPE_UNKNOWN
	return SHAPE_IRREGULAR
