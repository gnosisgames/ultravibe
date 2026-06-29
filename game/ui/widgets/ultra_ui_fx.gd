class_name UltraUiFx
extends RefCounted

const CLIP_HOVER := "ui_hover"
const CLIP_PRESSED := "ui_pressed"
const CLIP_BOP := "ui_bop"

static func resolve_host(from: Node) -> GnosisGodotEngine:
	var node: Node = from
	while node:
		if node is GnosisGodotEngine:
			return node as GnosisGodotEngine
		node = node.get_parent()
	return null

static func play_ui_sfx(from: Node, clip_id: String, volume: float = 0.0) -> void:
	var host := resolve_host(from)
	if host == null or host.engine == null:
		return
	var audio := host.engine.get_service("Audio") as GnosisAudioService
	if audio == null:
		return
	var options := host.engine.store.create_object()
	# `volume` is authored as a decibel offset (0.0 == unchanged, negative ==
	# quieter). The audio player's "volume" option is a LINEAR gain it feeds into
	# linear_to_db(), so convert here. Passing the raw dB value made the player
	# compute linear_to_db(-4.0) == NaN and reject the volume.
	if volume != 0.0:
		options.set_key("volume", db_to_linear(volume))
	audio.play_sound(clip_id, GnosisAudioService.SoundTrack.UI, false, false, options)

static func vibrate(from: Node, preset: String = "selection") -> void:
	var host := resolve_host(from)
	if host == null or host.engine == null:
		return
	var haptic := host.engine.get_service("Haptic") as GnosisHapticService
	if haptic:
		haptic.play_preset(preset)
