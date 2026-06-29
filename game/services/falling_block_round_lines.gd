class_name FallingBlockRoundLines
extends RefCounted

## Lines-cleared quota per round. Round 1 = 5 lines, then +1 each round (6, 7, 8, 9, ...).

const BASE_LINES_PER_ROUND := 5
const LINES_PER_ROUND_INCREMENT := 1

static func target_lines_for_round(round_number: int) -> int:
	var round := maxi(1, round_number)
	return BASE_LINES_PER_ROUND + (round - 1) * LINES_PER_ROUND_INCREMENT
