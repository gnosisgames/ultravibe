class_name FeedbackAudioRegistry
extends RefCounted

const REGISTRY_PATH := "res://data/feedback_audio_registry.json"

static var _entries: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_entries.clear()
	if not FileAccess.file_exists(REGISTRY_PATH):
		push_warning("[FeedbackAudioRegistry] Missing registry at %s" % REGISTRY_PATH)
		return
	var file := FileAccess.open(REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return
	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	_entries = data


static func get_feedback_ids() -> Array[String]:
	ensure_loaded()
	var ids: Array[String] = []
	for key in _entries.keys():
		ids.append(str(key))
	return ids


static func resolve(feedback_id: String) -> Dictionary:
	ensure_loaded()
	if feedback_id.is_empty():
		return {}
	var direct: Variant = _entries.get(feedback_id)
	if typeof(direct) == TYPE_DICTIONARY:
		return direct
	for key in _entries.keys():
		if str(key).to_lower() == feedback_id.to_lower():
			var entry: Variant = _entries[key]
			return entry if typeof(entry) == TYPE_DICTIONARY else {}
	return {}
