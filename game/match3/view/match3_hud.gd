class_name Match3Hud
extends Control

## Minimal match-3 HUD (score, target, moves).

@onready var _score_label: Label = %ScoreLabel
@onready var _target_label: Label = %TargetLabel
@onready var _moves_label: Label = %MovesLabel
@onready var _status_label: Label = %StatusLabel

const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")

var _service = null


func bind_service(service) -> void:
	_service = service
	refresh_from_service(service)


func refresh_from_service(service = null) -> void:
	if service:
		_service = service
	if _service == null:
		return
	var gameplay = _service.get_gameplay()
	if _score_label:
		_score_label.text = "Score: %d" % gameplay.current_score
	if _target_label:
		_target_label.text = "Target: %d" % gameplay.target_score
	if _moves_label:
		_moves_label.text = "Moves: %d" % gameplay.current_moves
	if _status_label:
		_status_label.text = _status_text(gameplay.status)


func _status_text(status: int) -> String:
	match status:
		Match3ModelsScript.STATUS_WIN:
			return "You win!"
		Match3ModelsScript.STATUS_LOSS:
			return "Out of moves"
		Match3ModelsScript.STATUS_PLAYING:
			return ""
		_:
			return ""
