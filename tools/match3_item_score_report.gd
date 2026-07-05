extends SceneTree

## Prints per-gem scores for isolated match-3/4/5 lines (no boons, cascades, or floors).
## Mirrors Unity balance spreadsheets: tile profile × N tiles → move score = sum(points) × sum(multi).
##
## Run from ultravibe/:
##   ../scripts/resolve_godot.sh && "$GODOT" --path . --headless --script res://tools/match3_item_score_report.gd
## Optional env: MATCH3_SCORE_MAX_LEVEL=3 (default 5)

const MATCH_SIZES := [3, 4, 5]
const DEFAULT_MAX_LEVEL := 5

var _bootstrap: Node = null
var _frames := 0


func _initialize() -> void:
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	_print_report()
	quit()
	return true


func _print_report() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		push_error("Match3 service missing")
		return

	var max_level := DEFAULT_MAX_LEVEL
	var raw_level := OS.get_environment("MATCH3_SCORE_MAX_LEVEL").strip_edges()
	if raw_level.is_valid_int():
		max_level = maxi(1, raw_level.to_int())
	var item_ids := _sorted_item_ids(m3)
	if item_ids.is_empty():
		push_error("No items in configuration")
		return

	print("")
	print("=== Match3 isolated line scores (no boons / cascades) ===")
	print("Formula: movePoints = N × tilePoints, moveMulti = N × tileMulti, score = movePoints × max(1, moveMulti)")
	print("Levels 1..%d, item type = plain" % max_level)
	print("")

	for level in range(1, max_level + 1):
		_set_all_item_levels(m3, level)
		print("-- Level %d --" % level)
		print("%-8s | %7s | %7s | %7s | %7s | %7s | %7s | %7s | %7s" % [
			"item",
			"pts",
			"multi",
			"m3 pts",
			"m3 mult",
			"m3 score",
			"m4 score",
			"m5 score",
			"avg m3-5",
		])
		print("-".repeat(92))

		var match_totals := {3: 0, 4: 0, 5: 0}
		for item_id in item_ids:
			var profile: Dictionary = m3.call("_resolve_item_score_profile", item_id, "plain")
			var tile_points := int(profile.get("points", 0))
			var tile_multi := int(profile.get("multi", 0))
			var row := _row_for_profile(item_id, tile_points, tile_multi)
			for size in MATCH_SIZES:
				match_totals[size] += int(row.get("m%d_score" % size, 0))
			print("%-8s | %7d | %7d | %7d | %7d | %7d | %7d | %7d | %7d" % [
				item_id,
				tile_points,
				tile_multi,
				int(row.get("m3_pts", 0)),
				int(row.get("m3_mult", 0)),
				int(row.get("m3_score", 0)),
				int(row.get("m4_score", 0)),
				int(row.get("m5_score", 0)),
				int(row.get("avg_score", 0)),
			])

		var count := item_ids.size()
		if count > 0:
			print("-".repeat(92))
			print("%-8s | %7s | %7s | %7d | %7d | %7d | %7d | %7d | %7d" % [
				"AVERAGE",
				"-",
				"-",
				0,
				0,
				int(round(float(match_totals[3]) / count)),
				int(round(float(match_totals[4]) / count)),
				int(round(float(match_totals[5]) / count)),
				int(round(float(match_totals[3] + match_totals[4] + match_totals[5]) / float(count * 3))),
			])
		print("")


func _sorted_item_ids(m3) -> Array[String]:
	var out: Array[String] = []
	var cfg = m3.get_node("configuration", true)
	if not cfg.is_valid():
		return out
	var items: GnosisNode = cfg.get_node("items")
	if not items.is_valid() or items.get_type() != GnosisValueType.OBJECT:
		return out
	for key in items.get_keys():
		var id := str(key).strip_edges()
		if not id.is_empty():
			out.append(id)
	out.sort()
	return out


func _set_all_item_levels(m3, level: int) -> void:
	var m3_state: GnosisNode = m3.get_node("match3", false)
	if not m3_state.is_valid():
		return
	var levels: GnosisNode = m3_state.get_node("itemLevels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		levels = m3.context.store.create_object()
		m3_state.set_node("itemLevels", levels)
	for item_id in _sorted_item_ids(m3):
		levels.set_key(item_id, maxi(1, level))


func _row_for_profile(item_id: String, tile_points: int, tile_multi: int) -> Dictionary:
	var scores := {}
	for size in MATCH_SIZES:
		var move_pts: int = size * tile_points
		var move_mult := maxi(1, size * tile_multi)
		scores["m%d_pts" % size] = move_pts
		scores["m%d_mult" % size] = move_mult
		scores["m%d_score" % size] = move_pts * move_mult
	var avg := int(round(float(scores["m3_score"] + scores["m4_score"] + scores["m5_score"]) / 3.0))
	scores["avg_score"] = avg
	scores["item_id"] = item_id
	return scores
