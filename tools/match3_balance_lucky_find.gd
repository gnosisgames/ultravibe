class_name Match3BalanceLuckyFind
extends RefCounted

## Analytic cascade-assist model for balance reports (matches runtime rules in match3_lucky_find.gd).
## Assist −100…+100: negative = hinder rate, positive = help rate, 0 = neutral refills.
## Pity nudges assist up on opening-only scores; resets after a lucky help chain.
## Mega-chain: after a successful help refill in one move, next refill has MEGA_CHAIN_CHANCE
## to force another help (up to MAX_LUCKY_HELPS_PER_MOVE per move).

const GOLDEN_LUCKY_FIND_BONUS_ASSIST := 10.0
const GOLDEN_LUCKY_FIND_MAX_STACKS := 10

const DEFAULT_PERMANENT_ASSIST := -50.0
const DEFAULT_PITY_INCREMENT_ASSIST := 5.0

const MIN_ASSIST := -100.0
const MAX_ASSIST := 100.0
const MAX_LUCKY_HELPS_PER_MOVE := 3
const MEGA_CHAIN_CHANCE := 0.55

## Fraction of non-opening-only scoring moves that produce another natural cascade step.
const NATURAL_CASCADE_FACTOR := 0.65
## Expected cascade steps suppressed per hinder activation on a refill batch.
const HINDER_STEP_SUPPRESSION := 0.40


static func load_ephemeral_tuning() -> Dictionary:
	var out := {
		"enabled": true,
		"permanentAssist": DEFAULT_PERMANENT_ASSIST,
		"pityIncrementAssist": DEFAULT_PITY_INCREMENT_ASSIST,
		"source": "defaults",
	}
	if not FileAccess.file_exists("res://data/ephemeral.json"):
		return out
	var text := FileAccess.get_file_as_string("res://data/ephemeral.json")
	if text.is_empty():
		return out
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return out
	var ephemeral: Dictionary = parsed.get("Ephemeral", {})
	var m3: Dictionary = ephemeral.get("match3", {})
	var tuning: Dictionary = m3.get("luckyFindTuning", {})
	if tuning.is_empty():
		tuning = m3.get("luckyFind", {})
	if tuning.is_empty():
		return out
	out["enabled"] = bool(tuning.get("enabled", true))
	out["permanentAssist"] = _assist_from_tuning_dict(tuning)
	out["pityIncrementAssist"] = float(
		tuning.get("pityIncrementAssist", tuning.get("pityIncrementPercent", DEFAULT_PITY_INCREMENT_ASSIST))
	)
	out["source"] = "data/ephemeral.json"
	return out


static func _assist_from_tuning_dict(tuning: Dictionary) -> float:
	if tuning.has("permanentAssist"):
		return clampf(float(tuning.get("permanentAssist", DEFAULT_PERMANENT_ASSIST)), MIN_ASSIST, MAX_ASSIST)
	if tuning.has("permanentCascadeAssist"):
		return clampf(float(tuning.get("permanentCascadeAssist", DEFAULT_PERMANENT_ASSIST)), MIN_ASSIST, MAX_ASSIST)
	if tuning.has("permanentChancePercent"):
		return clampf(float(tuning.get("permanentChancePercent", 0.0)) - 50.0, MIN_ASSIST, MAX_ASSIST)
	return DEFAULT_PERMANENT_ASSIST


static func effective_permanent_assist(tuning: Dictionary, upgrade_stacks: int) -> float:
	var stacks := clampi(upgrade_stacks, 0, GOLDEN_LUCKY_FIND_MAX_STACKS)
	return clampf(
		_assist_from_tuning_dict(tuning) + float(stacks) * GOLDEN_LUCKY_FIND_BONUS_ASSIST,
		MIN_ASSIST,
		MAX_ASSIST
	)


static func assist_rates(assist: float) -> Dictionary:
	var clamped := clampf(assist, MIN_ASSIST, MAX_ASSIST)
	return {
		"help_rate": maxf(0.0, clamped) / 100.0,
		"hinder_rate": maxf(0.0, -clamped) / 100.0,
	}


static func pity_curve_rows(permanent: float, pity_inc: float, max_opening_only: int) -> Array:
	var rows: Array = []
	var temp := permanent
	for k in range(0, max_opening_only + 1):
		var rates := assist_rates(temp)
		rows.append({
			"opening_only_moves": k,
			"temporary_assist": temp,
			"help_rate": rates.help_rate,
			"hinder_rate": rates.hinder_rate,
		})
		if k < max_opening_only:
			temp = clampf(temp + pity_inc, MIN_ASSIST, MAX_ASSIST)
	return rows


static func simulate_round(
	moves: int,
	hit_rate: float,
	opening_only_rate: float,
	permanent: float,
	pity_inc: float,
	lucky_extra_steps: float,
	enabled: bool,
	natural_cascade_factor: float = NATURAL_CASCADE_FACTOR,
	hinder_suppression: float = HINDER_STEP_SUPPRESSION,
	mega_chain_chance: float = MEGA_CHAIN_CHANCE,
	max_lucky_helps_per_move: int = MAX_LUCKY_HELPS_PER_MOVE
) -> Dictionary:
	if not enabled or moves <= 0:
		return _empty_round_stats(permanent)

	var temp := permanent
	var pending_force := false
	var total_lucky_steps := 0.0
	var total_help := 0.0
	var total_help_flat := 0.0
	var total_hinder := 0.0
	var total_natural_extra := 0.0
	var scoring_moves_expected := 0.0

	for _m in range(moves):
		var p_score := clampf(hit_rate, 0.0, 1.0)
		scoring_moves_expected += p_score
		if p_score <= 0.0:
			continue

		var p_opening_only := clampf(opening_only_rate, 0.0, 1.0) * p_score
		var p_natural_score := p_score - p_opening_only
		var e_natural_raw := p_natural_score * natural_cascade_factor
		var refill_count := 1.0 + e_natural_raw

		var rates := assist_rates(temp)
		var help_rate: float = rates.help_rate
		var hinder_rate: float = rates.hinder_rate

		var force_first := pending_force and temp > 0.0
		if pending_force:
			pending_force = false

		var e_help := p_score * _expected_help_activations(
			refill_count, help_rate, force_first, mega_chain_chance, max_lucky_helps_per_move
		)
		var e_help_flat := p_score * _expected_help_activations_flat(refill_count, help_rate, force_first)
		var e_hinder := p_score * refill_count * hinder_rate
		var e_natural := maxf(0.0, e_natural_raw - e_hinder * hinder_suppression)

		total_help += e_help
		total_help_flat += e_help_flat
		total_hinder += e_hinder
		total_natural_extra += e_natural
		total_lucky_steps += e_help * maxf(0.0, lucky_extra_steps)

		temp = clampf(temp + p_opening_only * pity_inc, MIN_ASSIST, MAX_ASSIST)
		var p_reset := minf(1.0, e_help)
		temp = temp * (1.0 - p_reset) + permanent * p_reset

	var scoring_div := scoring_moves_expected if scoring_moves_expected > 0.0 else 1.0
	var help_per_scoring := total_help / scoring_div
	var help_flat_per_scoring := total_help_flat / scoring_div
	return {
		"expected_lucky_extra_per_move": total_lucky_steps / float(moves),
		"expected_lucky_extra_per_scoring_move": total_lucky_steps / scoring_div,
		"expected_help_activations_per_scoring_move": help_per_scoring,
		"expected_help_activations_flat_per_scoring_move": help_flat_per_scoring,
		"expected_mega_chain_bonus_helps_per_scoring_move": maxf(0.0, help_per_scoring - help_flat_per_scoring),
		"expected_hinder_activations_per_scoring_move": total_hinder / scoring_div,
		"expected_natural_extra_per_scoring_move": total_natural_extra / scoring_div,
		"expected_activations_per_scoring_move": help_per_scoring,
		"ending_temporary_assist": temp,
		"scoring_moves_expected": scoring_moves_expected,
	}


static func _empty_round_stats(permanent: float) -> Dictionary:
	return {
		"expected_lucky_extra_per_move": 0.0,
		"expected_lucky_extra_per_scoring_move": 0.0,
		"expected_help_activations_per_scoring_move": 0.0,
		"expected_help_activations_flat_per_scoring_move": 0.0,
		"expected_mega_chain_bonus_helps_per_scoring_move": 0.0,
		"expected_hinder_activations_per_scoring_move": 0.0,
		"expected_natural_extra_per_scoring_move": 0.0,
		"expected_activations_per_scoring_move": 0.0,
		"ending_temporary_assist": permanent,
		"scoring_moves_expected": 0.0,
	}


static func mega_chain_help_multiplier(
	refill_count: float,
	help_rate: float,
	mega_chain_chance: float = MEGA_CHAIN_CHANCE,
	max_lucky_helps_per_move: int = MAX_LUCKY_HELPS_PER_MOVE
) -> float:
	if refill_count <= 0.0 or help_rate <= 0.0:
		return 1.0
	var flat := _expected_help_activations_flat(refill_count, help_rate, false)
	if flat <= 0.0:
		return 1.0
	var chained := _expected_help_activations(
		refill_count, help_rate, false, mega_chain_chance, max_lucky_helps_per_move
	)
	return chained / flat


static func lucky_addon_multiplier(natural_extra: int, lucky_extra_steps: float, yield_factor: float) -> float:
	return lucky_addon_multiplier_float(float(natural_extra), lucky_extra_steps, yield_factor)


static func lucky_addon_multiplier_float(natural_extra: float, lucky_extra_steps: float, yield_factor: float) -> float:
	if lucky_extra_steps <= 0.0:
		return 0.0
	var base_step := natural_extra + 1.0
	var addon := 0.0
	var whole := int(floor(lucky_extra_steps))
	var frac := lucky_extra_steps - float(whole)
	for step in range(whole):
		addon += pow(yield_factor, base_step + float(step))
	if frac > 0.0:
		addon += frac * pow(yield_factor, base_step + float(whole))
	return addon


static func expected_move_score_with_lucky(
	opening_score: int,
	natural_extra: int,
	yield_factor: float,
	hit_rate: float,
	lucky_extra_steps: float
) -> float:
	var mult := _cascade_multiplier(natural_extra, yield_factor)
	mult += lucky_addon_multiplier(natural_extra, lucky_extra_steps, yield_factor)
	return float(opening_score) * mult * hit_rate


static func expected_move_score_from_simulation(
	opening_score: int,
	yield_factor: float,
	hit_rate: float,
	round_stats: Dictionary
) -> float:
	var natural_extra := float(round_stats.get("expected_natural_extra_per_scoring_move", 0.0))
	var lucky_extra := float(round_stats.get("expected_lucky_extra_per_scoring_move", 0.0))
	var mult := _cascade_multiplier_float(natural_extra, yield_factor)
	mult += lucky_addon_multiplier_float(natural_extra, lucky_extra, yield_factor)
	return float(opening_score) * mult * hit_rate


static func _cascade_multiplier(extra_cascades: int, yield_factor: float) -> float:
	return _cascade_multiplier_float(float(extra_cascades), yield_factor)


static func _cascade_multiplier_float(extra_cascades: float, yield_factor: float) -> float:
	var total := 1.0
	var whole := int(floor(extra_cascades))
	var frac := extra_cascades - float(whole)
	for step in range(1, whole + 1):
		total += pow(yield_factor, float(step))
	if frac > 0.0:
		total += frac * pow(yield_factor, float(whole + 1))
	return total


static func _expected_help_activations(
	refill_count: float,
	help_rate: float,
	force_first: bool,
	mega_chain_chance: float = MEGA_CHAIN_CHANCE,
	max_lucky_helps_per_move: int = MAX_LUCKY_HELPS_PER_MOVE
) -> float:
	if refill_count <= 0.0 or help_rate <= 0.0:
		return 0.0
	return _expected_help_activations_state(
		refill_count, help_rate, force_first, 0, false, mega_chain_chance, max_lucky_helps_per_move
	)


static func _expected_help_activations_flat(refill_count: float, help_rate: float, force_first: bool) -> float:
	if refill_count <= 0.0:
		return 0.0
	if force_first and help_rate > 0.0:
		return refill_count
	if help_rate <= 0.0:
		return 0.0
	return refill_count * help_rate


static func _expected_help_activations_state(
	remaining: float,
	help_rate: float,
	force: bool,
	help_count: int,
	mega_pending: bool,
	mega_chain_chance: float = MEGA_CHAIN_CHANCE,
	max_lucky_helps_per_move: int = MAX_LUCKY_HELPS_PER_MOVE
) -> float:
	if remaining <= 0.0 or help_count >= max_lucky_helps_per_move:
		return 0.0

	var batch := minf(1.0, remaining)
	var p_activate := 0.0
	if mega_pending:
		p_activate = 1.0
	elif force:
		p_activate = 1.0
	else:
		p_activate = help_rate

	var e_here := batch * p_activate
	var rest := remaining - batch
	if p_activate <= 0.0:
		return _expected_help_activations_state(
			rest, help_rate, false, help_count, false, mega_chain_chance, max_lucky_helps_per_move
		)

	var p_chain := mega_chain_chance if help_count + 1 < max_lucky_helps_per_move else 0.0
	var e_after := 0.0
	e_after += p_activate * p_chain * _expected_help_activations_state(
		rest, help_rate, false, help_count + 1, true, mega_chain_chance, max_lucky_helps_per_move
	)
	e_after += p_activate * (1.0 - p_chain) * _expected_help_activations_state(
		rest, help_rate, false, help_count + 1, false, mega_chain_chance, max_lucky_helps_per_move
	)
	e_after += (1.0 - p_activate) * _expected_help_activations_state(
		rest, help_rate, false, help_count, false, mega_chain_chance, max_lucky_helps_per_move
	)
	return e_here + e_after
