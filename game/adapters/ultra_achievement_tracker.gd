class_name UltraAchievementTracker
extends GnosisAdapter

## Subscribes to Match3 and inventory facts, granting catalog achievements via the engine service.

const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Match3EventsScript = preload("res://game/match3/match3_events.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const LuckyFindScript = preload("res://game/match3/core/match3_lucky_find.gd")
const CollectionScript = preload("res://game/services/ultravibe_collection.gd")
const BoonServiceScript = preload(
	"res://addons/com.gnosisgames.gnosisengine/services/gnosis_boon_service.gd"
)
const UpgradeServiceScript = preload(
	"res://addons/com.gnosisgames.gnosisengine/services/gnosis_upgrade_service.gd"
)
const ConsumableServiceScript = preload(
	"res://addons/com.gnosisgames.gnosisengine/services/gnosis_consumable_service.gd"
)

const COMBO_CHAIN_MIN_STEPS := 5
const COLLECTION_SCOUT_MIN := 15

var _subscriptions: Array = []
var _wired := false


func bind_engine(eng: GnosisEngine) -> void:
	super.bind_engine(eng)
	_wire_subscriptions()


func _exit_tree() -> void:
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()


func _wire_subscriptions() -> void:
	if _wired or engine == null or engine.event_bus == null:
		return
	_wired = true
	var bus := engine.event_bus
	_subscriptions.append(bus.subscribe(
		Match3EventsScript.FACT_MATCH3_MOVE_RESOLVED,
		_on_move_resolved,
		0
	))
	_subscriptions.append(bus.subscribe(
		Match3EventsScript.FACT_MATCH3_STATUS_CHANGED,
		_on_status_changed,
		0
	))
	_subscriptions.append(bus.subscribe(
		BoonServiceScript.FACT_BOON_ADDED,
		_on_boon_added,
		0
	))
	_subscriptions.append(bus.subscribe(
		UpgradeServiceScript.FACT_UPGRADE_ADDED,
		_on_upgrade_added,
		0
	))
	_subscriptions.append(bus.subscribe(
		ConsumableServiceScript.FACT_CONSUMABLE_ADDED,
		_on_consumable_added,
		0
	))


func _on_move_resolved(event: GnosisEvent) -> void:
	if not _event_applied(event):
		return
	if not _node_bool(event.data, "success", false):
		return
	var step_count := _node_int(event.data, "stepCount", 0)
	if step_count > 0:
		_grant("first_match")
	if step_count >= COMBO_CHAIN_MIN_STEPS:
		_grant("combo_chain")
	_check_lucky_find_achievements()


func _on_status_changed(event: GnosisEvent) -> void:
	if not _event_applied(event):
		return
	var status := _node_int(event.data, Match3EventsScript.PAYLOAD_GAME_STATUS, -1)
	if status != Match3ModelsScript.STATUS_WIN:
		return
	_grant("first_level")
	var m3 := _match3_service()
	if m3 != null and m3.has_method("is_boss_round") and m3.is_boss_round():
		_grant("first_boss")
	if _board_is_clear():
		_grant("perfect_board")


func _on_boon_added(event: GnosisEvent) -> void:
	if not _event_applied(event):
		return
	var boon_id := _node_str(event.data, "boonId")
	if boon_id.is_empty():
		return
	_mark_discovered("boon", boon_id)
	_check_collection_scout()


func _on_upgrade_added(event: GnosisEvent) -> void:
	if not _event_applied(event):
		return
	var upgrade_id := _node_str(event.data, "upgradeId")
	if upgrade_id.is_empty():
		return
	_mark_discovered("upgrade", upgrade_id)
	_check_collection_scout()


func _on_consumable_added(event: GnosisEvent) -> void:
	if not _event_applied(event):
		return
	var consumable_id := _node_str(event.data, "consumableId")
	if consumable_id.is_empty():
		return
	_mark_discovered("consumable", consumable_id)
	_check_collection_scout()


func _check_lucky_find_achievements() -> void:
	var m3 := _match3_service()
	if m3 == null or not m3.has_method("get_lucky_find"):
		return
	var lucky_find: Match3LuckyFind = m3.get_lucky_find()
	if lucky_find == null:
		return
	if lucky_find.temporary_assist >= LuckyFindScript.MAX_ASSIST:
		_grant("vibe_master")
	if lucky_find.has_method("consume_last_refill_outcome"):
		var outcome: Dictionary = lucky_find.consume_last_refill_outcome()
		if bool(outcome.get("mega_chain", false)):
			_grant("gem_rain")


func _check_collection_scout() -> void:
	if engine == null or engine.context == null:
		return
	if CollectionScript.total_discovered_count(engine.context) >= COLLECTION_SCOUT_MIN:
		_grant("collection_scout")


func _mark_discovered(type_id: String, item_id: String) -> void:
	if engine == null or engine.context == null:
		return
	CollectionScript.mark_discovered(engine.context, type_id, item_id)


func _board_is_clear() -> bool:
	var m3 := _match3_service()
	if m3 == null or not m3.has_method("get_gameplay"):
		return false
	var gameplay: Match3Gameplay = m3.get_gameplay()
	if gameplay == null:
		return false
	for y in range(gameplay.height):
		for x in range(gameplay.width):
			var tile = gameplay.get_tile(x, y)
			if tile != null and str(tile.item_id).strip_edges() != "":
				return false
	return true


func _grant(achievement_id: String) -> void:
	var svc: GnosisAchievementService = _achievement_service()
	if svc == null:
		return
	svc.grant(achievement_id)


func _achievement_service() -> GnosisAchievementService:
	return engine.get_service("Achievement") as GnosisAchievementService if engine else null


func _match3_service() -> Match3Service:
	return engine.get_service("Match3") as Match3Service if engine else null


func _event_applied(event: GnosisEvent) -> bool:
	if event == null or event.data == null or not event.data.is_valid():
		return false
	var applied := event.data.get_node("applied")
	if applied.is_valid() and applied.get_type() == GnosisValueType.BOOL:
		return bool(applied.value)
	return true


func _node_int(node: GnosisNode, key: String, fallback: int) -> int:
	if node == null or not node.is_valid():
		return fallback
	var field := node.get_node(key)
	return int(field.value) if field.is_valid() else fallback


func _node_bool(node: GnosisNode, key: String, fallback: bool) -> bool:
	if node == null or not node.is_valid():
		return fallback
	var field := node.get_node(key)
	return bool(field.value) if field.is_valid() else fallback


func _node_str(node: GnosisNode, key: String) -> String:
	if node == null or not node.is_valid():
		return ""
	var field := node.get_node(key)
	return str(field.value).strip_edges() if field.is_valid() and field.value != null else ""
