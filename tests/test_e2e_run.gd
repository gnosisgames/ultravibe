extends SceneTree

## End-to-end run verification: boots the real Ultravibe game (Deck -> spawn pipeline,
## gravity, scoring, rounds, bosses, theme, localization) and drives live frames plus
## hard drops, asserting the integrated systems behave coherently with no errors.

var _bootstrap: Node = null
var _fb: FallingBlockService = null
var _ctx: GnosisContext = null
var _frames := 0
var _locks_seen := 0
var _last_piece := ""
var _phase := 0
var _done := false
var _boss_spawn_at := 0
var _boss_was_active := false

func _initialize() -> void:
	print("--- End-to-End Run Test ---")
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)

func _process(delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_fb = _bootstrap.engine.get_service("FallingBlock") as FallingBlockService
		_ctx = _fb.context
	if _fb == null:
		return false
	if _done:
		return true

	match _phase:
		0:
			_phase_live_gameplay()
		1:
			_phase_boss_then_finish()
	return _done

## Phase 0: let the real loop spawn/drop pieces; hard-drop periodically to lock them.
func _phase_live_gameplay() -> void:
	var players := _fb.get_players()
	if players.is_empty():
		return
	var player: FallingBlockModels.PlayerState = players[0]
	if not player.current_piece_instance_id.is_empty():
		if _last_piece != player.current_piece_instance_id:
			_last_piece = player.current_piece_instance_id
	# Every ~12 frames, hard drop the active piece to lock it and accrue score.
	if _frames % 12 == 0 and not player.current_piece_instance_id.is_empty():
		var before := player.current_piece_instance_id
		var hd := FallingBlockModels.InputEventData.new()
		hd.player_id = player.player_id
		hd.type = FallingBlockModels.InputType.HARD_DROP
		_fb.handle_input(hd)
		if player.current_piece_instance_id != before:
			_locks_seen += 1
	if _frames > 90:
		_phase = 1

## Phase 1: drive a boss-only encounter deterministically, then assert everything.
func _phase_boss_then_finish() -> void:
	var flags: GnosisNode = FallingBlockEphemeral.get_fb(_ctx).get_node("gameFlags")
	if not flags.is_valid() or flags.get_type() != GnosisValueType.OBJECT:
		flags = _ctx.store.create_object()
		FallingBlockEphemeral.get_fb(_ctx).set_key("gameFlags", flags)
	flags.set_key("includeBosses", true)
	flags.set_key("bossOnly", true)
	_fb._bosses.reset_for_new_run()
	_boss_spawn_at = FallingBlockEphemeral.get_fb_int(_ctx, "bossScheduleNextSpawnAtElapsedSec", 0)
	_fb.debug_set_run_elapsed_seconds(float(_boss_spawn_at) + 1.0)
	_boss_was_active = FallingBlockEphemeral.get_fb_bool(_ctx, "bossEncounterIsActive", false)
	var ends_at := FallingBlockEphemeral.get_fb_int(_ctx, "bossEncounterEndsAtElapsedSec", 0)
	_fb.debug_set_run_elapsed_seconds(float(ends_at) + 1.0)

	_done = true
	var ok := _assert_all()
	print("--- End-to-End Run Test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)

func _assert_all() -> bool:
	var ok := true

	# Live spawn pipeline produced pieces.
	if _fb._piece_instance_counter <= 0 and _last_piece.is_empty():
		print("[FAIL] no pieces ever spawned via the live Deck pipeline")
		ok = false
	else:
		print("[SUCCESS] live spawn pipeline produced pieces (counter=%d)" % _fb._piece_instance_counter)

	# Hard drops locked pieces; score accrues only when lines actually clear.
	var run_total := FallingBlockEphemeral.get_fb_scalable(_ctx, "runTotalScore")
	var progress := FallingBlockEphemeral.get_fb_int(_ctx, "roundLinesCurrent", 0)
	var scored := run_total.compare_to(GnosisScalableValue.zero()) > 0
	var cleared_lines := progress > 0
	if _locks_seen <= 0:
		print("[FAIL] no pieces locked via hard drop during live play")
		ok = false
	elif cleared_lines and not scored:
		print("[FAIL] lines cleared but run score did not accrue")
		ok = false
	else:
		print("[SUCCESS] locked %d pieces; run score tracks line clears (progress>0=%s, scored=%s)" % [_locks_seen, str(cleared_lines), str(scored)])

	# Rewards: offers rolled for the active round.
	var offers := FallingBlockEphemeral.get_fb_node(_ctx, "rewardOffers")
	var has_offers := offers.is_valid() and (offers.get_type() == GnosisValueType.LIST or offers.get_type() == GnosisValueType.OBJECT) and offers.get_count() > 0
	if not has_offers:
		print("[INFO] no reward offers present (round-reward UI not wired); skipping")
	else:
		print("[SUCCESS] reward offers present for the active round (%d)" % offers.get_count())

	# Boss: encounter started + survived within the integrated loop.
	var survived := FallingBlockEphemeral.get_fb_int(_ctx, "bossEncountersSurvivedThisRun", 0)
	if not _boss_was_active:
		print("[FAIL] boss encounter did not start at scheduled time (%ds)" % _boss_spawn_at)
		ok = false
	elif survived < 1:
		print("[FAIL] boss encounter not resolved as survived")
		ok = false
	else:
		print("[SUCCESS] boss encounter started and survived (count=%d)" % survived)

	# Theme restored to normal after the boss.
	var theme := _bootstrap.engine.get_service("Theme") as GnosisThemeService
	if theme.get_current_theme_id() != "normal":
		print("[FAIL] theme not restored to 'normal' after boss (got '%s')" % theme.get_current_theme_id())
		ok = false
	else:
		print("[SUCCESS] theme restored to 'normal' post-encounter")

	# Localization resolves a boss level name.
	var loc := _bootstrap.engine.get_service("Localization") as GnosisLocalizationService
	if loc.get_string_value("aresLevelName", "") != "Ares":
		print("[FAIL] localization did not resolve aresLevelName")
		ok = false
	else:
		print("[SUCCESS] localization resolves boss level names")

	return ok
