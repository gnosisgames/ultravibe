class_name FallingBlockCollection
extends RefCounted

## Persistent collection/discovery helpers for Ultravibe. Runtime inventories are
## ephemeral per run; this records which rewards have ever been seen by the
## player under Persistent.collection.discovered.

const ROOT_KEY := "collection"
const DISCOVERED_KEY := "discovered"

const TYPE_TO_CATEGORY := {
	"boon": "boons",
	"consumable": "consumables",
	"ability": "abilities",
	"upgrade": "upgrades"
}

static func mark_discovered(context: GnosisContext, type_id: String, item_id: String) -> void:
	if context == null or context.state == null or context.store == null:
		return
	var clean_id := item_id.strip_edges()
	if clean_id.is_empty():
		return
	var category := category_for_type(type_id)
	if category.is_empty():
		return
	var discovered := ensure_discovered_root(context)
	var bucket := discovered.get_node(category)
	if not bucket.is_valid() or bucket.get_type() != GnosisValueType.OBJECT:
		bucket = context.store.create_object()
		discovered.set_node(category, bucket)
	bucket.set_node(clean_id, true)

static func discovered_ids(context: GnosisContext, category: String) -> Dictionary:
	var result := {}
	if context == null or context.state == null:
		return result
	var discovered := get_discovered_root(context)
	if not discovered.is_valid() or discovered.get_type() != GnosisValueType.OBJECT:
		return result
	var bucket := discovered.get_node(category)
	if not bucket.is_valid() or bucket.get_type() != GnosisValueType.OBJECT:
		return result
	for key in bucket.get_keys():
		var node := bucket.get_node(key)
		if node.is_valid() and node.get_type() == GnosisValueType.BOOL and bool(node.value):
			result[str(key).strip_edges().to_lower()] = true
	return result

static func is_discovered(context: GnosisContext, category: String, item_id: String) -> bool:
	if item_id.strip_edges().is_empty():
		return false
	return discovered_ids(context, category).has(item_id.strip_edges().to_lower())

static func category_for_type(type_id: String) -> String:
	return str(TYPE_TO_CATEGORY.get(type_id.strip_edges().to_lower(), ""))

static func get_discovered_root(context: GnosisContext) -> GnosisNode:
	if context == null or context.state == null:
		return GnosisNode.new(null)
	return context.state.root.get_node("Persistent.%s.%s" % [ROOT_KEY, DISCOVERED_KEY])

static func ensure_discovered_root(context: GnosisContext) -> GnosisNode:
	var persistent := context.state.root.get_node("Persistent")
	if not persistent.is_valid() or persistent.get_type() != GnosisValueType.OBJECT:
		persistent = context.store.create_object()
		context.state.root.set_node("Persistent", persistent)
	var collection := persistent.get_node(ROOT_KEY)
	if not collection.is_valid() or collection.get_type() != GnosisValueType.OBJECT:
		collection = context.store.create_object()
		persistent.set_node(ROOT_KEY, collection)
	var discovered := collection.get_node(DISCOVERED_KEY)
	if not discovered.is_valid() or discovered.get_type() != GnosisValueType.OBJECT:
		discovered = context.store.create_object()
		collection.set_node(DISCOVERED_KEY, discovered)
	for category in TYPE_TO_CATEGORY.values():
		var bucket := discovered.get_node(category)
		if not bucket.is_valid() or bucket.get_type() != GnosisValueType.OBJECT:
			discovered.set_node(category, context.store.create_object())
	return discovered
