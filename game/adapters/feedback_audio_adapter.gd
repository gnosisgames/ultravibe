class_name FeedbackAudioAdapter
extends GnosisAdapter

const AudioServiceScript = preload("res://addons/com.gnosisgames.gnosisengine/services/gnosis_audio_service.gd")
const FeedbackRegistry = preload("res://game/services/feedback_audio_registry.gd")

var _subscription: RefCounted = null


func _exit_tree() -> void:
	_dispose_subscription()


func _on_service_bound() -> void:
	_register_feedback_ids()
	_subscribe()


func _register_feedback_ids() -> void:
	if not engine:
		return
	var anim := engine.get_service("Animation") as GnosisAnimationService
	if anim == null:
		return
	anim.register_feedback_ids(FeedbackRegistry.get_feedback_ids())


func _subscribe() -> void:
	_dispose_subscription()
	if not engine or not engine.event_bus:
		return
	_subscription = engine.event_bus.subscribe(
		GnosisAnimationService.REQUEST_FEEDBACK_PLAY,
		_on_feedback_play_requested,
		0
	)


func _on_feedback_play_requested(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	var id_node := event.data.get_node("id")
	if not id_node.is_valid() or id_node.value == null:
		return
	var feedback_id := str(id_node.value).strip_edges()
	if feedback_id.is_empty():
		return
	_play_feedback_audio(feedback_id)


func _play_feedback_audio(feedback_id: String) -> void:
	var entry := FeedbackRegistry.resolve(feedback_id)
	if entry.is_empty():
		return
	var clip_id := str(entry.get("clip", "")).strip_edges()
	if clip_id.is_empty():
		return
	var audio := _audio()
	if audio == null or not engine or not engine.store:
		return
	var options := engine.store.create_object()
	options.set_key("volume", float(entry.get("volume", 1.0)))
	options.set_key("pitch", float(entry.get("pitch", 1.0)))
	audio.play_sound(clip_id, AudioServiceScript.SoundTrack.Sfx, false, false, options)


func _audio() -> GnosisAudioService:
	if engine == null:
		return null
	return engine.get_service("Audio") as GnosisAudioService


func _dispose_subscription() -> void:
	if _subscription and _subscription.has_method("dispose"):
		_subscription.dispose()
	_subscription = null
