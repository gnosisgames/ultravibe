extends SceneTree

## Round difficulty vs isolated match scores + cascade chain model + Lucky Find assist.
## Uses the same target/moves formulas as Match3Service, including ephemeral roundTargets from round 10+.
##
## Run: ./tools/match3_round_balance_report.sh
## Env:
##   MATCH3_SCORE_MAX_LEVEL=1       item level for avg gem profile (default 1)
##   MATCH3_CASCADE_YIELD=0.55      each cascade step scores yield^k × opening match (default 0.55)
##   MATCH3_NATURAL_CASCADE=0.65    P(natural extra cascade | non-opening-only score) (default 0.65)
##   MATCH3_HINDER_SUPPRESSION=0.40 cascade steps lost per hinder activation (default 0.40)
##   MATCH3_HIT_RATE=0.70           fraction of moves that score (default 0.70)
##   MATCH3_OPENING_ONLY_RATE=0.40  scoring moves with no natural cascade (pity builds)
##   MATCH3_LUCKY_EXTRA_STEPS=1.0   expected extra cascade steps when Lucky Find help fires
##   MATCH3_MEGA_CHAIN_CHANCE=0.55    P(next refill in same move is forced help | help succeeded)
##   MATCH3_MAX_LUCKY_HELPS=3         max lucky help inserts per scoring move
##   MATCH3_LUCKY_UPGRADE_STACKS=0 GoldenLuckyFind stacks (0-10, +10 assist each)
##   MATCH3_USE_EPHEMERAL_LUCKY=1   read luckyFindTuning from data/ephemeral.json (default 1)
##   MATCH3_MAX_ROUND=24
##   MATCH3_OPENING_MATCH=3         default opening match size 3|4|5 for main table

const LuckyFindModel = preload("res://tools/match3_balance_lucky_find.gd")

const MATCH_SIZES := [3, 4, 5]
const BASE_SCORE_TO_WIN := 1500
const ROUND_TARGET_STEP := 500
const TARGET_ADVANCED_MULTIPLIER := 1.25
const TARGET_BOSS_MULTIPLIER := 1.6
const BOSS_MOVES_BONUS := 1
const BASE_MOVES_LIMIT := 8

var _objective_target_cfg: Dictionary = {}
const ROUNDS_PER_FLOOR := 3

var _bootstrap: Node = null
var _frames := 0


func _initialize() -> void:
	_bootstrap = load("res://main.tscn").instantiate()
	root.add_child(_bootstrap)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 8:
		return false
	_print_report()
	quit()
	return true


func _print_report() -> void:
	var engine: GnosisEngine = _bootstrap.engine
	var m3 = engine.get_service("Match3")
	if m3 == null:
		push_error("Match3 service missing")
		return

	var item_level := _env_int("MATCH3_SCORE_MAX_LEVEL", 1)
	var cascade_yield := _env_float("MATCH3_CASCADE_YIELD", 0.55)
	var natural_cascade_factor := _env_float("MATCH3_NATURAL_CASCADE", LuckyFindModel.NATURAL_CASCADE_FACTOR)
	var hinder_suppression := _env_float("MATCH3_HINDER_SUPPRESSION", LuckyFindModel.HINDER_STEP_SUPPRESSION)
	var hit_rate := clampf(_env_float("MATCH3_HIT_RATE", 0.70), 0.01, 1.0)
	var opening_only_rate := clampf(_env_float("MATCH3_OPENING_ONLY_RATE", 0.40), 0.0, 1.0)
	var lucky_extra_steps := maxf(0.0, _env_float("MATCH3_LUCKY_EXTRA_STEPS", 1.0))
	var mega_chain_chance := clampf(_env_float("MATCH3_MEGA_CHAIN_CHANCE", LuckyFindModel.MEGA_CHAIN_CHANCE), 0.0, 1.0)
	var max_lucky_helps := clampi(_env_int("MATCH3_MAX_LUCKY_HELPS", LuckyFindModel.MAX_LUCKY_HELPS_PER_MOVE), 1, 10)
	var upgrade_stacks := clampi(_env_int("MATCH3_LUCKY_UPGRADE_STACKS", 0), 0, 10)
	var use_ephemeral := _env_int("MATCH3_USE_EPHEMERAL_LUCKY", 1) != 0
	var max_round := _env_int("MATCH3_MAX_ROUND", 24)
	var opening_size := clampi(_env_int("MATCH3_OPENING_MATCH", 3), 3, 5)

	var lf_tuning := LuckyFindModel.load_ephemeral_tuning() if use_ephemeral else {
		"enabled": true,
		"permanentAssist": LuckyFindModel.DEFAULT_PERMANENT_ASSIST,
		"pityIncrementAssist": LuckyFindModel.DEFAULT_PITY_INCREMENT_ASSIST,
		"source": "defaults",
	}
	var lf_enabled := bool(lf_tuning.get("enabled", true))
	var permanent_assist := LuckyFindModel.effective_permanent_assist(lf_tuning, upgrade_stacks)
	var pity_inc := float(lf_tuning.get("pityIncrementAssist", LuckyFindModel.DEFAULT_PITY_INCREMENT_ASSIST))
	_objective_target_cfg = _load_objective_target_config()

	_set_all_item_levels(m3, item_level)
	var avgs := _average_gem_scores(m3)
	var opening_score := int(avgs.get(opening_size, avgs.get(3, 0)))

	print("")
	print("=== Match3 round balance (cascade + Lucky Find planning) ===")
	print("Runtime formulas: target = 1500 + (round-1)*500 × stage mult (1.25 adv / 1.6 boss); roundTargets table from round 10+; moves = 8 + (round-1)/3 + boss+1")
	print("Item level %d | opening match-%d avg score %d | cascade yield %.2f | natural factor %.2f | hit rate %.0f%%" % [
		item_level, opening_size, opening_score, cascade_yield, natural_cascade_factor, hit_rate * 100.0,
	])
	print("Comfort = (moves × expected_score_per_move) / target  (>1.0 = headroom)")
	print("Columns @N = N fixed natural extra cascades; +assist = natural + lucky help (incl. mega-chain) for round")
	print("")

	var sim_kwargs := {
		"natural_cascade_factor": natural_cascade_factor,
		"hinder_suppression": hinder_suppression,
		"mega_chain_chance": mega_chain_chance,
		"max_lucky_helps_per_move": max_lucky_helps,
	}

	_print_lucky_find_section(
		lf_tuning, lf_enabled, permanent_assist, pity_inc, upgrade_stacks,
		opening_only_rate, lucky_extra_steps, hit_rate, max_round, sim_kwargs,
		mega_chain_chance, max_lucky_helps
	)
	print("")
	_print_assist_scenarios(
		max_round, opening_score, cascade_yield, hit_rate, opening_only_rate,
		lucky_extra_steps, lf_enabled, sim_kwargs
	)
	print("")
	_print_cascade_multipliers(cascade_yield)
	print("")
	_print_round_table(
		max_round, opening_score, cascade_yield, hit_rate, opening_only_rate,
		permanent_assist, pity_inc, lucky_extra_steps, lf_enabled, sim_kwargs
	)
	print("")
	_print_cycle_summary(
		max_round, opening_score, cascade_yield, hit_rate, opening_only_rate,
		permanent_assist, pity_inc, lucky_extra_steps, lf_enabled, sim_kwargs
	)
	print("")
	_print_opening_sizes(
		m3, item_level, cascade_yield, hit_rate, opening_only_rate, max_round,
		permanent_assist, pity_inc, lucky_extra_steps, lf_enabled, sim_kwargs
	)


func _print_lucky_find_section(
	lf_tuning: Dictionary,
	lf_enabled: bool,
	permanent_assist: float,
	pity_inc: float,
	upgrade_stacks: int,
	opening_only_rate: float,
	lucky_extra_steps: float,
	hit_rate: float,
	max_round: int,
	sim_kwargs: Dictionary,
	mega_chain_chance: float,
	max_lucky_helps: int
) -> void:
	print("-- Cascade assist model (%s) --" % str(lf_tuning.get("source", "?")))
	if not lf_enabled:
		print("disabled — +assist columns match natural-only model")
		return
	var base_rates := LuckyFindModel.assist_rates(permanent_assist)
	print(
		"base assist %+.0f → help %.0f%% | hinder %.0f%% | pity +%.0f assist per opening-only score" % [
			permanent_assist,
			float(base_rates.help_rate) * 100.0,
			maxf(0.0, float(base_rates.hinder_rate)) * 100.0,
			pity_inc,
		]
	)
	print(
		"upgrade stacks %d (+%.0f assist each, max %d) | opening-only %.0f%% | lucky steps/help %.2f" % [
			upgrade_stacks,
			LuckyFindModel.GOLDEN_LUCKY_FIND_BONUS_ASSIST,
			LuckyFindModel.GOLDEN_LUCKY_FIND_MAX_STACKS,
			opening_only_rate * 100.0,
			lucky_extra_steps,
		]
	)
	print(
		"natural cascade factor %.2f | hinder suppression %.2f steps/activation" % [
			float(sim_kwargs.get("natural_cascade_factor", LuckyFindModel.NATURAL_CASCADE_FACTOR)),
			float(sim_kwargs.get("hinder_suppression", LuckyFindModel.HINDER_STEP_SUPPRESSION)),
		]
	)
	print(
		"mega-chain: %.0f%% next-refill chain after help | max %d lucky helps/scoring move" % [
			mega_chain_chance * 100.0,
			max_lucky_helps,
		]
	)
	var chain_refill := 1.0 + (1.0 - opening_only_rate) * float(
		sim_kwargs.get("natural_cascade_factor", LuckyFindModel.NATURAL_CASCADE_FACTOR)
	)
	var chain_mult := LuckyFindModel.mega_chain_help_multiplier(
		chain_refill, maxf(0.0, permanent_assist) / 100.0, mega_chain_chance, max_lucky_helps
	)
	if permanent_assist > 0.0:
		print(
			"at base assist: ~%.2f× help activations vs flat roll (refill batches ≈ %.2f/scoring move)" % [
				chain_mult,
				chain_refill,
			]
		)
	print("Pity curve (assist / help% / hinder% after k opening-only scores, no lucky reset):")
	for row in LuckyFindModel.pity_curve_rows(permanent_assist, pity_inc, 6):
		print(
			"  after %d opening-only → assist %+.0f (help %.0f%%, hinder %.0f%%)" % [
				int(row.opening_only_moves),
				float(row.temporary_assist),
				float(row.help_rate) * 100.0,
				float(row.hinder_rate) * 100.0,
			]
		)
	var sample_moves := _resolve_moves_limit(9, "boss", BASE_MOVES_LIMIT)
	var sample := _simulate_round(
		sample_moves, hit_rate, opening_only_rate, permanent_assist, pity_inc,
		lucky_extra_steps, true, sim_kwargs
	)
	print(
		"Round 9 boss (%d moves): natural +%.3f | help +%.3f (chain +%.3f) | lucky +%.3f | hinder %.3f/refill | ending assist %+.0f" % [
			sample_moves,
			float(sample.expected_natural_extra_per_scoring_move),
			float(sample.expected_help_activations_per_scoring_move),
			float(sample.expected_mega_chain_bonus_helps_per_scoring_move),
			float(sample.expected_lucky_extra_per_scoring_move),
			float(sample.expected_hinder_activations_per_scoring_move),
			float(sample.ending_temporary_assist),
		]
	)
	var early_moves := _resolve_moves_limit(1, "normal", BASE_MOVES_LIMIT)
	var early := _simulate_round(
		early_moves, hit_rate, opening_only_rate, permanent_assist, pity_inc,
		lucky_extra_steps, true, sim_kwargs
	)
	print(
		"Round 1 (%d moves): natural +%.3f | help +%.3f (chain +%.3f) | lucky +%.3f | hinder %.3f/refill | ending assist %+.0f" % [
			early_moves,
			float(early.expected_natural_extra_per_scoring_move),
			float(early.expected_help_activations_per_scoring_move),
			float(early.expected_mega_chain_bonus_helps_per_scoring_move),
			float(early.expected_lucky_extra_per_scoring_move),
			float(early.expected_hinder_activations_per_scoring_move),
			float(early.ending_temporary_assist),
		]
	)


func _print_assist_scenarios(
	max_round: int,
	opening_score: int,
	cascade_yield: float,
	hit_rate: float,
	opening_only_rate: float,
	lucky_extra_steps: float,
	lf_enabled: bool,
	sim_kwargs: Dictionary
) -> void:
	if not lf_enabled:
		return
	print("-- Assist scenarios (round 9 boss, match opening score %d) --" % opening_score)
	var round_num := 9
	var stage := "boss"
	var target := _resolve_target_score(round_num, stage)
	var moves := _resolve_moves_limit(round_num, stage, BASE_MOVES_LIMIT)
	var scenarios := [
		{"label": "fresh run (-50)", "assist": LuckyFindModel.DEFAULT_PERMANENT_ASSIST},
		{"label": "neutral (0)", "assist": 0.0},
		{"label": "mid pity (-20)", "assist": -20.0},
		{"label": "4× upgrade (-10)", "assist": -10.0},
		{"label": "10× upgrade (+50)", "assist": 50.0},
	]
	print("%-18s | help | hinder | nat+ | help+ | chain+ | lucky+ | comfort" % "scenario")
	print("-".repeat(88))
	for scenario in scenarios:
		var assist: float = float(scenario.assist)
		var rates := LuckyFindModel.assist_rates(assist)
		var stats := _simulate_round(
			moves, hit_rate, opening_only_rate, assist,
			LuckyFindModel.DEFAULT_PITY_INCREMENT_ASSIST, lucky_extra_steps, true, sim_kwargs
		)
		var expected := LuckyFindModel.expected_move_score_from_simulation(
			opening_score, cascade_yield, hit_rate, stats
		)
		var comfort := (float(moves) * expected) / float(target) if target > 0 else 0.0
		print(
			"%-18s | %3.0f%% | %5.0f%% | %4.2f | %5.2f | %6.2f | %5.2f | %.2f" % [
				str(scenario.label),
				float(rates.help_rate) * 100.0,
				maxf(0.0, float(rates.hinder_rate)) * 100.0,
				float(stats.expected_natural_extra_per_scoring_move),
				float(stats.expected_help_activations_per_scoring_move),
				float(stats.expected_mega_chain_bonus_helps_per_scoring_move),
				float(stats.expected_lucky_extra_per_scoring_move),
				comfort,
			]
		)


func _print_cascade_multipliers(yield_factor: float) -> void:
	print("-- Natural cascade multiplier (opening match + N extra cascade steps) --")
	print("%-18s | %s" % ["extra cascades", "mult"])
	print("-".repeat(32))
	for extra in range(0, 4):
		var mult := _cascade_multiplier(extra, yield_factor)
		print("%-18d | %.3f" % [extra, mult])


func _print_round_table(
	max_round: int,
	opening_score: int,
	cascade_yield: float,
	hit_rate: float,
	opening_only_rate: float,
	permanent_assist: float,
	pity_inc: float,
	lucky_extra_steps: float,
	lf_enabled: bool,
	sim_kwargs: Dictionary
) -> void:
	print("-- Per-round table (cycles 1-3 = rounds 1-9, tutorial tier) --")
	var header := "%-5s | %-5s | %-8s | %7s | %5s | %8s | %s | %s" % [
		"round",
		"floor",
		"stage",
		"target",
		"moves",
		"need/mv",
		"comfort @0/1/2/3",
		"+assist",
	]
	print(header)
	print("-".repeat(header.length()))

	for round_num in range(1, max_round + 1):
		var floor_num := int((round_num - 1) / ROUNDS_PER_FLOOR) + 1
		var round_in_floor := int((round_num - 1) % ROUNDS_PER_FLOOR) + 1
		var stage := _stage_for_round_in_floor(round_in_floor)
		var target := _resolve_target_score(round_num, stage)
		var moves := _resolve_moves_limit(round_num, stage, BASE_MOVES_LIMIT)
		var need_per_move := float(target) / float(moves)
		var marker := "  *" if round_num <= 9 else ""
		var comforts: PackedStringArray = []
		for extra in range(0, 4):
			var expected := _expected_move_score(opening_score, extra, cascade_yield, hit_rate)
			var ratio := (float(moves) * expected) / float(target) if target > 0 else 0.0
			comforts.append("%.2f" % ratio)
		var lf_round := _simulate_round(
			moves, hit_rate, opening_only_rate, permanent_assist, pity_inc,
			lucky_extra_steps, lf_enabled, sim_kwargs
		)
		var lf_expected := LuckyFindModel.expected_move_score_from_simulation(
			opening_score, cascade_yield, hit_rate, lf_round
		)
		var lf_ratio := (float(moves) * lf_expected) / float(target) if target > 0 else 0.0
		print("%-5d | %-5d | %-8s | %7d | %5d | %8.0f | %s | %.2f%s" % [
			round_num,
			floor_num,
			stage,
			target,
			moves,
			need_per_move,
			"/".join(comforts),
			lf_ratio,
			marker,
		])
	print("* = first 3 cycles (rounds 1-9)")
	print("+assist = comfort with natural (post-hinder) + lucky help; help+/chain+ include mega-chain within move")


func _print_cycle_summary(
	max_round: int,
	opening_score: int,
	cascade_yield: float,
	hit_rate: float,
	opening_only_rate: float,
	permanent_assist: float,
	pity_inc: float,
	lucky_extra_steps: float,
	lf_enabled: bool,
	sim_kwargs: Dictionary
) -> void:
	print("-- Cycle summary (avg comfort ratio per 3-round floor) --")
	print(
		"%-6s | rounds | avg target | avg moves | comfort@0 | comfort@1 | +assist | comfort@2 | comfort@3" % [
			"cycle",
		]
	)
	print("-".repeat(100))

	var cycle := 0
	while true:
		var start_round := cycle * ROUNDS_PER_FLOOR + 1
		if start_round > max_round:
			break
		var end_round := mini(start_round + ROUNDS_PER_FLOOR - 1, max_round)
		var sum_target := 0.0
		var sum_moves := 0.0
		var sum_comfort := [0.0, 0.0, 0.0, 0.0]
		var sum_lf_comfort := 0.0
		var count := 0
		for round_num in range(start_round, end_round + 1):
			var round_in_floor := int((round_num - 1) % ROUNDS_PER_FLOOR) + 1
			var stage := _stage_for_round_in_floor(round_in_floor)
			var target := _resolve_target_score(round_num, stage)
			var moves := _resolve_moves_limit(round_num, stage, BASE_MOVES_LIMIT)
			sum_target += float(target)
			sum_moves += float(moves)
			for extra in range(0, 4):
				var expected := _expected_move_score(opening_score, extra, cascade_yield, hit_rate)
				sum_comfort[extra] += (float(moves) * expected) / float(target) if target > 0 else 0.0
			var lf_round := _simulate_round(
				moves, hit_rate, opening_only_rate, permanent_assist, pity_inc,
				lucky_extra_steps, lf_enabled, sim_kwargs
			)
			var lf_expected := LuckyFindModel.expected_move_score_from_simulation(
				opening_score, cascade_yield, hit_rate, lf_round
			)
			sum_lf_comfort += (float(moves) * lf_expected) / float(target) if target > 0 else 0.0
			count += 1
		if count == 0:
			break
		var tier := "easy" if cycle < 3 else ("mid" if cycle < 6 else "late")
		print(
			"%-6d | %2d-%2d  | %10.0f | %9.1f | %9.2f | %9.2f | %11.2f | %9.2f | %9.2f  (%s)" % [
				cycle + 1,
				start_round,
				end_round,
				sum_target / float(count),
				sum_moves / float(count),
				sum_comfort[0] / float(count),
				sum_comfort[1] / float(count),
				sum_lf_comfort / float(count),
				sum_comfort[2] / float(count),
				sum_comfort[3] / float(count),
				tier,
			]
		)
		cycle += 1


func _print_opening_sizes(
	m3,
	item_level: int,
	cascade_yield: float,
	hit_rate: float,
	opening_only_rate: float,
	max_round: int,
	permanent_assist: float,
	pity_inc: float,
	lucky_extra_steps: float,
	lf_enabled: bool,
	sim_kwargs: Dictionary
) -> void:
	print("-- Match-3 / 4 / 5 opening size matrix (round 9 boss, level %d) --" % item_level)
	_set_all_item_levels(m3, item_level)
	var avgs := _average_gem_scores(m3)
	var round_num := 9
	var stage := "boss"
	var target := _resolve_target_score(round_num, stage)
	var moves := _resolve_moves_limit(round_num, stage, BASE_MOVES_LIMIT)
	var lf_round := _simulate_round(
		moves, hit_rate, opening_only_rate, permanent_assist, pity_inc,
		lucky_extra_steps, lf_enabled, sim_kwargs
	)
	var rates := LuckyFindModel.assist_rates(permanent_assist)
	print(
		"Round 9: target %d, moves %d | assist %+.0f (help %.0f%%, hinder %.0f%%)" % [
			target,
			moves,
			permanent_assist,
			float(rates.help_rate) * 100.0,
			maxf(0.0, float(rates.hinder_rate)) * 100.0,
		]
	)
	print(
		"Expected per scoring move: natural +%.3f | help +%.3f (chain +%.3f) | lucky +%.3f | hinder %.3f activations" % [
			float(lf_round.expected_natural_extra_per_scoring_move),
			float(lf_round.expected_help_activations_per_scoring_move),
			float(lf_round.expected_mega_chain_bonus_helps_per_scoring_move),
			float(lf_round.expected_lucky_extra_per_scoring_move),
			float(lf_round.expected_hinder_activations_per_scoring_move),
		]
	)
	print(
		"%-8s | %6s | %s | %s | %s | %s" % [
			"match",
			"score",
			"comfort @0/1/2/3",
			"+assist",
			"need/mv @1",
			"need/mv +assist",
		]
	)
	print("-".repeat(88))
	for size in MATCH_SIZES:
		var opening := int(avgs.get(size, 0))
		var parts: PackedStringArray = []
		for extra in range(0, 4):
			var expected := _expected_move_score(opening, extra, cascade_yield, hit_rate)
			var ratio := (float(moves) * expected) / float(target) if target > 0 else 0.0
			parts.append("%.2f" % ratio)
		var lf_expected := LuckyFindModel.expected_move_score_from_simulation(
			opening, cascade_yield, hit_rate, lf_round
		)
		var lf_ratio := (float(moves) * lf_expected) / float(target) if target > 0 else 0.0
		var need_at_1 := float(target) / (
			float(moves) * _expected_move_score(opening, 1, cascade_yield, hit_rate)
		) if moves > 0 else 0.0
		var need_assist := float(target) / (float(moves) * lf_expected) if moves > 0 and lf_expected > 0.0 else 0.0
		print(
			"match-%d | %6d | %s | %6.2f | %8.0f | %8.0f" % [
				size, opening, "/".join(parts), lf_ratio, need_at_1, need_assist,
			]
		)


func _simulate_round(
	moves: int,
	hit_rate: float,
	opening_only_rate: float,
	permanent_assist: float,
	pity_inc: float,
	lucky_extra_steps: float,
	lf_enabled: bool,
	sim_kwargs: Dictionary
) -> Dictionary:
	return LuckyFindModel.simulate_round(
		moves,
		hit_rate,
		opening_only_rate,
		permanent_assist,
		pity_inc,
		lucky_extra_steps,
		lf_enabled,
		float(sim_kwargs.get("natural_cascade_factor", LuckyFindModel.NATURAL_CASCADE_FACTOR)),
		float(sim_kwargs.get("hinder_suppression", LuckyFindModel.HINDER_STEP_SUPPRESSION)),
		float(sim_kwargs.get("mega_chain_chance", LuckyFindModel.MEGA_CHAIN_CHANCE)),
		int(sim_kwargs.get("max_lucky_helps_per_move", LuckyFindModel.MAX_LUCKY_HELPS_PER_MOVE)),
	)


func _expected_move_score(opening_score: int, extra_cascades: int, yield_factor: float, hit_rate: float) -> float:
	return float(opening_score) * _cascade_multiplier(extra_cascades, yield_factor) * hit_rate


func _cascade_multiplier(extra_cascades: int, yield_factor: float) -> float:
	var total := 1.0
	for step in range(1, extra_cascades + 1):
		total += pow(yield_factor, float(step))
	return total


func _stage_for_round_in_floor(round_in_floor: int) -> String:
	match round_in_floor:
		2:
			return "advanced"
		3:
			return "boss"
		_:
			return "normal"


func _resolve_target_score(round_number: int, stage_type: String) -> int:
	var round_index := maxi(0, round_number - 1)
	var table_target := _read_round_target_from_table(round_index)
	if table_target > 0:
		return table_target
	var target := BASE_SCORE_TO_WIN + round_index * ROUND_TARGET_STEP
	if stage_type == "advanced":
		target = int(roundf(float(target) * TARGET_ADVANCED_MULTIPLIER))
	elif stage_type == "boss":
		target = int(roundf(float(target) * TARGET_BOSS_MULTIPLIER))
	return maxi(1, target)


func _load_objective_target_config() -> Dictionary:
	var out := {
		"useRoundTargetsTable": false,
		"useRoundTargetsFromRound": 10,
		"roundTargets": [],
	}
	if not FileAccess.file_exists("res://data/ephemeral.json"):
		return out
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/ephemeral.json"))
	if not (parsed is Dictionary):
		return out
	var m3: Dictionary = parsed.get("Ephemeral", {}).get("match3", {})
	var cfg: Dictionary = m3.get("objectiveTarget", {})
	if cfg.is_empty():
		return out
	out.useRoundTargetsTable = bool(cfg.get("useRoundTargetsTable", false))
	out.useRoundTargetsFromRound = int(cfg.get("useRoundTargetsFromRound", 10))
	var table: Array = cfg.get("roundTargets", [])
	for entry in table:
		out.roundTargets.append(int(entry))
	return out


func _read_round_target_from_table(round_index: int) -> int:
	if not bool(_objective_target_cfg.get("useRoundTargetsTable", false)):
		return 0
	if round_index + 1 < int(_objective_target_cfg.get("useRoundTargetsFromRound", 10)):
		return 0
	var table: Array = _objective_target_cfg.get("roundTargets", [])
	if round_index < 0 or round_index >= table.size():
		return 0
	return maxi(0, int(table[round_index]))


func _resolve_moves_limit(round: int, stage_type: String, default_moves: int) -> int:
	var moves := default_moves + int((maxi(1, round) - 1) / 3)
	if stage_type == "boss":
		moves += BOSS_MOVES_BONUS
	return maxi(1, moves)


func _average_gem_scores(m3) -> Dictionary:
	var totals := {3: 0, 4: 0, 5: 0}
	var item_ids := _sorted_item_ids(m3)
	if item_ids.is_empty():
		return totals
	for item_id in item_ids:
		var profile: Dictionary = m3.call("_resolve_item_score_profile", item_id, "plain")
		var tile_points := int(profile.get("points", 0))
		var tile_multi := int(profile.get("multi", 0))
		for size in MATCH_SIZES:
			var move_pts: int = size * tile_points
			var move_mult := maxi(1, size * tile_multi)
			totals[size] += move_pts * move_mult
	var count := item_ids.size()
	var avgs := {}
	for size in MATCH_SIZES:
		avgs[size] = int(round(float(totals[size]) / float(count)))
	return avgs


func _sorted_item_ids(m3) -> Array[String]:
	var out: Array[String] = []
	var cfg = m3.get_node("configuration", true)
	if not cfg.is_valid():
		return out
	var items: GnosisNode = cfg.get_node("items")
	if not items.is_valid() or items.get_type() != GnosisValueType.OBJECT:
		return out
	for key in items.get_keys():
		var id := str(key).strip_edges()
		if not id.is_empty():
			out.append(id)
	out.sort()
	return out


func _set_all_item_levels(m3, level: int) -> void:
	var m3_state: GnosisNode = m3.get_node("match3", false)
	if not m3_state.is_valid():
		return
	var levels: GnosisNode = m3_state.get_node("itemLevels")
	if not levels.is_valid() or levels.get_type() != GnosisValueType.OBJECT:
		levels = m3.context.store.create_object()
		m3_state.set_node("itemLevels", levels)
	for item_id in _sorted_item_ids(m3):
		levels.set_key(item_id, maxi(1, level))


func _env_int(name: String, default_value: int) -> int:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_valid_int():
		return raw.to_int()
	return default_value


func _env_float(name: String, default_value: float) -> float:
	var raw := OS.get_environment(name).strip_edges()
	if raw.is_valid_float():
		return raw.to_float()
	return default_value
