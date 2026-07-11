class_name UltravibeAchievements
extends RefCounted

## Profile-persistent achievement unlocks under Persistent.achievements.earned.

const ROOT_KEY := "achievements"
const EARNED_KEY := "earned"

static func grant(context: GnosisContext, achievement_id: String) -> void:
	if context == null:
		return
	var clean_id := achievement_id.strip_edges()
	if clean_id.is_empty():
		return
	if context.engine != null:
		var svc = context.engine.get_service("Achievement")
		if svc != null and svc.has_method("grant"):
			svc.grant(clean_id)
			return
	if context.state == null or context.store == null:
		return
	var earned := ensure_earned_root(context)
	earned.set_node(clean_id, true)

static func is_earned(context: GnosisContext, achievement_id: String) -> bool:
	var clean_id := achievement_id.strip_edges()
	if clean_id.is_empty():
		return false
	if context != null and context.engine != null:
		var svc = context.engine.get_service("Achievement")
		if svc != null and svc.has_method("is_earned"):
			return svc.is_earned(clean_id)
	return earned_ids(context).has(clean_id)

static func earned_ids(context: GnosisContext) -> Dictionary:
	var result := {}
	if context == null or context.state == null:
		return result
	var earned := get_earned_root(context)
	if not earned.is_valid() or earned.get_type() != GnosisValueType.OBJECT:
		return result
	for key in earned.get_keys():
		var node := earned.get_node(key)
		if node.is_valid() and node.get_type() == GnosisValueType.BOOL and bool(node.value):
			result[str(key).strip_edges()] = true
	return result

static func get_earned_root(context: GnosisContext) -> GnosisNode:
	if context == null or context.state == null:
		return GnosisNode.new(null)
	return context.state.root.get_node("Persistent.%s.%s" % [ROOT_KEY, EARNED_KEY])

static func ensure_earned_root(context: GnosisContext) -> GnosisNode:
	var persistent := context.state.root.get_node("Persistent")
	if not persistent.is_valid() or persistent.get_type() != GnosisValueType.OBJECT:
		persistent = context.store.create_object()
		context.state.root.set_node("Persistent", persistent)
	var achievements := persistent.get_node(ROOT_KEY)
	if not achievements.is_valid() or achievements.get_type() != GnosisValueType.OBJECT:
		achievements = context.store.create_object()
		persistent.set_node(ROOT_KEY, achievements)
	var earned := achievements.get_node(EARNED_KEY)
	if not earned.is_valid() or earned.get_type() != GnosisValueType.OBJECT:
		earned = context.store.create_object()
		achievements.set_node(EARNED_KEY, earned)
	return earned
