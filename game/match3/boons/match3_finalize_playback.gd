class_name Match3FinalizePlayback
extends RefCounted

## Ordered finalize UI steps (Unity finalizePlaybackSteps parity).

const KIND_CELL_FLOOR := "cell_floor_finalize"
const KIND_BOON_SCORE := "boon_score"
const KIND_BOON_ECHO := "boon_contribution_echo"

const SALTY_STEEL_ECHO_CALC_ID := "salty_steel_scored_mult"
const SCALING_UP_CALC_ID := "boon_scaling_counter_up"


static func build_from_match_result(scoring_result) -> Array:
	if scoring_result == null:
		return []
	var cell_steps: Array = scoring_result.cell_floor_finalize_steps if "cell_floor_finalize_steps" in scoring_result else []
	var boon_steps: Array = scoring_result.boon_finalize_steps if "boon_finalize_steps" in scoring_result else []
	return build_from_step_lists(cell_steps, boon_steps)


static func build_from_step_lists(cell_steps: Array, boon_steps: Array) -> Array:
	var playback: Array = []
	var echo_steps: Array = []
	var boon_score_steps: Array = []
	for step in boon_steps:
		if not (step is Dictionary):
			continue
		var calc_id := str(step.get("calculationId", "")).to_lower()
		if calc_id == SALTY_STEEL_ECHO_CALC_ID:
			echo_steps.append(step)
		else:
			boon_score_steps.append(step)
	var echo_index := 0
	for cell_step in cell_steps:
		if not (cell_step is Dictionary):
			continue
		var tagged: Dictionary = cell_step.duplicate()
		tagged["playbackKind"] = KIND_CELL_FLOOR
		playback.append(tagged)
		var floor_id := str(cell_step.get("floorTypeId", "")).strip_edges().to_lower()
		if floor_id == "steel" and echo_index < echo_steps.size():
			var echo_tagged: Dictionary = echo_steps[echo_index].duplicate()
			echo_tagged["playbackKind"] = KIND_BOON_ECHO
			playback.append(echo_tagged)
			echo_index += 1
	for step in boon_score_steps:
		var tagged: Dictionary = step.duplicate()
		var calc_id := str(step.get("calculationId", "")).to_lower()
		tagged["playbackKind"] = KIND_BOON_ECHO if calc_id == SCALING_UP_CALC_ID else KIND_BOON_SCORE
		playback.append(tagged)
	for i in range(echo_index, echo_steps.size()):
		var echo_tagged: Dictionary = echo_steps[i].duplicate()
		echo_tagged["playbackKind"] = KIND_BOON_ECHO
		playback.append(echo_tagged)
	return playback
