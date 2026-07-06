extends SceneTree

## Round difficulty vs isolated match scores + cascade chain model + Lucky Find assist.
## Uses the same target/moves formulas as Match3Service (not ephemeral roundTargets array).
##
## Run: ./tools/match3_round_balance_report.sh
## Env:
##   MATCH3_SCORE_MAX_LEVEL=1       item level for avg gem profile (default 1)
##   MATCH3_CASCADE_YIELD=0.55      each cascade step scores yield^k × opening match (default 0.55)
##   MATCH3_HIT_RATE=0.70           fraction of moves that score (default 0.70)
##   MATCH3_OPENING_ONLY_RATE=0.40  scoring moves with no natural cascade (pity builds)
##   MATCH3_LUCKY_EXTRA_STEPS=1.0   expected extra cascade steps when Lucky Find fires
##   MATCH3_LUCKY_UPGRADE_STACKS=0 GoldenLuckyFind stacks (0-4, +10% each)
##   MATCH3_USE_EPHEMERAL_LUCKY=1   read luckyFindTuning from data/ephemeral.json (default 1)
##   MATCH3_MAX_ROUND=24
##   MATCH3_OPENING_MATCH=3         opening match size 3|4|5 (default 3)

const LuckyFindModel = preload("res://tools/match3_balance_lucky_find.gd")

const MATCH_SIZES := [3, 4, 5]
const BASE_SCORE_TO_WIN := 1000
const BASE_MOVES_LIMIT := 10
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
	var hit_rate := clampf(_env_float("MATCH3_HIT_RATE", 0.70), 0.01, 1.0)
	var opening_only_rate := clampf(_env_float("MATCH3_OPENING_ONLY_RATE", 0.40), 0.0, 1.0)
	var lucky_extra_steps := maxf(0.0, _env_float("MATCH3_LUCKY_EXTRA_STEPS", 1.0))
	var upgrade_stacks := clampi(_env_int("MATCH3_LUCKY_UPGRADE_STACKS", 0), 0, 4)
	var use_ephemeral := _env_int("MATCH3_USE_EPHEMERAL_LUCKY", 1) != 0
	var max_round := _env_int("MATCH3_MAX_ROUND", 24)
	var opening_size := clampi(_env_int("MATCH3_OPENING_MATCH", 3), 3, 5)

	var lf_tuning := LuckyFindModel.load_ephemeral_tuning() if use_ephemeral else {
		"enabled": true,
		"permanentChancePercent": LuckyFindModel.DEFAULT_PERMANENT_PERCENT,
		"pityIncrementPercent": LuckyFindModel.DEFAULT_PITY_INCREMENT_PERCENT,
		"source": "defaults",
	}
	var lf_enabled := bool(lf_tuning.get("enabled", true))
	var permanent_pct := LuckyFindModel.effective_permanent_percent(lf_tuning, upgrade_stacks)
	var pity_pct := float(lf_tuning.get("pityIncrementPercent", LuckyFindModel.DEFAULT_PITY_INCREMENT_PERCENT))

	_set_all_item_levels(m3, item_level)
	var avgs := _average_gem_scores(m3)
	var opening_score := int(avgs.get(opening_size, avgs.get(3, 0)))

	print("")
	print("=== Match3 round balance (cascade + Lucky Find planning) ===")
	print("Runtime formulas: target = 1000 + (round-1)*350 × stage mult; moves = default + (round-1)/3 + boss+2")
	print("Item level %d | opening match-%d avg score %d | cascade yield %.2f | hit rate %.0f%%" % [
		item_level, opening_size, opening_score, cascade_yield, hit_rate * 100.0,
	])
	print("Comfort = (moves × expected_score_per_move) / target  (>1.0 = headroom)")
	print("Columns @N = N natural extra cascades; +LF adds expected Lucky Find steps for that round")
	print("")

	_print_lucky_find_section(
		lf_tuning, lf_enabled, permanent_pct, pity_pct, upgrade_stacks,
		opening_only_rate, lucky_extra_steps, hit_rate, max_round
	)
	print("")
	_print_cascade_multipliers(cascade_yield)
	print("")
	_print_round_table(
		max_round, opening_score, cascade_yield, hit_rate, opening_only_rate,
		permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
	)
	print("")
	_print_cycle_summary(
		max_round, opening_score, cascade_yield, hit_rate, opening_only_rate,
		permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
	)
	print("")
	_print_opening_sizes(
		m3, item_level, cascade_yield, hit_rate, opening_only_rate, max_round,
		permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
	)


func _print_lucky_find_section(
	lf_tuning: Dictionary,
	lf_enabled: bool,
	permanent_pct: float,
	pity_pct: float,
	upgrade_stacks: int,
	opening_only_rate: float,
	lucky_extra_steps: float,
	hit_rate: float,
	max_round: int
) -> void:
	print("-- Lucky Find model (%s) --" % str(lf_tuning.get("source", "?")))
	if not lf_enabled:
		print("disabled — comfort+LF columns match natural-only model")
		return
	print(
		"base %.0f%% | pity +%.0f%% per opening-only score | upgrade stacks %d (+%.0f%% each, max %d)" % [
			permanent_pct,
			pity_pct,
			upgrade_stacks,
			LuckyFindModel.GOLDEN_LUCKY_FIND_BONUS_PERCENT,
			LuckyFindModel.GOLDEN_LUCKY_FIND_MAX_STACKS,
		]
	)
	print(
		"opening-only rate %.0f%% of scoring moves | expected lucky steps/activation %.2f" % [
			opening_only_rate * 100.0,
			lucky_extra_steps,
		]
	)
	print("Pity curve (temporary %% after k opening-only scores, no lucky reset):")
	for row in LuckyFindModel.pity_curve_rows(permanent_pct, pity_pct, 6):
		print(
			"  after %d opening-only → %.0f%%" % [
				int(row.opening_only_moves),
				float(row.temporary_chance_percent),
			]
		)
	var sample_moves := _resolve_moves_limit(9, "boss", BASE_MOVES_LIMIT)
	var sample := LuckyFindModel.simulate_round(
		sample_moves, hit_rate, opening_only_rate, permanent_pct, pity_pct, lucky_extra_steps, true
	)
	print(
		"Round 9 boss sample (%d moves): +%.3f lucky steps/scoring move | ending temp %.0f%%" % [
			sample_moves,
			float(sample.expected_lucky_extra_per_scoring_move),
			float(sample.ending_temporary_chance_percent),
		]
	)
	var early_moves := _resolve_moves_limit(1, "normal", BASE_MOVES_LIMIT)
	var early := LuckyFindModel.simulate_round(
		early_moves, hit_rate, opening_only_rate, permanent_pct, pity_pct, lucky_extra_steps, true
	)
	print(
		"Round 1 sample (%d moves): +%.3f lucky steps/scoring move | ending temp %.0f%%" % [
			early_moves,
			float(early.expected_lucky_extra_per_scoring_move),
			float(early.ending_temporary_chance_percent),
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
	permanent_pct: float,
	pity_pct: float,
	lucky_extra_steps: float,
	lf_enabled: bool
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
		"@1+LF",
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
		var lf_round := LuckyFindModel.simulate_round(
			moves, hit_rate, opening_only_rate, permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
		)
		var lf_extra := float(lf_round.expected_lucky_extra_per_scoring_move)
		var lf_expected := LuckyFindModel.expected_move_score_with_lucky(
			opening_score, 1, cascade_yield, hit_rate, lf_extra
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
	print("@1+LF = comfort at 1 natural extra cascade + expected Lucky Find for that round's move count")


func _print_cycle_summary(
	max_round: int,
	opening_score: int,
	cascade_yield: float,
	hit_rate: float,
	opening_only_rate: float,
	permanent_pct: float,
	pity_pct: float,
	lucky_extra_steps: float,
	lf_enabled: bool
) -> void:
	print("-- Cycle summary (avg comfort ratio per 3-round floor) --")
	print(
		"%-6s | rounds | avg target | avg moves | comfort@0 | comfort@1 | comfort@1+LF | comfort@2 | comfort@3" % [
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
			var lf_round := LuckyFindModel.simulate_round(
				moves, hit_rate, opening_only_rate, permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
			)
			var lf_expected := LuckyFindModel.expected_move_score_with_lucky(
				opening_score, 1, cascade_yield, hit_rate, float(lf_round.expected_lucky_extra_per_scoring_move)
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
	permanent_pct: float,
	pity_pct: float,
	lucky_extra_steps: float,
	lf_enabled: bool
) -> void:
	print("-- Opening match size sensitivity (round 9 boss, level %d) --" % item_level)
	_set_all_item_levels(m3, item_level)
	var avgs := _average_gem_scores(m3)
	var round_num := 9
	var stage := "boss"
	var target := _resolve_target_score(round_num, stage)
	var moves := _resolve_moves_limit(round_num, stage, BASE_MOVES_LIMIT)
	var lf_round := LuckyFindModel.simulate_round(
		moves, hit_rate, opening_only_rate, permanent_pct, pity_pct, lucky_extra_steps, lf_enabled
	)
	var lf_extra := float(lf_round.expected_lucky_extra_per_scoring_move)
	print(
		"Round 9: target %d, moves %d, lucky +%.3f extra steps/scoring move" % [
			target, moves, lf_extra,
		]
	)
	for size in MATCH_SIZES:
		var opening := int(avgs.get(size, 0))
		var parts: PackedStringArray = []
		for extra in range(0, 4):
			var expected := _expected_move_score(opening, extra, cascade_yield, hit_rate)
			var ratio := (float(moves) * expected) / float(target) if target > 0 else 0.0
			parts.append("%.2f" % ratio)
		var lf_expected := LuckyFindModel.expected_move_score_with_lucky(
			opening, 1, cascade_yield, hit_rate, lf_extra
		)
		var lf_ratio := (float(moves) * lf_expected) / float(target) if target > 0 else 0.0
		print(
			"  match-%d avg %4d | comfort @0/1/2/3: %s | @1+LF %.2f" % [
				size, opening, "/".join(parts), lf_ratio,
			]
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
	var target := BASE_SCORE_TO_WIN + (maxi(1, round_number) - 1) * 350
	if stage_type == "advanced":
		target = int(roundf(float(target) * 1.2))
	elif stage_type == "boss":
		target = int(roundf(float(target) * 1.5))
	return maxi(1, target)


func _resolve_moves_limit(round: int, stage_type: String, default_moves: int) -> int:
	var moves := default_moves + int((maxi(1, round) - 1) / 3)
	if stage_type == "boss":
		moves += 2
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
