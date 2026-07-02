class_name Match3HudMetrics
extends RefCounted

## Running step points/multi for interleaved HUD playback (Unity hudMetrics parity).


static func annotate_boon_score_steps(steps: Array, final_points: int, final_multi: int) -> void:
	_annotate_steps(steps, final_points, final_multi, true)


static func annotate_finalize_playback_steps(playback: Array, final_points: int, final_multi: int) -> void:
	var sum_points := 0
	var sum_multi := 0
	for step in playback:
		if not (step is Dictionary):
			continue
		var kind := str(step.get("playbackKind", "")).to_lower()
		if kind == Match3FinalizePlayback.KIND_CELL_FLOOR:
			sum_multi += int(step.get("multiDelta", 0))
		else:
			sum_points += int(step.get("pointsDelta", 0))
			sum_multi += int(step.get("multiDelta", 0))
	var running_points := maxi(0, final_points - sum_points)
	var running_multi := maxi(1, final_multi - sum_multi)
	for step in playback:
		if not (step is Dictionary):
			continue
		var kind := str(step.get("playbackKind", "")).to_lower()
		if kind == Match3FinalizePlayback.KIND_CELL_FLOOR:
			running_multi += int(step.get("multiDelta", 0))
		else:
			running_points += int(step.get("pointsDelta", 0))
			running_multi += int(step.get("multiDelta", 0))
		step["stepPoints"] = running_points
		step["stepMulti"] = running_multi


static func _annotate_steps(steps: Array, final_points: int, final_multi: int, include_cell_floor_multi_only: bool) -> void:
	var sum_points := 0
	var sum_multi := 0
	for step in steps:
		if not (step is Dictionary):
			continue
		if not _step_has_hud_feedback(step):
			continue
		sum_points += int(step.get("pointsDelta", 0))
		sum_multi += int(step.get("multiDelta", 0))
	var running_points := maxi(0, final_points - sum_points)
	var running_multi := maxi(1, final_multi - sum_multi)
	for step in steps:
		if not (step is Dictionary):
			continue
		if not _step_has_hud_feedback(step):
			continue
		running_points += int(step.get("pointsDelta", 0))
		running_multi += int(step.get("multiDelta", 0))
		step["stepPoints"] = running_points
		step["stepMulti"] = running_multi


static func _step_has_hud_feedback(step: Dictionary) -> bool:
	if int(step.get("pointsDelta", 0)) != 0 or int(step.get("multiDelta", 0)) != 0:
		return true
	if not str(step.get("pointsDisplayText", "")).is_empty():
		return true
	if not str(step.get("multiDisplayText", "")).is_empty():
		return true
	return false
