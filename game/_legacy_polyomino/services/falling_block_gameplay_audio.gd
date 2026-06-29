class_name FallingBlockGameplayAudio
extends RefCounted

## Unity-parity piece + line-clear SFX via Gnosis Audio/Haptic services.
## Mirrors FallingBlockGnosisService.Animation.partial.cs + Constants.partial.cs.

const AudioServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_audio_service.gd")
const HapticServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_haptic_service.gd")

const FEEDBACK_COOLDOWN_MOVE_SECONDS := 0.10
const FEEDBACK_COOLDOWN_ROTATE_SECONDS := 0.12
const FEEDBACK_COOLDOWN_HARD_DROP_SECONDS := 0.06
const FEEDBACK_COOLDOWN_DISCARD_SECONDS := 0.18

const PIECE_FEEDBACK_JUICE_STREAK_RESET_SECONDS := 0.35
const PIECE_FEEDBACK_JUICE_RAMP_FULL_STREAK := 14
const PIECE_FEEDBACK_JUICE_MIN_PITCH := 1.0
const PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE := 1.28
const PIECE_FEEDBACK_JUICE_MAX_PITCH_ROTATE := 1.32
const PIECE_FEEDBACK_JUICE_MAX_PITCH_HARD_DROP := 1.38
const PIECE_FEEDBACK_JUICE_VOLUME := 0.92

const LINE_CLEAR_RANDOM_PITCH_MIN := 0.9
const LINE_CLEAR_RANDOM_PITCH_MAX := 1.1

const CLIP_MOVE := "move"
const CLIP_ROTATE := "rotate"
const CLIP_DISCARD := "discard"
const CLIP_HARD_DROP := "hard_drop"
const CLIP_LEVEL_FINISHED := "level_finished"
const CLIP_GAME_OVER := "game_over"

const _LINE_CLEAR_CLIPS := {
	1: "line_clear_1",
	2: "line_clear_2",
	3: "line_clear_3",
	4: "line_clear_4",
	5: "line_clear_5",
	6: "line_clear_6",
}

const _LINE_CLEAR_VOLUME_RANGES := {
	1: Vector2(0.8, 1.0),
	2: Vector2(0.9, 1.1),
	3: Vector2(1.0, 1.2),
	4: Vector2(1.1, 1.3),
	5: Vector2(1.2, 1.5),
	6: Vector2(1.5, 2.0),
}

var _svc: FallingBlockService = null
var _sfx_haptic_last_played_at: Dictionary = {}
var _juice_streaks: Dictionary = {}


func bind_service(svc: FallingBlockService) -> void:
	_svc = svc


func reset_streaks() -> void:
	_sfx_haptic_last_played_at.clear()
	_juice_streaks.clear()


static func compute_juice_progress01(streak: int) -> float:
	var full := maxi(1, PIECE_FEEDBACK_JUICE_RAMP_FULL_STREAK)
	return clampf(float(streak - 1) / float(full - 1), 0.0, 1.0)


static func compute_juice_pitch(streak: int, max_pitch: float) -> float:
	var progress := compute_juice_progress01(streak)
	return PIECE_FEEDBACK_JUICE_MIN_PITCH + (max_pitch - PIECE_FEEDBACK_JUICE_MIN_PITCH) * progress


func play_move() -> void:
	_play_sfx_and_piece_haptic(
		"move",
		FEEDBACK_COOLDOWN_MOVE_SECONDS,
		CLIP_MOVE,
		"Move",
		PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE,
		true
	)


func play_rotate() -> void:
	_play_sfx_and_piece_haptic(
		"rotate",
		FEEDBACK_COOLDOWN_ROTATE_SECONDS,
		CLIP_ROTATE,
		"Rotate",
		PIECE_FEEDBACK_JUICE_MAX_PITCH_ROTATE,
		true
	)


func play_discard() -> void:
	_play_sfx_and_piece_haptic(
		"discard",
		FEEDBACK_COOLDOWN_DISCARD_SECONDS,
		CLIP_DISCARD,
		"Discard",
		PIECE_FEEDBACK_JUICE_MAX_PITCH_MOVE,
		false
	)


func play_hard_drop() -> void:
	_play_sfx_and_piece_haptic(
		"hardDrop",
		FEEDBACK_COOLDOWN_HARD_DROP_SECONDS,
		CLIP_HARD_DROP,
		"HardDrop",
		PIECE_FEEDBACK_JUICE_MAX_PITCH_HARD_DROP,
		true
	)


func play_line_clear(cleared_lines: int) -> void:
	if cleared_lines <= 0:
		return
	var tier := 6 if cleared_lines >= 6 else cleared_lines
	var clip_id: String = _LINE_CLEAR_CLIPS.get(tier, "line_clear_1")
	var vol_range: Vector2 = _LINE_CLEAR_VOLUME_RANGES.get(tier, Vector2(0.8, 1.0))
	var pitch := randf_range(LINE_CLEAR_RANDOM_PITCH_MIN, LINE_CLEAR_RANDOM_PITCH_MAX)
	var volume := randf_range(vol_range.x, vol_range.y)
	_play_sfx_clip(clip_id, volume, pitch)


func play_level_finished() -> void:
	_play_sfx_clip(CLIP_LEVEL_FINISHED)


func play_game_over() -> void:
	var haptic := _haptic()
	if haptic:
		haptic.play_piece_feedback("GameOver")
	_play_sfx_clip(CLIP_GAME_OVER)


func _play_sfx_and_piece_haptic(
	cooldown_key: String,
	cooldown_seconds: float,
	clip_id: String,
	haptic_kind: String,
	max_pitch: float,
	use_juice_pitch_ramp: bool
) -> void:
	if _svc == null or clip_id.is_empty() or haptic_kind.is_empty():
		return
	var now := _now()
	if cooldown_seconds > 0.0 and _sfx_haptic_last_played_at.has(cooldown_key):
		var last_at: float = _sfx_haptic_last_played_at[cooldown_key]
		if now - last_at < cooldown_seconds:
			return
	var haptic := _haptic()
	if haptic:
		haptic.play_piece_feedback(haptic_kind)
	if use_juice_pitch_ramp:
		_play_piece_feedback_juice_tick(cooldown_key, clip_id, now, max_pitch)
	else:
		_play_sfx_clip(clip_id)
	_sfx_haptic_last_played_at[cooldown_key] = now


func _play_piece_feedback_juice_tick(streak_key: String, clip_id: String, now: float, max_pitch: float) -> void:
	var streak := 1
	if _juice_streaks.has(streak_key):
		var previous: Dictionary = _juice_streaks[streak_key]
		if now - float(previous.get("last_at", 0.0)) <= PIECE_FEEDBACK_JUICE_STREAK_RESET_SECONDS:
			streak = int(previous.get("count", 0)) + 1
	_juice_streaks[streak_key] = {"count": streak, "last_at": now}
	var progress := compute_juice_progress01(streak)
	var audio := _audio()
	if audio == null:
		return
	audio.play_juice_tick(
		[clip_id],
		progress,
		"roundRobin",
		"polydrop_piece_%s" % streak_key,
		PIECE_FEEDBACK_JUICE_MIN_PITCH,
		max_pitch,
		PIECE_FEEDBACK_JUICE_VOLUME,
		AudioServiceScript.SoundTrack.Sfx
	)


func _play_sfx_clip(clip_id: String, volume: float = 1.0, pitch: float = 1.0) -> void:
	var audio := _audio()
	if audio == null or clip_id.is_empty():
		return
	var store := _store()
	if store == null:
		return
	var options := store.create_object()
	options.set_key("volume", volume)
	options.set_key("pitch", pitch)
	audio.play_sound(clip_id, AudioServiceScript.SoundTrack.Sfx, false, false, options)


func _audio() -> GnosisAudioService:
	if _svc == null or _svc.context == null or _svc.context.engine == null:
		return null
	return _svc.context.engine.get_service("Audio") as GnosisAudioService


func _haptic() -> GnosisHapticService:
	if _svc == null or _svc.context == null or _svc.context.engine == null:
		return null
	return _svc.context.engine.get_service("Haptic") as GnosisHapticService


func _store() -> GnosisStore:
	if _svc == null or _svc.context == null:
		return null
	return _svc.context.store


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
