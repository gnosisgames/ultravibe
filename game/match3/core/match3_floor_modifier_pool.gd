class_name Match3FloorModifierPool
extends RefCounted

## Run-scoped floor modifier pool (Unity Ephemeral.match3.floorModifierPool parity).

const POOL_SIZE := 100
const POOL_KEY := "floorModifierPool"
const KEY_EMPTY := "empty"
const KEY_RANDOM := "Random"
const RESERVED_KEYS := [KEY_EMPTY, KEY_RANDOM]


static func ensure_pool(m3: GnosisNode, store: GnosisStore) -> void:
	if m3 == null or not m3.is_valid() or store == null:
		return
	var pool := m3.get_node(POOL_KEY)
	if pool.is_valid() and pool.get_type() == GnosisValueType.OBJECT:
		var counts := read_pool_dict(pool)
		if pool_sum(counts) == POOL_SIZE:
			return
	var fresh: GnosisNode = store.create_object()
	fresh.set_key(KEY_EMPTY, POOL_SIZE)
	m3.set_node(POOL_KEY, fresh)


static func add_delta(
	m3: GnosisNode,
	store: GnosisStore,
	floor_type_id: String,
	requested: int,
	known_type_ids: Array[String],
	rng: RandomNumberGenerator
) -> Dictionary:
	var result := {"applied": 0, "error": ""}
	if m3 == null or not m3.is_valid() or store == null:
		result["error"] = "match3_missing"
		return result
	var type_id := floor_type_id.strip_edges()
	if type_id.is_empty() or type_id.to_lower() == KEY_EMPTY.to_lower():
		result["error"] = "floor_pool_invalid_type"
		return result
	ensure_pool(m3, store)
	var pool := m3.get_node(POOL_KEY)
	var counts := read_pool_dict(pool)
	normalize_pool(counts)
	var applied := 0
	if type_id.to_lower() == KEY_RANDOM.to_lower():
		if known_type_ids.is_empty():
			result["error"] = "floor_pool_unknown_type"
			return result
		var count := clampi(requested, 1, POOL_SIZE)
		for _i in count:
			var picked := known_type_ids[rng.randi_range(0, known_type_ids.size() - 1)]
			applied += apply_one_delta(counts, picked)
	else:
		if not known_type_ids.has(type_id):
			result["error"] = "floor_pool_unknown_type"
			return result
		var delta := clampi(requested, 1, POOL_SIZE)
		applied = apply_one_delta(counts, type_id, delta)
	if applied <= 0:
		result["error"] = "floor_pool_no_slots_applied"
		return result
	write_pool_dict(pool, counts)
	m3.set_key("floorModifierPoolSize", POOL_SIZE)
	result["applied"] = applied
	return result


static func apply_one_delta(counts: Dictionary, floor_type_id: String, requested: int = 1) -> int:
	var tid := floor_type_id.strip_edges()
	var current_target: int = int(counts.get(tid, 0))
	var room := POOL_SIZE - current_target
	var delta := mini(requested, room)
	if delta <= 0:
		return 0
	var moved := 0
	while moved < delta:
		var empty: int = int(counts.get(KEY_EMPTY, 0))
		if empty > 0:
			counts[KEY_EMPTY] = empty - 1
			moved += 1
			continue
		if not consume_one_non_target_non_empty(counts, tid):
			break
		moved += 1
	if moved <= 0:
		return 0
	counts[tid] = current_target + moved
	return moved


static func consume_one_non_target_non_empty(counts: Dictionary, target_type_id: String) -> bool:
	var keys: Array = counts.keys()
	keys.sort()
	for key in keys:
		var id := str(key)
		if id.to_lower() == KEY_EMPTY.to_lower():
			continue
		if id.to_lower() == target_type_id.to_lower():
			continue
		var n: int = int(counts[id])
		if n <= 0:
			continue
		counts[id] = n - 1
		return true
	return false


static func apply_layout_to_gameplay(gameplay, pool: GnosisNode, rng: RandomNumberGenerator) -> void:
	if gameplay == null or pool == null or not pool.is_valid():
		return
	if not _is_board_grid_ready(gameplay):
		return
	var counts := read_pool_dict(pool)
	normalize_pool(counts)
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			tile.cell_floor_type_id = ""
	var multiset: Array[String] = []
	for key in counts.keys():
		var id := str(key)
		if id.to_lower() == KEY_EMPTY.to_lower():
			continue
		var n: int = int(counts[id])
		for _i in n:
			multiset.append(id)
	_shuffle_strings(multiset, rng)
	var coords: Array[Vector2i] = []
	for y in gameplay.height:
		for x in gameplay.width:
			var tile = gameplay.get_tile(x, y)
			if tile == null or not tile.can_hold_item():
				continue
			coords.append(Vector2i(x, y))
	_shuffle_coords(coords, rng)
	var place_count := mini(multiset.size(), coords.size())
	for i in range(place_count):
		var coord: Vector2i = coords[i]
		var tile = gameplay.get_tile(coord.x, coord.y)
		if tile:
			tile.cell_floor_type_id = multiset[i]


static func enhanced_counts_from_pool(
	pool: GnosisNode,
	enhanced_type_ids: Array[String]
) -> Dictionary:
	var out := {}
	if pool == null or not pool.is_valid():
		return out
	var counts := read_pool_dict(pool)
	for type_id in enhanced_type_ids:
		var n: int = int(counts.get(type_id, 0))
		if n > 0:
			out[type_id] = n
	return out


static func read_pool_dict(pool: GnosisNode) -> Dictionary:
	var out := {}
	if pool == null or not pool.is_valid() or pool.get_type() != GnosisValueType.OBJECT:
		return out
	for key in pool.get_keys():
		var id := str(key).strip_edges()
		if id.is_empty():
			continue
		var node := pool.get_node(key)
		var value := int(node.value) if node.is_valid() and node.value != null else 0
		out[id] = maxi(0, value)
	return out


static func write_pool_dict(pool: GnosisNode, counts: Dictionary) -> void:
	if pool == null or not pool.is_valid() or typeof(pool.value) != TYPE_DICTIONARY:
		return
	pool.value.clear()
	for key in counts.keys():
		pool.value[str(key)] = int(counts[key])


static func normalize_pool(counts: Dictionary) -> void:
	if pool_sum(counts) == POOL_SIZE:
		return
	counts.clear()
	counts[KEY_EMPTY] = POOL_SIZE


static func is_board_grid_ready(gameplay) -> bool:
	return _is_board_grid_ready(gameplay)


static func _is_board_grid_ready(gameplay) -> bool:
	if gameplay == null:
		return false
	if gameplay.width <= 0 or gameplay.height <= 0:
		return false
	if gameplay.grid.size() != gameplay.height:
		return false
	var row: Array = gameplay.grid[0]
	return row.size() == gameplay.width


static func pool_sum(counts: Dictionary) -> int:
	var total := 0
	for key in counts.keys():
		total += int(counts[key])
	return total


static func _shuffle_strings(items: Array[String], rng: RandomNumberGenerator) -> void:
	if items.size() < 2:
		return
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := items[i]
		items[i] = items[j]
		items[j] = tmp


static func _shuffle_coords(coords: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	if coords.size() < 2:
		return
	for i in range(coords.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := coords[i]
		coords[i] = coords[j]
		coords[j] = tmp
