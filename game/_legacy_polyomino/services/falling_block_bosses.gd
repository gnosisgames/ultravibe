class_name FallingBlockBosses
extends RefCounted

## Time-based boss encounters, ported from FallingBlockGnosisService.BossEncounter/BossSchedule.partial.cs.
##
## Driven by a run-elapsed-seconds clock (Ephemeral.timers.tetrisRunElapsed, whole seconds).
## Spawn interval 60-120s; encounter duration 45-90s; intervals are seed-stable via bossScheduleBasis.
## The boss pool grows cumulatively as properties.minimumTimeSec tiers unlock and picks are weighted
## toward bosses seen less this run. With the bossOnly flag the spawn gap is short and the whole pool
## is available immediately.
##
## On encounter start/end the boss level's properties.onRoundStartInvocations / onRoundEndInvocations are
## dispatched through the engine (e.g. FallingBlock.ApplyEffect / RemoveEffect). Surviving a boss
## increments bossEncountersSurvivedThisRun, publishes a survived fact, and fires the on_boss_defeated
## boon score phase.

const FB := preload("res://game/services/falling_block_ephemeral.gd")

const SPAWN_INTERVAL_MIN_SEC := 60
const SPAWN_INTERVAL_MAX_SEC := 120
const DURATION_MIN_SEC := 45
const DURATION_MAX_SEC := 90

# Ephemeral leaf keys (mirror FallingBlockEphemeralPaths.cs).
const K_SCHEDULE_BASIS := "bossScheduleBasis"
const K_SURVIVED := "bossEncountersSurvivedThisRun"
const K_IS_ACTIVE := "bossEncounterIsActive"
const K_LEVEL_ID := "bossEncounterLevelId"
const K_STARTED_AT := "bossEncounterStartedAtElapsedSec"
const K_ENDS_AT := "bossEncounterEndsAtElapsedSec"
const K_NEXT_SPAWN_AT := "bossScheduleNextSpawnAtElapsedSec"
const K_NEXT_LEVEL_ID := "bossScheduleNextLevelId"
const K_COUNTS_BY_ID := "bossEncounterCountsById"
const K_ENCOUNTERS_STARTED := "bossProgressEncountersStarted"
const K_ROUND_IS_BOSS := "roundIsBossRound"
const K_ROUND_THEME_ID := "roundThemeId"
const K_ROUND_SPRITE_ID := "roundSpriteId"
const K_ROUND_DISPLAY_LETTER := "roundDisplayLetter"
const K_ROUND_DESCRIPTION_KEY := "roundDescriptionKey"
const K_CURRENT_ROUND := "currentRound"
const K_PREVIEW_HAS_BOSS := "bossPreviewHasBoss"
const K_PREVIEW_SHOWS_CURRENT := "bossPreviewShowsCurrentEncounter"
const K_PREVIEW_SECONDS_UNTIL := "bossPreviewSecondsUntil"
const K_PREVIEW_LEVEL_ID := "bossPreviewLevelId"
const K_PREVIEW_GLYPH := "bossPreviewGlyph"
const K_PREVIEW_COLOR := "bossPreviewColor"

var _service: GnosisService = null
var _boon_score: FallingBlockBoonScore = null

func _init(service: GnosisService, boon_score: FallingBlockBoonScore = null) -> void:
	_service = service
	_boon_score = boon_score

func _ctx() -> GnosisContext:
	return _service.context

# --- Lifecycle ---

func reset_for_new_run() -> void:
	if _ctx() == null or _ctx().store == null:
		return
	_clear_identity_fields()
	FB.set_fb_bool(_ctx(), K_IS_ACTIVE, false)
	FB.set_fb_string(_ctx(), K_LEVEL_ID, "")
	FB.set_fb_int(_ctx(), K_STARTED_AT, 0)
	FB.set_fb_int(_ctx(), K_ENDS_AT, 0)
	FB.set_fb_int(_ctx(), K_ENCOUNTERS_STARTED, 0)
	FB.set_fb_int(_ctx(), K_SURVIVED, 0)
	FB.set_fb_node(_ctx(), K_COUNTS_BY_ID, _ctx().store.create_object())
	FB.set_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")

	if not FallingBlockGameFlags.is_include_bosses(_ctx()):
		FB.set_fb_int(_ctx(), K_NEXT_SPAWN_AT, 0)
		FB.set_fb_bool(_ctx(), K_PREVIEW_HAS_BOSS, false)
		_request_theme("normal")
		return

	_capture_schedule_basis()
	var first_spawn := _pick_spawn_interval_sec(0)
	FB.set_fb_int(_ctx(), K_NEXT_SPAWN_AT, first_spawn)
	_assign_scheduled_next_boss(first_spawn)
	_request_theme("normal")
	_write_normal_round_presentation()
	_refresh_preview(0)

## Advance the encounter state machine to the given run-elapsed whole seconds.
func advance(elapsed_sec: int) -> void:
	if _ctx() == null or _ctx().store == null:
		return
	if not FallingBlockGameFlags.is_include_bosses(_ctx()):
		return
	var elapsed: int = max(0, elapsed_sec)
	if FB.get_fb_bool(_ctx(), K_IS_ACTIVE, false):
		var ends_at := FB.get_fb_int(_ctx(), K_ENDS_AT, 0)
		if ends_at > 0 and elapsed >= ends_at:
			_end_encounter(elapsed)
		else:
			_refresh_preview(elapsed)
		return
	var next_spawn := FB.get_fb_int(_ctx(), K_NEXT_SPAWN_AT, 0)
	if next_spawn > 0 and elapsed >= next_spawn:
		_start_encounter(elapsed)
	else:
		_refresh_preview(elapsed)

# --- Encounter start / end ---

func _start_encounter(elapsed_sec: int) -> void:
	var level_id := _resolve_boss_level_id_for_encounter(elapsed_sec)
	var level_def := _get_level_def(level_id)
	if level_id.is_empty() or level_def == null or not level_def.is_valid():
		_schedule_next_spawn(elapsed_sec)
		return

	var ordinal := FB.get_fb_int(_ctx(), K_ENCOUNTERS_STARTED, 0) + 1
	_increment_encounter_count(level_id)
	FB.set_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")

	var duration := _pick_stable_ranged_int(_schedule_basis(), ordinal * 17 + 3, DURATION_MIN_SEC, DURATION_MAX_SEC)
	FB.set_fb_int(_ctx(), K_ENCOUNTERS_STARTED, ordinal)
	FB.set_fb_bool(_ctx(), K_IS_ACTIVE, true)
	FB.set_fb_bool(_ctx(), K_ROUND_IS_BOSS, true)
	FB.set_fb_string(_ctx(), K_LEVEL_ID, level_id)
	FB.set_fb_int(_ctx(), K_STARTED_AT, elapsed_sec)
	FB.set_fb_int(_ctx(), K_ENDS_AT, elapsed_sec + duration)

	var theme := _read_level_theme_id(level_def)
	if theme.is_empty():
		theme = "normal"
	FB.set_fb_string(_ctx(), K_ROUND_THEME_ID, theme)
	_request_theme(theme)
	_write_boss_round_presentation(level_def)

	_run_boss_invocations(level_def, "onRoundStartInvocations")
	_publish_started_fact(elapsed_sec, level_id)
	_refresh_preview(elapsed_sec)

func _end_encounter(elapsed_sec: int) -> void:
	var ended_level_id := FB.get_fb_string(_ctx(), K_LEVEL_ID, "")
	var level_def := _get_level_def(ended_level_id)
	if level_def != null and level_def.is_valid():
		_run_boss_invocations(level_def, "onRoundEndInvocations")

	var survived := FB.get_fb_int(_ctx(), K_SURVIVED, 0) + 1
	FB.set_fb_int(_ctx(), K_SURVIVED, survived)

	_clear_identity_fields()
	FB.set_fb_bool(_ctx(), K_IS_ACTIVE, false)
	FB.set_fb_string(_ctx(), K_LEVEL_ID, "")
	FB.set_fb_int(_ctx(), K_STARTED_AT, 0)
	FB.set_fb_int(_ctx(), K_ENDS_AT, 0)

	_request_theme("normal")
	_write_normal_round_presentation()

	# Surviving a boss is a scoring beat for on_boss_defeated boons.
	if _boon_score:
		_boon_score.apply_on_boss_defeated({"level_id": ended_level_id, "survived_this_run": survived})

	_publish_survived_fact(elapsed_sec, ended_level_id, survived)
	_schedule_next_spawn(elapsed_sec)
	_refresh_preview(elapsed_sec)

func _schedule_next_spawn(elapsed_sec: int) -> void:
	var survived := FB.get_fb_int(_ctx(), K_SURVIVED, 0)
	var started := FB.get_fb_int(_ctx(), K_ENCOUNTERS_STARTED, 0)
	var salt := survived * 31 + started * 97 + 1
	var interval := _pick_spawn_interval_sec(salt)
	var next_spawn_at := elapsed_sec + interval
	FB.set_fb_int(_ctx(), K_NEXT_SPAWN_AT, next_spawn_at)
	_assign_scheduled_next_boss(next_spawn_at)

# --- Invocation dispatch ---

func _run_boss_invocations(level_def: GnosisNode, key: String) -> void:
	var props := level_def.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return
	var invocations := props.get_node(key)
	if not invocations.is_valid() or invocations.get_type() != GnosisValueType.LIST:
		return
	var engine_call := func(caller_id, target_id, func_name, param_obj):
		return _ctx().engine.call_function(caller_id, target_id, func_name, param_obj)
	GnosisInvocationUtilities.run_invocation_list(_ctx().store, _service.id, invocations, engine_call, null, true)

# --- Pool / pick ---

func _resolve_boss_level_id_for_encounter(elapsed_sec: int) -> String:
	var scheduled := FB.get_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")
	var pool := _build_eligible_pool(elapsed_sec)
	if not scheduled.is_empty() and pool.has(scheduled) and _get_level_def(scheduled) != null:
		return scheduled
	if pool.is_empty():
		return ""
	return _pick_weighted_from_pool(pool)

func _assign_scheduled_next_boss(pool_elapsed_sec: int) -> void:
	var pool := _build_eligible_pool(pool_elapsed_sec)
	if pool.is_empty():
		FB.set_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")
		return
	FB.set_fb_string(_ctx(), K_NEXT_LEVEL_ID, _pick_weighted_from_pool(pool))

## All boss ids whose minimumTimeSec has been reached at elapsed_sec (cumulative tiers).
func _build_eligible_pool(elapsed_sec: int) -> Array:
	var elapsed: int = max(0, elapsed_sec)
	var entries := _read_boss_catalog_entries()
	var eligible: Array = []
	if entries.is_empty():
		return eligible
	if FallingBlockGameFlags.is_boss_only(_ctx()):
		for e in entries:
			eligible.append(str(e["id"]))
		eligible.sort()
		return eligible
	for e in entries:
		if elapsed >= int(e["min_time"]):
			eligible.append(str(e["id"]))
	if eligible.is_empty():
		for e in entries:
			eligible.append(str(e["id"]))
	eligible.sort()
	return eligible

## Weighted pick: bosses seen less this run get a higher weight (never below 1).
func _pick_weighted_from_pool(pool: Array) -> String:
	if pool.is_empty():
		return ""
	if pool.size() == 1:
		return str(pool[0]).strip_edges()
	var max_count := 0
	for id in pool:
		max_count = max(max_count, _read_encounter_count(str(id)))
	var weights: Array = []
	var total_weight := 0
	for id in pool:
		var w: int = 1 + max(0, max_count - _read_encounter_count(str(id)))
		weights.append(w)
		total_weight += w
	if total_weight <= 0:
		return str(pool[0]).strip_edges()
	var roll := _seed_range_int(0, total_weight)
	var cumulative := 0
	for i in range(pool.size()):
		cumulative += int(weights[i])
		if roll < cumulative:
			return str(pool[i]).strip_edges()
	return str(pool[pool.size() - 1]).strip_edges()

func _read_boss_catalog_entries() -> Array:
	var entries: Array = []
	var configuration := _service.get_node("configuration", true)
	if not configuration.is_valid() or configuration.get_type() != GnosisValueType.OBJECT:
		return entries
	var bosses := configuration.get_node("bosses")
	if not bosses.is_valid() or bosses.get_type() != GnosisValueType.OBJECT:
		return entries
	for boss_id in bosses.get_keys():
		if str(boss_id).is_empty():
			continue
		var n := bosses.get_node(boss_id)
		if not n.is_valid() or n.get_type() != GnosisValueType.OBJECT:
			continue
		if not _level_has_boss_tag(n):
			continue
		if not FallingBlockGameFlags.is_catalog_entry_allowed(_ctx(), n):
			continue
		entries.append({"id": str(boss_id), "min_time": _read_level_minimum_time_sec(n), "def": n})
	entries.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return entries

# --- Encounter counts ---

func _read_encounter_count(boss_id: String) -> int:
	if boss_id.strip_edges().is_empty():
		return 0
	var counts := FB.get_fb_node(_ctx(), K_COUNTS_BY_ID)
	if not counts.is_valid() or counts.get_type() != GnosisValueType.OBJECT:
		return 0
	return max(0, FB.read_int(counts.get_node(boss_id.strip_edges().to_lower()), 0))

func _increment_encounter_count(boss_id: String) -> void:
	if boss_id.strip_edges().is_empty():
		return
	var key := boss_id.strip_edges().to_lower()
	var counts := FB.get_fb_node(_ctx(), K_COUNTS_BY_ID)
	if not counts.is_valid() or counts.get_type() != GnosisValueType.OBJECT:
		counts = _ctx().store.create_object()
		FB.set_fb_node(_ctx(), K_COUNTS_BY_ID, counts)
	counts.set_key(key, _read_encounter_count(key) + 1)

# --- Presentation ---

func _clear_identity_fields() -> void:
	FB.set_fb_bool(_ctx(), K_ROUND_IS_BOSS, false)
	FB.set_fb_string(_ctx(), K_ROUND_THEME_ID, "normal")
	FB.set_fb_string(_ctx(), K_ROUND_SPRITE_ID, "")
	FB.set_fb_string(_ctx(), K_ROUND_DESCRIPTION_KEY, "")

func _write_normal_round_presentation() -> void:
	FB.set_fb_string(_ctx(), K_ROUND_THEME_ID, "normal")
	var display: int = max(1, FB.get_fb_int(_ctx(), K_CURRENT_ROUND, 1))
	FB.set_fb_string(_ctx(), K_ROUND_DISPLAY_LETTER, str(display))
	FB.set_fb_string(_ctx(), K_ROUND_SPRITE_ID, "")
	FB.set_fb_string(_ctx(), K_ROUND_DESCRIPTION_KEY, "")

func _write_boss_round_presentation(level_def: GnosisNode) -> void:
	var glyph := _normalize_starting_letter(_read_metadata_string(level_def, "startingLetter"))
	if glyph.is_empty():
		glyph = _read_metadata_string(level_def, "id")
	FB.set_fb_string(_ctx(), K_ROUND_DISPLAY_LETTER, glyph)
	FB.set_fb_string(_ctx(), K_ROUND_SPRITE_ID, _read_metadata_string(level_def, "spriteId"))
	FB.set_fb_string(_ctx(), K_ROUND_DESCRIPTION_KEY, _read_metadata_string(level_def, "descriptionKey"))

func _refresh_preview(elapsed: int) -> void:
	if FB.get_fb_bool(_ctx(), K_IS_ACTIVE, false):
		var level_id := FB.get_fb_string(_ctx(), K_LEVEL_ID, "")
		var ends_at := FB.get_fb_int(_ctx(), K_ENDS_AT, 0)
		var seconds_until: int = max(0, ends_at - elapsed) if ends_at > 0 else 0
		var level_def := _get_level_def(level_id)
		if level_id.is_empty() or level_def == null or not level_def.is_valid():
			_clear_preview_fields()
			return
		_write_preview_fields(level_def, level_id, seconds_until, true)
		return
	var next_spawn := FB.get_fb_int(_ctx(), K_NEXT_SPAWN_AT, 0)
	var pick_elapsed: int = max(elapsed, next_spawn) if next_spawn > 0 else elapsed
	var pool := _build_eligible_pool(pick_elapsed)
	if next_spawn <= 0 or pool.is_empty():
		_clear_preview_fields()
		return
	var seconds_until_spawn: int = max(0, next_spawn - elapsed)
	var next_level_id := FB.get_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")
	if next_level_id.is_empty() or not pool.has(next_level_id):
		_assign_scheduled_next_boss(pick_elapsed)
		next_level_id = FB.get_fb_string(_ctx(), K_NEXT_LEVEL_ID, "")
	var next_def := _get_level_def(next_level_id)
	if next_def == null or not next_def.is_valid():
		_clear_preview_fields()
		return
	_write_preview_fields(next_def, next_level_id, seconds_until_spawn, false)

func _write_preview_fields(level_def: GnosisNode, level_id: String, seconds_until: int, shows_current: bool) -> void:
	var glyph := _normalize_starting_letter(_read_metadata_string(level_def, "startingLetter"))
	if glyph.is_empty():
		glyph = _read_metadata_string(level_def, "id")
	FB.set_fb_bool(_ctx(), K_PREVIEW_HAS_BOSS, true)
	FB.set_fb_bool(_ctx(), K_PREVIEW_SHOWS_CURRENT, shows_current)
	FB.set_fb_int(_ctx(), K_PREVIEW_SECONDS_UNTIL, seconds_until)
	FB.set_fb_string(_ctx(), K_PREVIEW_LEVEL_ID, level_id)
	FB.set_fb_string(_ctx(), K_PREVIEW_GLYPH, glyph)
	FB.set_fb_string(_ctx(), K_PREVIEW_COLOR, _read_metadata_string(level_def, "textColor"))

func _clear_preview_fields() -> void:
	FB.set_fb_bool(_ctx(), K_PREVIEW_HAS_BOSS, false)
	FB.set_fb_bool(_ctx(), K_PREVIEW_SHOWS_CURRENT, false)
	FB.set_fb_int(_ctx(), K_PREVIEW_SECONDS_UNTIL, 0)
	FB.set_fb_string(_ctx(), K_PREVIEW_LEVEL_ID, "")
	FB.set_fb_string(_ctx(), K_PREVIEW_GLYPH, "")
	FB.set_fb_string(_ctx(), K_PREVIEW_COLOR, "")

func _request_theme(theme_id: String) -> void:
	if _ctx() == null or _ctx().store == null:
		return
	var args := _ctx().store.create_object()
	args.set_key("themeId", theme_id if not theme_id.is_empty() else "normal")
	_service.call_service("Theme", "SetCurrentTheme", args)

# --- Facts ---

func _publish_started_fact(elapsed_sec: int, level_id: String) -> void:
	if _ctx() == null or _ctx().event_bus == null or _ctx().store == null:
		return
	var payload := _ctx().store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_ELAPSED_SEC, elapsed_sec)
	payload.set_key(FallingBlockEvents.PAYLOAD_BOSS_ENCOUNTER_LEVEL_ID, level_id)
	_ctx().event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_BOSS_ENCOUNTER_STARTED, payload, false))

func _publish_survived_fact(elapsed_sec: int, ended_level_id: String, survived: int) -> void:
	if _ctx() == null or _ctx().event_bus == null or _ctx().store == null:
		return
	var payload := _ctx().store.create_object()
	payload.set_key(FallingBlockEvents.PAYLOAD_ELAPSED_SEC, elapsed_sec)
	payload.set_key(FallingBlockEvents.PAYLOAD_BOSS_ENCOUNTERS_SURVIVED_THIS_RUN, survived)
	payload.set_key(FallingBlockEvents.PAYLOAD_BOSS_ENCOUNTER_LEVEL_ID, ended_level_id)
	_ctx().event_bus.publish(GnosisEvent.new(FallingBlockEvents.FACT_FALLING_BLOCK_BOSS_ENCOUNTER_SURVIVED, payload, false))

# --- Schedule basis / stable RNG ---

func _capture_schedule_basis() -> void:
	var basis := _try_read_seed()
	if basis == 0:
		basis = 1
	FB.set_fb_int(_ctx(), K_SCHEDULE_BASIS, basis)

func _schedule_basis() -> int:
	return FB.get_fb_int(_ctx(), K_SCHEDULE_BASIS, 1)

func _try_read_seed() -> int:
	if _ctx() == null or _ctx().engine == null:
		return 0
	var res = _service.call_service("Seed", "GetSeed", _ctx().store.create_object())
	if res is GnosisFunctionResult and res.is_ok and res.payload != null and res.payload.is_valid():
		return FB.read_int(res.payload.get_node("seed"), 0)
	if res is GnosisNode and res.is_valid():
		return FB.read_int(res.get_node("seed"), 0)
	return 0

func _pick_spawn_interval_sec(salt: int) -> int:
	if FallingBlockGameFlags.is_boss_only(_ctx()):
		return FallingBlockGameFlags.BOSS_ONLY_SPAWN_INTERVAL_SEC
	return _pick_stable_ranged_int(_schedule_basis(), salt, SPAWN_INTERVAL_MIN_SEC, SPAWN_INTERVAL_MAX_SEC)

static func _pick_stable_ranged_int(basis: int, salt: int, min_inclusive: int, max_inclusive: int) -> int:
	if max_inclusive < min_inclusive:
		var t := max_inclusive
		max_inclusive = min_inclusive
		min_inclusive = t
	var span := max_inclusive - min_inclusive + 1
	if span <= 1:
		return min_inclusive
	var x := int(basis) & 0xFFFFFFFF
	x ^= (int(salt) * 0x9E3779B9) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	x ^= (x >> 16)
	x = (x * 0x7FEB352D) & 0xFFFFFFFF
	x ^= (x >> 15)
	x &= 0xFFFFFFFF
	return min_inclusive + (x % span)

func _seed_range_int(min_inclusive: int, max_exclusive: int) -> int:
	if max_exclusive <= min_inclusive:
		return min_inclusive
	var args := _ctx().store.create_object()
	args.set_key("min", min_inclusive)
	args.set_key("max", max_exclusive)
	var res = _service.call_service("Seed", "RangeInt", args)
	if res is GnosisFunctionResult and res.is_ok and res.payload != null and res.payload.is_valid():
		return FB.read_int(res.payload.get_node("value"), min_inclusive)
	if res is GnosisNode and res.is_valid():
		return FB.read_int(res.get_node("value"), min_inclusive)
	return min_inclusive

# --- Level definition readers ---

func _get_level_def(level_id: String) -> GnosisNode:
	if level_id.strip_edges().is_empty():
		return null
	var configuration := _service.get_node("configuration", true)
	if not configuration.is_valid() or configuration.get_type() != GnosisValueType.OBJECT:
		return null
	var bosses := configuration.get_node("bosses")
	if bosses.is_valid() and bosses.get_type() == GnosisValueType.OBJECT:
		var n := bosses.get_node(level_id.strip_edges())
		if n.is_valid() and n.get_type() == GnosisValueType.OBJECT:
			return n
	var levels := configuration.get_node("levels")
	if levels.is_valid() and levels.get_type() == GnosisValueType.OBJECT:
		var ln := levels.get_node(level_id.strip_edges())
		if ln.is_valid() and ln.get_type() == GnosisValueType.OBJECT:
			return ln
	return null

func _level_has_boss_tag(level_def: GnosisNode) -> bool:
	var props := level_def.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return false
	var tags := props.get_node("gameplayTags")
	if not tags.is_valid() or tags.get_type() != GnosisValueType.LIST:
		return false
	for i in range(tags.get_count()):
		var item := tags.get_node(i)
		if item.is_valid() and item.get_type() == GnosisValueType.STRING and str(item.value).strip_edges().to_lower() == "boss":
			return true
	return false

func _read_level_minimum_time_sec(level_def: GnosisNode) -> int:
	var props := level_def.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return 0
	return max(0, FB.read_int(props.get_node("minimumTimeSec"), 0))

func _read_level_theme_id(level_def: GnosisNode) -> String:
	var props := level_def.get_node("properties")
	if not props.is_valid() or props.get_type() != GnosisValueType.OBJECT:
		return ""
	return FB.read_string(props.get_node("themeId"), "").strip_edges()

func _read_metadata_string(level_def: GnosisNode, key: String) -> String:
	var meta := level_def.get_node("metadata")
	if not meta.is_valid() or meta.get_type() != GnosisValueType.OBJECT:
		return ""
	return FB.read_string(meta.get_node(key), "")

func _normalize_starting_letter(raw: String) -> String:
	if raw.is_empty():
		return ""
	var s := raw.strip_edges()
	if s.find("\\u") < 0:
		return s
	var out := ""
	var i := 0
	while i < s.length():
		if i + 5 < s.length() and s[i] == "\\" and s[i + 1] == "u":
			var hex := s.substr(i + 2, 4)
			if hex.is_valid_hex_number(false):
				out += String.chr(("0x" + hex).hex_to_int())
				i += 6
				continue
		out += s[i]
		i += 1
	return out
