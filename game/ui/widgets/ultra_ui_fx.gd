class_name UltraUiFx
extends RefCounted

const CLIP_HOVER := "ui_hover"
const CLIP_PRESSED := "ui_pressed"
const CLIP_BOP := "ui_bop"

## Unity round-reward money glyphs (Cartoon/coin1–7.wav via PlayJuiceTick).
const DEFAULT_ROUND_REWARD_COIN_CLIP_IDS: Array[String] = [
	"coin1Sfx", "coin2Sfx", "coin3Sfx", "coin4Sfx", "coin5Sfx", "coin6Sfx", "coin7Sfx",
]
const ROUND_REWARD_COIN_JUICE_POOL := "roundRewardMoneyGlyphs"

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

## Unity Match3GnosisService.PlayRoundRewardMoneyJuiceTick parity: shuffle-bag coin
## clip + pitch ramp from minPitch→maxPitch across the glyph sequence.
static func play_round_reward_coin_juice(from: Node, glyph_index: int, glyph_count: int) -> void:
	var host := resolve_host(from)
	if host == null or host.engine == null:
		return
	var audio := host.engine.get_service("Audio") as GnosisAudioService
	if audio == null:
		return
	var count := maxi(1, glyph_count)
	var index := clampi(glyph_index, 0, count - 1)
	var progress := 1.0 if count <= 1 else float(index) / float(count - 1)
	var clip_ids := _round_reward_coin_clip_ids(host.engine)
	audio.play_juice_tick(
		clip_ids,
		progress,
		"shuffleBag",
		ROUND_REWARD_COIN_JUICE_POOL,
		1.0,
		1.5,
		1.0,
		GnosisAudioService.SoundTrack.Sfx
	)

static func _round_reward_coin_clip_ids(engine: GnosisEngine) -> Array[String]:
	if engine == null or engine.state == null or not engine.state.root.is_valid():
		return DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()
	var ephemeral := engine.state.root.get_node("Ephemeral")
	if not ephemeral.is_valid():
		return DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()
	var match3 := ephemeral.get_node("match3")
	if not match3.is_valid():
		return DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()
	var audio := match3.get_node("audio")
	if not audio.is_valid() or audio.get_type() != GnosisValueType.OBJECT:
		return DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()
	var list_node := audio.get_node("roundRewardCoinJuiceClipIds")
	if not list_node.is_valid() or list_node.get_type() != GnosisValueType.LIST or list_node.get_count() == 0:
		return DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()
	var ids: Array[String] = []
	for i in range(list_node.get_count()):
		var entry := list_node.get_node(i)
		if not entry.is_valid() or entry.value == null:
			continue
		var clip_id := str(entry.value).strip_edges()
		if not clip_id.is_empty():
			ids.append(clip_id)
	return ids if not ids.is_empty() else DEFAULT_ROUND_REWARD_COIN_CLIP_IDS.duplicate()

static func vibrate(from: Node, preset: String = "selection") -> void:
	var host := resolve_host(from)
	if host == null or host.engine == null:
		return
	var haptic := host.engine.get_service("Haptic") as GnosisHapticService
	if haptic:
		haptic.play_preset(preset)
