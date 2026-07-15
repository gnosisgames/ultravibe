class_name UltraEditionRunPressure
extends Node

## Applies GnosisEditionPolicy trial pressure during live match3 gameplay (mobile trial).

var _engine: GnosisEngine = null
var _elapsed := 0.0

func bind_engine(engine: GnosisEngine) -> void:
	_engine = engine
	_elapsed = 0.0

func _process(delta: float) -> void:
	if _engine == null or delta <= 0.0:
		return
	var edition := _engine.get_service("Edition") as GnosisEditionService
	var m3 = _engine.get_service("Match3")
	if edition == null or m3 == null:
		return
	if not edition.should_apply_trial_policy():
		_elapsed = 0.0
		return
	if not _gameplay_live():
		return
	if m3.has_method("is_run_game_over") and m3.is_run_game_over():
		return
	var policy = edition.get_policy()
	if policy == null or not policy.has_method("run_pressure_at_elapsed_seconds"):
		return
	_elapsed += delta
	var pressure: Dictionary = policy.run_pressure_at_elapsed_seconds(_elapsed)
	if bool(pressure.get("force_game_over", false)):
		if m3.has_method("force_trial_run_end"):
			m3.force_trial_run_end(str(pressure.get("reason", "trial")))

func _gameplay_live() -> bool:
	var ui := _engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return false
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	var m3 = _engine.get_service("Match3")
	if m3 == null or not m3.has_method("is_board_input_allowed"):
		return false
	return m3.is_board_input_allowed() \
		and ui.get_active_overlay_state_for_view("pause").is_empty() \
		and ui.get_active_overlay_state_for_view("game_over").is_empty()
