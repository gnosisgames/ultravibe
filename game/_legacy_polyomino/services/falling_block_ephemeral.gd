class_name FallingBlockEphemeral
extends RefCounted

## Static helpers for reading/writing the per-run Ephemeral.fallingBlock state branch.
## Mirrors FallingBlockEphemeralServiceHelpers / *.EphemeralAccess.partial.cs.

const FB_KEY := "fallingBlock"

static func get_fb(context) -> GnosisNode:
	var eph: GnosisNode = context.state.root.get_node("Ephemeral")
	if not eph.is_valid() or eph.get_type() != GnosisValueType.OBJECT:
		eph = context.store.create_object()
		context.state.root.set_node("Ephemeral", eph)
	var fb: GnosisNode = eph.get_node(FB_KEY)
	if not fb.is_valid() or fb.get_type() != GnosisValueType.OBJECT:
		fb = context.store.create_object()
		eph.set_node(FB_KEY, fb)
	return fb

static func read_int(node: GnosisNode, default_value: int = 0) -> int:
	if node == null or not node.is_valid():
		return default_value
	match node.get_type():
		GnosisValueType.INT:
			return int(node.value)
		GnosisValueType.FLOAT:
			return int(node.value)
		GnosisValueType.STRING:
			return int(str(node.value)) if str(node.value).is_valid_int() else default_value
	return default_value

static func read_float(node: GnosisNode, default_value: float = 0.0) -> float:
	if node == null or not node.is_valid():
		return default_value
	match node.get_type():
		GnosisValueType.INT, GnosisValueType.FLOAT:
			return float(node.value)
		GnosisValueType.STRING:
			return float(str(node.value)) if str(node.value).is_valid_float() else default_value
	return default_value

static func read_string(node: GnosisNode, default_value: String = "") -> String:
	if node == null or not node.is_valid() or node.get_type() != GnosisValueType.STRING:
		return default_value
	return str(node.value)

static func read_bool(node: GnosisNode, default_value: bool = false) -> bool:
	if node == null or not node.is_valid() or node.get_type() != GnosisValueType.BOOL:
		return default_value
	return bool(node.value)

## Reads a stored { coefficient, suffixIndex } object as a GnosisScalableValue.
static func read_scalable(node: GnosisNode) -> GnosisScalableValue:
	if node == null or not node.is_valid() or node.get_type() != GnosisValueType.OBJECT:
		return GnosisScalableValue.zero()
	var coef := read_int(node.get_node("coefficient"), 0)
	var suffix := read_int(node.get_node("suffixIndex"), 0)
	return GnosisScalableValue.new(coef, suffix)

## Returns a plain dict representation of a scalable for storing into state.
static func scalable_to_dict(value: GnosisScalableValue) -> Dictionary:
	return {"coefficient": value.coefficient, "suffixIndex": value.suffix_index}

## Builds a scalable from a whole number that round-trips correctly through
## to_int(). GnosisScalableValue.from_int() has an off-by-one suffix bug for
## small magnitudes (it omits the implicit suffix index 1), so values < 1000
## decode back to 0. We construct via the normalized {coefficient, suffix}
## form instead: value = (coefficient / 1000) * 1000^(suffixIndex - 1).
static func scalable_from_int(n: int) -> GnosisScalableValue:
	if n == 0:
		return GnosisScalableValue.zero()
	return GnosisScalableValue.from_value_and_suffix(n * 1000, 1)

# --- fallingBlock leaf accessors ---

static func get_fb_node(context, leaf: String) -> GnosisNode:
	return get_fb(context).get_node(leaf)

static func get_fb_int(context, leaf: String, default_value: int = 0) -> int:
	return read_int(get_fb(context).get_node(leaf), default_value)

static func set_fb_int(context, leaf: String, value: int) -> void:
	get_fb(context).set_key(leaf, value)

static func get_fb_float(context, leaf: String, default_value: float = 0.0) -> float:
	return read_float(get_fb(context).get_node(leaf), default_value)

static func set_fb_float(context, leaf: String, value: float) -> void:
	get_fb(context).set_key(leaf, value)

static func get_fb_string(context, leaf: String, default_value: String = "") -> String:
	return read_string(get_fb(context).get_node(leaf), default_value)

static func set_fb_string(context, leaf: String, value: String) -> void:
	get_fb(context).set_key(leaf, value)

static func get_fb_bool(context, leaf: String, default_value: bool = false) -> bool:
	return read_bool(get_fb(context).get_node(leaf), default_value)

static func set_fb_bool(context, leaf: String, value: bool) -> void:
	get_fb(context).set_key(leaf, value)

static func set_fb_node(context, leaf: String, value: GnosisNode) -> void:
	get_fb(context).set_key(leaf, value)

static func get_fb_scalable(context, leaf: String) -> GnosisScalableValue:
	return read_scalable(get_fb(context).get_node(leaf))

static func set_fb_scalable(context, leaf: String, value: GnosisScalableValue) -> void:
	var node = context.store.create_object()
	node.set_key("coefficient", value.coefficient)
	node.set_key("suffixIndex", value.suffix_index)
	get_fb(context).set_key(leaf, node)
