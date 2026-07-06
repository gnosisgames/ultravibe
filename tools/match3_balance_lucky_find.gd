class_name Match3BalanceLuckyFind
extends RefCounted

## Analytic Lucky Find model for balance reports (matches runtime rules in match3_lucky_find.gd).
## Pity rises on scoring moves with zero natural cascade steps; resets after a lucky chain.

const GOLDEN_LUCKY_FIND_BONUS_PERCENT := 10.0
const GOLDEN_LUCKY_FIND_MAX_STACKS := 4

const DEFAULT_PERMANENT_PERCENT := 10.0
const DEFAULT_PITY_INCREMENT_PERCENT := 5.0


static func load_ephemeral_tuning() -> Dictionary:
	var out := {
		"enabled": true,
		"permanentChancePercent": DEFAULT_PERMANENT_PERCENT,
		"pityIncrementPercent": DEFAULT_PITY_INCREMENT_PERCENT,
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
	out["permanentChancePercent"] = float(tuning.get("permanentChancePercent", DEFAULT_PERMANENT_PERCENT))
	out["pityIncrementPercent"] = float(tuning.get("pityIncrementPercent", DEFAULT_PITY_INCREMENT_PERCENT))
	out["source"] = "data/ephemeral.json"
	return out


static func effective_permanent_percent(tuning: Dictionary, upgrade_stacks: int) -> float:
	var stacks := clampi(upgrade_stacks, 0, GOLDEN_LUCKY_FIND_MAX_STACKS)
	return maxf(
		0.0,
		float(tuning.get("permanentChancePercent", DEFAULT_PERMANENT_PERCENT))
		+ float(stacks) * GOLDEN_LUCKY_FIND_BONUS_PERCENT
	)


static func pity_curve_rows(permanent: float, pity_inc: float, max_opening_only: int) -> Array:
	var rows: Array = []
	var temp := permanent
	for k in range(0, max_opening_only + 1):
		rows.append({"opening_only_moves": k, "temporary_chance_percent": temp})
		if k < max_opening_only:
			temp += pity_inc
	return rows


static func simulate_round(
	moves: int,
	hit_rate: float,
	opening_only_rate: float,
	permanent: float,
	pity_inc: float,
	lucky_extra_steps: float,
	enabled: bool
) -> Dictionary:
	if not enabled or moves <= 0:
		return {
			"expected_lucky_extra_per_move": 0.0,
			"expected_lucky_extra_per_scoring_move": 0.0,
			"expected_activations_per_scoring_move": 0.0,
			"ending_temporary_chance_percent": permanent,
			"scoring_moves_expected": 0.0,
		}

	var temp := permanent
	var pending_force := false
	var total_lucky_steps := 0.0
	var total_activations := 0.0
	var scoring_moves_expected := 0.0

	for _m in range(moves):
		var p_score := clampf(hit_rate, 0.0, 1.0)
		scoring_moves_expected += p_score
		if p_score <= 0.0:
			continue

		var p_opening_only := clampf(opening_only_rate, 0.0, 1.0) * p_score
		var p_natural_cascade := p_score - p_opening_only
		var e_natural_extra := p_natural_cascade * 0.65
		var refill_count := 1.0 + e_natural_extra

		var p_activate := 1.0 if pending_force else minf(1.0, temp / 100.0)
		if pending_force:
			pending_force = false

		var e_activations := p_score * refill_count * p_activate
		total_activations += e_activations
		total_lucky_steps += e_activations * maxf(0.0, lucky_extra_steps)

		temp += p_opening_only * pity_inc
		var p_reset := minf(1.0, e_activations)
		temp = temp * (1.0 - p_reset) + permanent * p_reset

	return {
		"expected_lucky_extra_per_move": total_lucky_steps / float(moves),
		"expected_lucky_extra_per_scoring_move": (
			total_lucky_steps / scoring_moves_expected if scoring_moves_expected > 0.0 else 0.0
		),
		"expected_activations_per_scoring_move": (
			total_activations / scoring_moves_expected if scoring_moves_expected > 0.0 else 0.0
		),
		"ending_temporary_chance_percent": temp,
		"scoring_moves_expected": scoring_moves_expected,
	}


static func lucky_addon_multiplier(natural_extra: int, lucky_extra_steps: float, yield_factor: float) -> float:
	if lucky_extra_steps <= 0.0:
		return 0.0
	var base_step := float(natural_extra + 1)
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


static func _cascade_multiplier(extra_cascades: int, yield_factor: float) -> float:
	var total := 1.0
	for step in range(1, extra_cascades + 1):
		total += pow(yield_factor, float(step))
	return total
