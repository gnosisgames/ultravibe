class_name UltraMusicPlaylistAdapter
extends GnosisAdapter

## Port of Unity Ultravibe's UnityAudioAdapter playlist behaviour:
## - "normal": 10 run themes, random-unique shuffle, cycle forever
## - "boss": 3 boss themes, random pick then loop that track until the encounter ends
## Switches on run start, boss encounter start/end, and game over (boss playlist after delay).

const PLAYLISTS_PATH := "res://data/music_playlists.json"
const PLAYLIST_NORMAL := "normal"
const PLAYLIST_BOSS := "boss"
const FB := preload("res://game/services/falling_block_ephemeral.gd")

@export var music_bus_name: String = "Music"
@export var playlist_fade_duration: float = 6.0
@export var run_start_fade_duration: float = 6.0
@export var delayed_start_delay: float = 4.0
@export var delayed_start_fade_duration: float = 6.0

var _asset_registry: GnosisAssetRegistry = null
var _music_player: AudioStreamPlayer
var _fade_tween: Tween
var _delay_timer: SceneTreeTimer
var _playlists: Dictionary = {}
var _default_playlist_id: String = PLAYLIST_NORMAL
var _current_playlist_id: String = ""
var _current_song_index: int = -1
var _shuffle_bag: Array[int] = []
var _loop_current_song: bool = false
var _play_forever: bool = true
var _song_linear_volume: float = 1.0
var _transition_gen: int = 0
var _subscriptions: Array = []
var _wired: bool = false
var _rng := RandomNumberGenerator.new()

func set_asset_registry(registry: GnosisAssetRegistry) -> void:
	_asset_registry = registry

func bind_engine(eng: GnosisEngine) -> void:
	super.bind_engine(eng)
	_wire_subscriptions()

func _ready() -> void:
	_rng.randomize()
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "PlaylistMusicPlayer"
	_music_player.bus = _resolve_music_bus()
	_music_player.finished.connect(_on_track_finished)
	add_child(_music_player)
	_load_playlist_config()

func _exit_tree() -> void:
	_cancel_delayed_start()
	_kill_fade_tween()
	for sub in _subscriptions:
		if sub and sub.has_method("dispose"):
			sub.dispose()
	_subscriptions.clear()

func _wire_subscriptions() -> void:
	if _wired or not engine or not engine.event_bus:
		return
	_wired = true
	var bus := engine.event_bus
	_subscriptions.append(bus.subscribe(
		FallingBlockEvents.FACT_FALLING_BLOCK_SPAWN_NEEDED,
		_on_spawn_needed,
		0
	))
	_subscriptions.append(bus.subscribe(
		FallingBlockEvents.FACT_FALLING_BLOCK_BOSS_ENCOUNTER_STARTED,
		_on_boss_started,
		0
	))
	_subscriptions.append(bus.subscribe(
		FallingBlockEvents.FACT_FALLING_BLOCK_BOSS_ENCOUNTER_SURVIVED,
		_on_boss_ended,
		0
	))
	_subscriptions.append(bus.subscribe(
		FallingBlockEvents.FACT_FALLING_BLOCK_GAME_OVER,
		_on_game_over,
		0
	))
	_ensure_default_playlist_on_boot()

func _resolve_music_bus() -> String:
	return music_bus_name if AudioServer.get_bus_index(music_bus_name) != -1 else "Master"

func _load_playlist_config() -> void:
	if not FileAccess.file_exists(PLAYLISTS_PATH):
		push_warning("[UltraMusicPlaylistAdapter] Missing playlist config: %s" % PLAYLISTS_PATH)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(PLAYLISTS_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[UltraMusicPlaylistAdapter] Invalid playlist config JSON.")
		return
	_default_playlist_id = str(data.get("defaultPlaylistId", PLAYLIST_NORMAL))
	_playlists = data.get("playlists", {})

func _ensure_default_playlist_on_boot() -> void:
	if _current_playlist_id.is_empty() and not _default_playlist_id.is_empty():
		switch_playlist(_default_playlist_id, 0.0, false)

func _on_spawn_needed(event: GnosisEvent) -> void:
	if not event or not event.data.is_valid():
		return
	var reason := _read_string(event.data, FallingBlockEvents.PAYLOAD_SPAWN_REASON)
	if reason != "run_started":
		return
	ensure_run_start_music()

func ensure_run_start_music() -> void:
	_cancel_delayed_start()
	_cancel_transitions()
	if _boss_encounter_active():
		switch_playlist(PLAYLIST_BOSS, run_start_fade_duration, true)
	else:
		switch_playlist(PLAYLIST_NORMAL, run_start_fade_duration, true)

func _on_boss_started(_event: GnosisEvent) -> void:
	_cancel_delayed_start()
	switch_playlist(PLAYLIST_BOSS, playlist_fade_duration, true)

func _on_boss_ended(_event: GnosisEvent) -> void:
	_cancel_delayed_start()
	switch_playlist(PLAYLIST_NORMAL, playlist_fade_duration, true)

func _on_game_over(_event: GnosisEvent) -> void:
	stop_current_music_instant()
	_schedule_delayed_playlist(PLAYLIST_BOSS)

func stop_current_music_instant() -> void:
	_cancel_delayed_start()
	_cancel_transitions()
	_music_player.stop()
	_current_playlist_id = ""
	_current_song_index = -1
	_shuffle_bag.clear()

func switch_playlist(playlist_id: String, fade_in_duration: float, fade_out_previous: bool) -> void:
	if playlist_id.is_empty() or not _playlists.has(playlist_id):
		return
	if playlist_id == _current_playlist_id and _music_player.playing:
		if fade_in_duration > 0.01 and _song_linear_volume < 0.99:
			_fade_song_volume_to(1.0, fade_in_duration)
		return

	_cancel_delayed_start()
	_cancel_transitions()
	var fade_out := playlist_fade_duration if fade_out_previous else 0.0
	if _music_player.playing and fade_out > 0.01:
		_fade_out_and_switch(playlist_id, fade_out, fade_in_duration)
	else:
		_music_player.stop()
		_begin_playlist(playlist_id, fade_in_duration)

func _fade_out_and_switch(playlist_id: String, fade_out: float, fade_in: float) -> void:
	var gen := _transition_gen
	_fade_song_volume_to(0.0, fade_out)
	_fade_tween.finished.connect(func() -> void:
		if gen != _transition_gen:
			return
		_music_player.stop()
		_begin_playlist(playlist_id, fade_in)
	, CONNECT_ONE_SHOT)

func _begin_playlist(playlist_id: String, fade_in_duration: float) -> void:
	var playlist: Dictionary = _playlists[playlist_id]
	_current_playlist_id = playlist_id
	_current_song_index = -1
	_shuffle_bag.clear()
	_loop_current_song = str(playlist.get("playMode", "")) == "loop_current"
	_play_forever = str(playlist.get("playMode", "")) == "forever"
	_play_next_song(0.0 if fade_in_duration > 0.01 else 1.0, fade_in_duration)

func _play_next_song(initial_volume: float, fade_in_duration: float) -> void:
	var playlist: Dictionary = _playlists.get(_current_playlist_id, {})
	var songs: Array = playlist.get("songs", [])
	if songs.is_empty():
		return

	var next_index := _pick_next_song_index(songs.size())
	if next_index < 0:
		return

	_current_song_index = next_index
	var clip_id := str(songs[next_index])
	var stream := _resolve_clip(clip_id)
	if stream == null:
		push_warning("[UltraMusicPlaylistAdapter] Could not resolve music clip '%s'." % clip_id)
		return

	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = _loop_current_song
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = _loop_current_song
	elif "loop" in stream:
		stream.loop = _loop_current_song

	_music_player.stream = stream
	_song_linear_volume = clampf(initial_volume, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(max(_song_linear_volume, 0.0001))
	_music_player.play()
	if fade_in_duration > 0.01 and _song_linear_volume < 0.99:
		_fade_song_volume_to(1.0, fade_in_duration)

func _pick_next_song_index(song_count: int) -> int:
	if song_count <= 0:
		return -1
	if _loop_current_song and _current_song_index >= 0:
		return _current_song_index

	var play_order := str(_playlists.get(_current_playlist_id, {}).get("playOrder", "normal"))
	if play_order == "random_unique":
		if _shuffle_bag.is_empty():
			_refill_shuffle_bag(song_count)
		if _shuffle_bag.is_empty():
			return -1
		var pick := _rng.randi_range(0, _shuffle_bag.size() - 1)
		return int(_shuffle_bag.pop_at(pick))

	if song_count == 1:
		return 0
	if _current_song_index < 0:
		return _rng.randi_range(0, song_count - 1)
	return (_current_song_index + 1) % song_count

func _refill_shuffle_bag(song_count: int) -> void:
	_shuffle_bag.clear()
	for i in range(song_count):
		_shuffle_bag.append(i)
	_shuffle_bag.shuffle()

func _on_track_finished() -> void:
	if _loop_current_song or not _play_forever:
		return
	_play_next_song(1.0, 0.0)

func _schedule_delayed_playlist(playlist_id: String) -> void:
	_cancel_delayed_start()
	_delay_timer = get_tree().create_timer(delayed_start_delay)
	var gen := _transition_gen
	_delay_timer.timeout.connect(func() -> void:
		if gen != _transition_gen:
			return
		switch_playlist(playlist_id, delayed_start_fade_duration, false)
	, CONNECT_ONE_SHOT)

func _cancel_delayed_start() -> void:
	if _delay_timer:
		_delay_timer = null

func _cancel_transitions() -> void:
	_transition_gen += 1
	_kill_fade_tween()

func _fade_song_volume_to(target: float, duration: float) -> void:
	_kill_fade_tween()
	if duration <= 0.01:
		_song_linear_volume = clampf(target, 0.0, 1.0)
		_music_player.volume_db = linear_to_db(max(_song_linear_volume, 0.0001))
		return
	_fade_tween = create_tween()
	_fade_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_fade_tween.tween_method(_set_song_linear_volume, _song_linear_volume, clampf(target, 0.0, 1.0), duration)

func _set_song_linear_volume(v: float) -> void:
	_song_linear_volume = clampf(v, 0.0, 1.0)
	_music_player.volume_db = linear_to_db(max(_song_linear_volume, 0.0001))

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	_fade_tween = null

func _resolve_clip(clip_id: String) -> AudioStream:
	if _asset_registry:
		return _asset_registry.get_audio_clip(clip_id)
	return load("res://assets/audio/music/normal/theme_1.mp3") as AudioStream

func _boss_encounter_active() -> bool:
	if not engine or not engine.context:
		return false
	return FB.get_fb_bool(engine.context, "bossEncounterIsActive", false)

func _read_string(data: GnosisNode, key: String) -> String:
	if not data.is_valid():
		return ""
	var node := data.get_node(key)
	if node.is_valid() and node.get_type() == GnosisValueType.STRING:
		return str(node.value).strip_edges()
	return ""
