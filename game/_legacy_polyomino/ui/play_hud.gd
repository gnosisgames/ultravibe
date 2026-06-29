class_name PlayHud
extends Control

## In-game play chrome: the horizontal stat bar topbar and the centered board.
## Replaces the legacy programmatic FallingBlockHud.

const FB := preload("res://game/services/falling_block_ephemeral.gd")

@export var neon_patch := 24

var _service: FallingBlockService = null

@onready var _board_slot: Control = %BoardSlot
@onready var _board_area: AspectRatioContainer = get_node_or_null("Layout/BoardArea") as AspectRatioContainer
@onready var _reward_slots: PlayHudRewardSlots = %RewardSlots
@onready var _boons_bar: PlayHudBoonsBar = %BoonsBar
@onready var _ability_cycler: PlayHudAbilityCycler = %AbilityCycler
@onready var _consumables_bar: PlayHudConsumablesBar = %ConsumablesBar
@onready var _upgrades_bar: PlayHudUpgradesBar = %UpgradesBar
@onready var _coop_overlay: Control = %CoopOverlay
@onready var _boss_section: Control = %BossSection
@onready var _boss_glyph: Control = %Glyph
@onready var _boss_letter: Label = %BossLetter
@onready var _boss_skull: TextureRect = %BossSkull
@onready var _boss_clock_icon: TextureRect = %BossClockIcon
@onready var _stat_value_labels: Array[Label] = []
@onready var _score_icon: TextureRect = get_node_or_null("Layout/StatBar/Margin/ZonesRow/StatsRow/Stat5/Icon")

const SCORE_FALLBACK_COLOR := Color(0.345098, 0.345098, 0.572549, 1.0)
var _score_theme_id := "__unset__"

## Scale-pop feedback when a stat value changes (mirrors the old Unity sidebar).
## The time label (index 2) is excluded since it ticks every second.
const STAT_POP_AMPLITUDE := 0.28
const STAT_POP_DECAY := 5.5
const STAT_POP_TIME_INDEX := 2
var _stat_prev_text: Array[String] = []
var _stat_pop: Array[float] = []

## Proximity-clock tint stops, mirrored from Unity MainHud.BossPreview.
const BOSS_CLOCK_ORANGE := Color(1.0, 0.62, 0.18, 1.0)
const BOSS_CLOCK_RED := Color(0.95, 0.28, 0.22, 1.0)
const BOSS_CLOCK_NEUTRAL := Color(0.4, 0.95, 0.38, 1.0)
const MAX_DISPLAY_SCORE := 999_999_999

# HUD-side countdown window so the clock fills boss color -> orange -> red as the
# encounter approaches (Unity tracks this in the store; we track the peak here).
var _boss_clock_phase := ""
var _boss_clock_window := 1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_neon_patches()
	_collect_stat_labels()
	call_deferred("_attach_board_renderer")
	_apply_layout_for_player_count(_read_player_count())

func bind_service(service: FallingBlockService) -> void:
	_service = service
	if _reward_slots:
		_reward_slots.bind_service(service)
	if _boons_bar:
		_boons_bar.bind_service(service)
	if _ability_cycler:
		_ability_cycler.bind_service(service)
	if _consumables_bar:
		_consumables_bar.bind_service(service)
	if _upgrades_bar:
		_upgrades_bar.bind_service(service)

func get_board_slot() -> Control:
	return _board_slot

func _process(delta: float) -> void:
	if _service == null or _service.context == null:
		return
	var ctx = _service.context

	_update_boss_header(ctx)
	_update_sidebar_stats(ctx)
	_update_stat_pops(delta)
	_apply_layout_for_player_count(_read_player_count())

## Boss section: a schedule-driven clock that is ALWAYS present while bosses are in
## play. Like Unity, the single clock serves both purposes -- it counts down to the
## next boss's arrival, then (once the encounter is active) to that boss leaving.
## The glyph (Wimzik Greek font, e.g. "Ψ") + skull wear the boss textColor; the
## clock + arrow shift boss color -> orange -> red as the deadline approaches.
func _update_boss_header(ctx) -> void:
	if _boss_section == null:
		return

	if not FallingBlockGameFlags.is_include_bosses(ctx):
		_hide_boss_section()
		return

	var elapsed := 0
	if _service != null:
		elapsed = _service.read_run_elapsed_whole_seconds()

	# Resolve the active deadline: boss end while fighting, else the next spawn.
	var seconds := 0
	var phase := ""
	if FB.get_fb_bool(ctx, "bossEncounterIsActive", false):
		var ends_at := FB.get_fb_int(ctx, "bossEncounterEndsAtElapsedSec", 0)
		seconds = maxi(0, ends_at - elapsed) if ends_at > 0 else 0
		phase = "current:" + FB.get_fb_string(ctx, "bossEncounterLevelId", "")
	else:
		var next_spawn := FB.get_fb_int(ctx, "bossScheduleNextSpawnAtElapsedSec", 0)
		if next_spawn > 0:
			seconds = maxi(0, next_spawn - elapsed)
			phase = "next:" + FB.get_fb_string(ctx, "bossScheduleNextLevelId", "")
		elif FB.get_fb_bool(ctx, "bossPreviewHasBoss", false):
			# Fallback: schedule not populated yet, but the service has a live preview.
			seconds = maxi(0, FB.get_fb_int(ctx, "bossPreviewSecondsUntil", 0))
			phase = "next:" + FB.get_fb_string(ctx, "bossPreviewLevelId", "")
		else:
			_hide_boss_section()
			return

	_boss_section.visible = true

	var boss_color := Color.WHITE
	var hex := FB.get_fb_string(ctx, "bossPreviewColor", "")
	if not hex.is_empty():
		boss_color = Color.html(hex)

	# Letter + skull wear the boss text color (shown once the boss letter is known).
	var glyph := FB.get_fb_string(ctx, "bossPreviewGlyph", "")
	var has_glyph := not glyph.strip_edges().is_empty()
	if _boss_glyph:
		_boss_glyph.visible = has_glyph
	if _boss_letter and has_glyph:
		_boss_letter.text = glyph
		_boss_letter.add_theme_color_override("font_color", boss_color)
	if _boss_skull:
		_boss_skull.modulate = boss_color

	# The clock icon shifts boss color -> orange -> red with proximity; the pulse
	# scales the whole glyph (letter + skull + clock) together as one component.
	var proximity := _boss_clock_proximity(phase, seconds)
	if _boss_clock_icon:
		_boss_clock_icon.modulate = _evaluate_boss_clock_color(boss_color, proximity)
	if _boss_glyph:
		# Pivot from the live center so the whole glyph breathes symmetrically;
		# size can shift with font/layout tweaks, so recompute it each frame.
		_boss_glyph.pivot_offset = _boss_glyph.size * 0.5
		_boss_glyph.scale = Vector2.ONE * _boss_clock_pop_scale(proximity)

func _hide_boss_section() -> void:
	_boss_section.visible = false
	_boss_clock_phase = ""
	_boss_clock_window = 1

## proximity in [0,1]: 0 = far away (boss color), 1 = imminent (red). The window is
## the peak countdown seen for the current phase, so each phase fills from 0 -> 1.
func _boss_clock_proximity(phase: String, seconds_until: int) -> float:
	if phase != _boss_clock_phase or seconds_until > _boss_clock_window:
		_boss_clock_phase = phase
		_boss_clock_window = maxi(1, seconds_until)
	return 1.0 - clampf(float(seconds_until) / float(_boss_clock_window), 0.0, 1.0)

func _evaluate_boss_clock_color(boss_color: Color, proximity: float) -> Color:
	proximity = clampf(proximity, 0.0, 1.0)
	if proximity <= 0.0:
		return boss_color
	if proximity < 0.5:
		return boss_color.lerp(BOSS_CLOCK_ORANGE, proximity / 0.5)
	return BOSS_CLOCK_ORANGE.lerp(BOSS_CLOCK_RED, (proximity - 0.5) / 0.5)

func _boss_clock_pop_scale(proximity: float) -> float:
	proximity = clampf(proximity, 0.0, 1.0)
	var pulse_freq := 1.5 + proximity * 12.0
	var wobble := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 1000.0 * pulse_freq)
	var amplitude := 0.04 + proximity * 0.22
	return 1.0 + amplitude * wobble

func _update_sidebar_stats(ctx) -> void:
	# Stat0: discards (trash). Stat1: round line objective (current/needed).
	# Stat2: run-elapsed time (clock). Stat3: fall speed level. Stat4: negative
	# ultravibe chance (%). Stat5: run total score.
	if _stat_value_labels.size() > 0 and _stat_value_labels[0]:
		var discards := int(round(FB.get_fb_float(ctx, "currentDiscards", 0.0)))
		_set_stat_text(0, "%04d" % maxi(0, discards))
	if _stat_value_labels.size() > 1 and _stat_value_labels[1]:
		var current := FB.get_fb_int(ctx, "roundLinesCurrent", 0)
		var needed := FB.get_fb_int(ctx, "roundLinesNeeded", FallingBlockRoundLines.BASE_LINES_PER_ROUND)
		_set_stat_text(1, "%d/%d" % [maxi(0, current), maxi(1, needed)])
	if _stat_value_labels.size() > 2 and _stat_value_labels[2]:
		var seconds := 0
		if _service != null:
			seconds = _service.read_run_elapsed_whole_seconds()
		_set_stat_text(2, _format_clock(seconds))
	if _stat_value_labels.size() > 3 and _stat_value_labels[3] and _service != null:
		_set_stat_text(3, "%04d" % _service.read_fall_speed_hud_display())
	if _stat_value_labels.size() > 4 and _stat_value_labels[4] and _service != null:
		_set_stat_text(4, "%04d" % _service.read_negative_chance_hud_display())
	if _stat_value_labels.size() > 5 and _stat_value_labels[5]:
		var run_score := FB.get_fb_scalable(ctx, "runTotalScore").to_int()
		_set_stat_text(5, _format_score(run_score))
		_apply_score_theme_color()

## Sets a stat label's text and, when the value actually changed (and it is not
## the time field), kicks off a scale-pop so additions/reductions feel tactile.
func _set_stat_text(index: int, text: String) -> void:
	if index < 0 or index >= _stat_value_labels.size():
		return
	var lbl := _stat_value_labels[index]
	if lbl == null:
		return
	if index < _stat_prev_text.size() and _stat_prev_text[index] != text:
		if index != STAT_POP_TIME_INDEX:
			_stat_pop[index] = 1.0
		_stat_prev_text[index] = text
	lbl.text = text

## Decays each active stat pop and applies the scale from the label center.
func _update_stat_pops(delta: float) -> void:
	for i in range(_stat_value_labels.size()):
		var lbl := _stat_value_labels[i]
		if lbl == null or i >= _stat_pop.size():
			continue
		if _stat_pop[i] <= 0.0:
			if lbl.scale != Vector2.ONE:
				lbl.scale = Vector2.ONE
			continue
		_stat_pop[i] = maxf(0.0, _stat_pop[i] - STAT_POP_DECAY * delta)
		lbl.pivot_offset = lbl.size * 0.5
		lbl.scale = Vector2.ONE * (1.0 + STAT_POP_AMPLITUDE * _stat_pop[i])

func _format_score(total_score: int) -> String:
	total_score = clampi(maxi(0, total_score), 0, MAX_DISPLAY_SCORE)
	var millions := total_score / 1_000_000
	var thousands := (total_score / 1_000) % 1000
	var ones := total_score % 1000
	return "%03d:%03d:%03d" % [millions, thousands, ones]

## Keep the run-score field on the active theme's primary color. Re-applied only
## when the theme id changes (e.g. a boss encounter swaps its theme in/out).
func _apply_score_theme_color() -> void:
	var theme_service = _theme_service()
	var theme_id: String = theme_service.get_current_theme_id() if theme_service else ""
	if theme_id == _score_theme_id:
		return
	_score_theme_id = theme_id
	var color := _theme_primary_color()
	if _stat_value_labels.size() > 5 and _stat_value_labels[5]:
		_stat_value_labels[5].add_theme_color_override("font_color", color)
	if _score_icon:
		_score_icon.modulate = color

func _theme_service():
	var host := UltraUiFx.resolve_host(self)
	if host and "engine" in host and host.engine:
		return host.engine.get_service("Theme")
	return null

func _theme_primary_color() -> Color:
	var theme_service = _theme_service()
	if theme_service:
		var hex: String = theme_service.get_theme_property("primary.neon", "")
		if not hex.is_empty():
			return Color.from_string(hex, SCORE_FALLBACK_COLOR)
	return SCORE_FALLBACK_COLOR

func _format_clock(total_seconds: int) -> String:
	total_seconds = maxi(0, total_seconds)
	return "%02d:%02d:%02d" % [total_seconds / 3600, (total_seconds / 60) % 60, total_seconds % 60]

func _read_player_count() -> int:
	if _service == null or _service.context == null:
		return 1
	var eph := _service.context.state.root.get_node("Ephemeral")
	if not eph.is_valid():
		return 1
	return maxi(1, FB.read_int(eph.get_node("playerCount"), 1))

func _apply_layout_for_player_count(_count: int) -> void:
	_apply_board_aspect_ratio()
	# Lane dividers and "1P".."4P" headers are painted by the board renderer so they
	# sit behind the falling blocks; the legacy overlay nodes stay hidden.
	if _coop_overlay:
		_coop_overlay.visible = false

## The board region is an AspectRatioContainer; co-op widens the grid (e.g. 32
## cols) so the container ratio must track the real board aspect (width / visible
## rows) instead of staying at the authored solo 10x20 (0.5). Otherwise auto_fit
## just shrinks the wide grid into the solo-shaped box.
func _apply_board_aspect_ratio() -> void:
	if _board_area == null:
		return
	var renderer := _board_renderer()
	if renderer == null:
		return
	var cols := renderer.get_grid_width()
	var rows := renderer.get_visible_rows()
	if cols <= 0 or rows <= 0:
		return
	var ratio := float(cols) / float(rows)
	if not is_equal_approx(_board_area.ratio, ratio):
		_board_area.ratio = ratio

func _board_renderer() -> FallingBlockBoardRenderer:
	if _board_slot == null:
		return null
	return _board_slot.get_node_or_null("BoardRenderer") as FallingBlockBoardRenderer

func _attach_board_renderer() -> void:
	if _board_slot == null:
		return
	var renderer := get_tree().get_first_node_in_group(
		FallingBlockBoardRenderer.BOARD_RENDERER_GROUP
	) as FallingBlockBoardRenderer
	if renderer == null:
		renderer = get_parent().get_node_or_null("BoardRenderer") as FallingBlockBoardRenderer
	if renderer == null:
		return
	if renderer.get_parent() != _board_slot:
		renderer.reparent(_board_slot)
	renderer.set_anchors_preset(Control.PRESET_FULL_RECT)
	renderer.offset_left = 0
	renderer.offset_top = 0
	renderer.offset_right = 0
	renderer.offset_bottom = 0
	renderer.center_in_rect = true
	# Scale the grid to fill the BoardSlot with a small even margin instead of a
	# fixed cell size, so it occupies nearly the full height like the Unity HUD.
	renderer.auto_fit = true
	renderer.fit_padding_ratio = 0.0

func _apply_neon_patches() -> void:
	for node in find_children("*", "NinePatchRect", true, false):
		var patch := node as NinePatchRect
		if patch.texture == null:
			continue
		patch.patch_margin_left = neon_patch
		patch.patch_margin_top = neon_patch
		patch.patch_margin_right = neon_patch
		patch.patch_margin_bottom = neon_patch

func _collect_stat_labels() -> void:
	_stat_value_labels.clear()
	for i in range(6):
		var lbl := find_child("StatValue%d" % i, true, false) as Label
		if lbl:
			_stat_value_labels.append(lbl)
	# Seed change-tracking with current text so the first frame does not pop.
	_stat_prev_text.clear()
	_stat_pop.clear()
	for lbl in _stat_value_labels:
		_stat_prev_text.append(lbl.text)
		_stat_pop.append(0.0)
