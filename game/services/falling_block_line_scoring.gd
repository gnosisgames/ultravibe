class_name FallingBlockLineScoring
extends RefCounted

## Fixed score awarded per physical line-clear burst (independent of block variants).

const SCORE_SINGLE := 100
const SCORE_DOUBLE := 250
const SCORE_TRIPLE := 500
const SCORE_QUAD := 1000
const SCORE_PENTA_PLUS := 5000

static func score_for_lines(raw_lines: int) -> int:
	match clampi(raw_lines, 0, 999):
		0: return 0
		1: return SCORE_SINGLE
		2: return SCORE_DOUBLE
		3: return SCORE_TRIPLE
		4: return SCORE_QUAD
		_: return SCORE_PENTA_PLUS

static func score_as_scalable(raw_lines: int) -> GnosisScalableValue:
	return FallingBlockEphemeral.scalable_from_int(score_for_lines(raw_lines))
