extends SceneTree

## Balance model: mega-chain help activations exceed flat roll; comfort uses chained helps.

const LuckyFindModel = preload("res://tools/match3_balance_lucky_find.gd")

var _frames := 0
var _done := false


func _initialize() -> void:
	print("--- Match3 balance mega-chain test ---")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 2:
		return false
	if _done:
		return true
	_done = true
	var ok := _check_chain_beats_flat() and _check_comfort_uses_chain()
	print("--- Match3 balance mega-chain test %s ---" % ("Passed" if ok else "FAILED"))
	quit(0 if ok else 1)
	return true


func _check_chain_beats_flat() -> bool:
	var refill := 1.65
	var help_rate := 0.5
	var flat := LuckyFindModel._expected_help_activations_flat(refill, help_rate, false)
	var chained := LuckyFindModel._expected_help_activations(refill, help_rate, false)
	if chained <= flat + 0.001:
		print("[FAIL] chained helps %.3f should exceed flat %.3f" % [chained, flat])
		return false
	var mult := LuckyFindModel.mega_chain_help_multiplier(refill, help_rate)
	if mult <= 1.01:
		print("[FAIL] mega-chain multiplier %.3f should be > 1" % mult)
		return false
	print("[SUCCESS] mega-chain boosts help activations (flat %.3f → %.3f, ×%.2f)" % [flat, chained, mult])
	return true


func _check_comfort_uses_chain() -> bool:
	var stats := LuckyFindModel.simulate_round(
		14,
		0.70,
		0.40,
		50.0,
		LuckyFindModel.DEFAULT_PITY_INCREMENT_ASSIST,
		1.0,
		true
	)
	var chain_bonus := float(stats.expected_mega_chain_bonus_helps_per_scoring_move)
	if chain_bonus <= 0.01:
		print("[FAIL] +50 assist round sim should show mega-chain bonus helps, got %.3f" % chain_bonus)
		return false
	var flat_score := LuckyFindModel.expected_move_score_from_simulation(
		173,
		0.55,
		0.70,
		{
			"expected_natural_extra_per_scoring_move": stats.expected_natural_extra_per_scoring_move,
			"expected_lucky_extra_per_scoring_move": float(stats.expected_help_activations_flat_per_scoring_move),
		}
	)
	var chained_score := LuckyFindModel.expected_move_score_from_simulation(
		173, 0.55, 0.70, stats
	)
	if chained_score <= flat_score + 0.01:
		print("[FAIL] comfort score should rise with mega-chain (flat %.1f vs chain %.1f)" % [flat_score, chained_score])
		return false
	print("[SUCCESS] comfort model includes mega-chain bonus (chain +%.3f helps/scoring move)" % chain_bonus)
	return true
