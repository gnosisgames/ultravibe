class_name UltravibeRegistry
extends RefCounted

const SHAPES_PATH = "res://data/ultravibe_shapes.json"

var _shapes_by_id: Dictionary = {}

func load_shapes() -> void:
	_shapes_by_id.clear()
	if not FileAccess.file_exists(SHAPES_PATH):
		push_warning("[UltravibeRegistry] Missing shapes file: %s" % SHAPES_PATH)
		return
	var file := FileAccess.open(SHAPES_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var shapes: Dictionary = parsed.get("shapes", {})
	for key in shapes.keys():
		var entry: Dictionary = shapes[key]
		var info := FallingBlockModels.UltravibeInfo.new()
		info.ultravibe_id = str(entry.get("ultravibeId", key))
		info.block_count = int(entry.get("blockCount", 0))
		info.block_offsets = []
		for offset in entry.get("blockOffsets", []):
			if offset is Array and offset.size() >= 2:
				info.block_offsets.append(Vector2i(int(offset[0]), int(offset[1])))
		for tag in entry.get("tags", []):
			info.tags.append(str(tag))
		_shapes_by_id[info.ultravibe_id.to_lower()] = info

func get_shape(ultravibe_id: String) -> FallingBlockModels.UltravibeInfo:
	return _shapes_by_id.get(ultravibe_id.strip_edges().to_lower(), null)

func get_all_shape_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _shapes_by_id.keys():
		ids.append(_shapes_by_id[key].ultravibe_id)
	return ids

func get_random_shape_id(rng: RandomNumberGenerator) -> String:
	var ids := get_all_shape_ids()
	if ids.is_empty():
		return ""
	return ids[rng.randi_range(0, ids.size() - 1)]
