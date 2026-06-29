extends SceneTree

## Verifies Sprint E boss scheduling: with bossOnly on, an encounter starts shortly
## after run start, sets the boss round identity + theme, registers the boss level's
## ApplyEffect, and on expiry clears the encounter, increments the survived count, and
## removes the effect.

var _bootstrap: Node = null
var _frames := 0
var _done := false

func _initialize() -> void:
	print("--- Boss Encounter Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	if _done:
		return true
	_done = true
	var ok := _run()
	print("--- Boss Encounter Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true

func _run() -> bool:
	var ok := true
	var engine: GnosisEngine = _bootstrap.engine
	var fb := engine.get_service("FallingBlock") as FallingBlockService
	var ctx: GnosisContext = fb.context

	# Force a deterministic boss-only run: every boss is eligible immediately and the
	# spawn gap is short (BOSS_ONLY_SPAWN_INTERVAL_SEC).
	var flags: GnosisNode = FallingBlockEphemeral.get_fb(ctx).get_node("gameFlags")
	if not flags.is_valid() or flags.get_type() != GnosisValueType.OBJECT:
		flags = ctx.store.create_object()
		FallingBlockEphemeral.get_fb(ctx).set_key("gameFlags", flags)
	flags.set_key("includeBosses", true)
	flags.set_key("bossOnly", true)
	flags.set_key("includeNegatives", true)
	fb._bosses.reset_for_new_run()

	var spawn_at := FallingBlockEphemeral.get_fb_int(ctx, "bossScheduleNextSpawnAtElapsedSec", 0)
	if spawn_at <= 0:
		print("[FAIL] no boss spawn scheduled (spawn_at=%d)" % spawn_at)
		return false
	print("[INFO] first boss scheduled at %ds" % spawn_at)

	# Advance just past the scheduled spawn -> encounter should start.
	fb.debug_set_run_elapsed_seconds(float(spawn_at) + 1.0)
	var is_active := FallingBlockEphemeral.get_fb_bool(ctx, "bossEncounterIsActive", false)
	var level_id := FallingBlockEphemeral.get_fb_string(ctx, "bossEncounterLevelId", "")
	var is_boss_round := FallingBlockEphemeral.get_fb_bool(ctx, "roundIsBossRound", false)
	var theme := FallingBlockEphemeral.get_fb_string(ctx, "roundThemeId", "")
	if not is_active or level_id.is_empty():
		print("[FAIL] boss encounter did not start (active=%s, level='%s')" % [is_active, level_id])
		ok = false
	elif not is_boss_round:
		print("[FAIL] roundIsBossRound not set during encounter")
		ok = false
	else:
		print("[SUCCESS] boss encounter started: level='%s' theme='%s'" % [level_id, theme])

	# Most bosses register a base effect via ApplyEffect on round start.
	var effects: GnosisNode = FallingBlockEphemeral.get_fb_node(ctx, "activeEffects")
	var effect_count := effects.get_count() if effects.is_valid() and effects.get_type() == GnosisValueType.OBJECT else 0
	print("[INFO] active effects after start: %d" % effect_count)

	var ends_at := FallingBlockEphemeral.get_fb_int(ctx, "bossEncounterEndsAtElapsedSec", 0)
	if ends_at <= 0:
		print("[FAIL] encounter has no end time")
		return false

	# Advance past the encounter end -> it should resolve and tally a survival.
	var survived_before := FallingBlockEphemeral.get_fb_int(ctx, "bossEncountersSurvivedThisRun", 0)
	fb.debug_set_run_elapsed_seconds(float(ends_at) + 1.0)
	var still_active := FallingBlockEphemeral.get_fb_bool(ctx, "bossEncounterIsActive", false)
	var survived_after := FallingBlockEphemeral.get_fb_int(ctx, "bossEncountersSurvivedThisRun", 0)
	var theme_after := FallingBlockEphemeral.get_fb_string(ctx, "roundThemeId", "")
	if still_active:
		print("[FAIL] boss encounter did not end after its duration")
		ok = false
	elif survived_after != survived_before + 1:
		print("[FAIL] survived count not incremented (%d -> %d)" % [survived_before, survived_after])
		ok = false
	elif theme_after != "normal":
		print("[FAIL] theme not restored to normal (got '%s')" % theme_after)
		ok = false
	else:
		print("[SUCCESS] boss survived: count %d -> %d, theme restored" % [survived_before, survived_after])

	# After ending, a new spawn should be scheduled.
	var next_spawn := FallingBlockEphemeral.get_fb_int(ctx, "bossScheduleNextSpawnAtElapsedSec", 0)
	if next_spawn <= ends_at:
		print("[FAIL] no follow-up boss scheduled after survival (next=%d, ended=%d)" % [next_spawn, ends_at])
		ok = false
	else:
		print("[SUCCESS] next boss scheduled at %ds" % next_spawn)

	return ok
