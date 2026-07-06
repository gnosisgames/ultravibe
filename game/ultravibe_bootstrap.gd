class_name UltravibeBootstrap
extends "res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_godot_engine.gd"

## Boots the Gnosis engine for Ultravibe: registers data-driven services and Match3 gameplay.

const ADDON := "res://addons/com.gnosisgames.gnosisengine/services"

const Match3ServiceScript = preload("res://game/match3/services/match3_service.gd")
const Match3ShopServiceScript = preload("res://game/match3/services/match3_shop_service.gd")
const Match3PlayAdapterScript = preload("res://game/match3/adapters/match3_play_adapter.gd")
const Match3ModelsScript = preload("res://game/match3/core/match3_models.gd")
const FeedbackAudioAdapterScript = preload("res://game/adapters/feedback_audio_adapter.gd")
const UltraMusicPlaylistAdapterScript = preload("res://game/adapters/ultra_music_playlist_adapter.gd")
const UltraDebugInfoOverlayScript = preload("res://game/ui/widgets/ultra_debug_info_overlay.gd")
const UltraDisplaySettingsScript = preload("res://game/ultra_display_settings.gd")
const TranslationBridgeScript = preload("res://addons/com.gnosisgames.gnosisengine/adapters/godot/gnosis_godot_translation_bridge.gd")

var _match3_adapter = null
var _feedback_audio_adapter: FeedbackAudioAdapter = null
var _music_playlist_adapter: UltraMusicPlaylistAdapter = null
var _debug_info_overlay: UltraDebugInfoOverlay = null
var _display_settings: UltraDisplaySettings = null
var _translation_bridge: GnosisGodotTranslationBridge = null

func _register_default_services(config: GnosisEngineConfig) -> void:
	super._register_default_services(config)

	config.data_base_path = "res://data"
	config.config_manifest_path = "res://data/configuration.json"
	config.asset_registry_paths = PackedStringArray(["res://data/asset_registry.json"])

	_register(config, "Score", GnosisLifetime.TRANSIENT, "gnosis_score_service.gd")
	_register(config, "Currency", GnosisLifetime.TRANSIENT, "gnosis_currency_service.gd")
	_register(config, "Boon", GnosisLifetime.TRANSIENT, "gnosis_boon_service.gd")
	_register(config, "Consumable", GnosisLifetime.TRANSIENT, "gnosis_consumable_service.gd")
	_register(config, "Ability", GnosisLifetime.TRANSIENT, "gnosis_ability_service.gd")
	_register(config, "Upgrade", GnosisLifetime.TRANSIENT, "gnosis_upgrade_service.gd")
	_register(config, "Shop", GnosisLifetime.TRANSIENT, "gnosis_shop_service.gd")
	_register(config, "Scaling", GnosisLifetime.TRANSIENT, "gnosis_scaling_service.gd")
	_register(config, "Time", GnosisLifetime.TRANSIENT, "gnosis_time_service.gd")
	_register(config, "Seed", GnosisLifetime.TRANSIENT, "gnosis_seed_service.gd")
	_register(config, "Rule", GnosisLifetime.TRANSIENT, "gnosis_rule_service.gd")
	_register(config, "Statistic", GnosisLifetime.SINGLETON, "gnosis_statistic_service.gd")
	_register(config, "Animation", GnosisLifetime.SINGLETON, "gnosis_animation_service.gd")

	config.register_service("Match3", GnosisLifetime.TRANSIENT, func(): return Match3ServiceScript.new())
	config.register_service("Match3Shop", GnosisLifetime.TRANSIENT, func(): return Match3ShopServiceScript.new())

func _register(config: GnosisEngineConfig, id: String, lifetime: int, file_name: String) -> void:
	var script: Script = load("%s/%s" % [ADDON, file_name])
	config.register_service(id, lifetime, func(): return script.new())

func _wire_adapters() -> void:
	super._wire_adapters()
	_match3_adapter = _find_or_create_adapter(Match3PlayAdapterScript, "Match3PlayAdapter")
	_feedback_audio_adapter = _find_or_create_adapter(FeedbackAudioAdapterScript, "FeedbackAudioAdapter") as FeedbackAudioAdapter
	_music_playlist_adapter = _find_or_create_adapter(UltraMusicPlaylistAdapterScript, "MusicPlaylistAdapter") as UltraMusicPlaylistAdapter
	_bind_match3_adapter()
	if _feedback_audio_adapter:
		_feedback_audio_adapter.bind_engine(engine)
		var anim := engine.get_service("Animation") as GnosisAnimationService
		if anim:
			_feedback_audio_adapter.bind_service(anim)
	_bind_music_playlist_adapter()
	_bind_hud()
	_configure_gameplay_input()

func _configure_gameplay_input() -> void:
	var input := get_adapter(GnosisGodotInputAdapter) as GnosisGodotInputAdapter
	if input == null:
		return
	var categories := {}
	var players := {}
	for action_name in GameInputActions.action_names():
		var spec: Dictionary = GameInputActions.BINDINGS[action_name]
		var category := str(spec.get("category", "gameplay"))
		categories[action_name] = category
		if category == "gameplay":
			players[action_name] = "P0"
	for action_name in GnosisConsoleInputActions.action_names():
		categories[action_name] = "console"
	input.action_category_overrides = categories
	input.action_player_overrides = players
	input.device_player_overrides = {
		0: "P0",
		1: "P1",
		2: "P2",
		3: "P3",
	}

func _bind_match3_adapter() -> void:
	var svc := engine.get_service("Match3") if engine else null
	if _match3_adapter:
		_match3_adapter.bind_engine(engine)
		if svc:
			_match3_adapter.bind_service(svc)

func _bind_music_playlist_adapter() -> void:
	if _music_playlist_adapter and engine:
		_music_playlist_adapter.set_asset_registry(asset_registry)
		_music_playlist_adapter.bind_engine(engine)

func _rebind_transient_adapters() -> void:
	super._rebind_transient_adapters()
	_bind_match3_adapter()
	_bind_music_playlist_adapter()
	_bind_hud()

func continue_saved_run() -> bool:
	if not engine:
		return false
	var payload := GnosisRunSave.load_run_save()
	if payload.is_empty():
		return false
	var saved_ephemeral: Dictionary = {}
	var raw_ephemeral: Variant = payload.get("Ephemeral", {})
	if raw_ephemeral is Dictionary:
		saved_ephemeral = raw_ephemeral
	if saved_ephemeral.is_empty():
		GnosisRunSave.clear_run_save()
		return false
	var runtime_snapshot: Dictionary = payload.get("runtime", {})
	var config := engine.get_service("Configuration") as GnosisConfigurationService
	if config:
		config.prepare_continue_from_save(saved_ephemeral)
	engine.end_run()
	engine.destroy_non_permanent_services()
	engine.initialize_non_permanent_services()
	engine.start_run()
	if config:
		config.load_ephemeral_from_dictionary(saved_ephemeral)
	_rebind_transient_adapters()
	var m3 = engine.get_service("Match3")
	if m3 and m3.has_method("resume_saved_run"):
		m3.resume_saved_run(runtime_snapshot)
	resync_match3_board_view()
	return true

func try_save_in_progress_run() -> bool:
	if not _should_save_run():
		return false
	return GnosisRunSave.save_in_progress_run(engine)

func _should_save_run() -> bool:
	if engine == null:
		return false
	var ui := engine.get_service("GameUI") as GnosisGameUIService
	if ui == null:
		return false
	if ui.get_base_view_id().strip_edges().to_lower() != "gameplay":
		return false
	if not ui.get_active_overlay_state_for_view("game_over").is_empty():
		return false
	var m3 = engine.get_service("Match3")
	if m3 == null:
		return false
	if m3.has_method("is_run_saveable") and not m3.is_run_saveable():
		return false
	if m3.has_method("is_run_game_over") and m3.is_run_game_over():
		return false
	return true

func _exit_tree() -> void:
	try_save_in_progress_run()
	super._exit_tree()

func _bind_hud() -> void:
	var hud := get_node_or_null("UI/GameArea/Hud")
	var svc := engine.get_service("Match3") if engine else null
	if hud and svc and hud.has_method("bind_service"):
		hud.bind_service(svc)


func resync_match3_board_view() -> void:
	if _match3_adapter and _match3_adapter.has_method("resync_board_view"):
		_match3_adapter.resync_board_view()

@export var disable_crt_overlay: bool = false

func _initialize_presentation() -> void:
	if startup_view_id.is_empty():
		startup_view_id = "title"
	super._initialize_presentation()
	_ensure_translation_bridge()
	_ensure_debug_info_overlay()
	_ensure_display_settings()

func _ensure_translation_bridge() -> void:
	if _translation_bridge == null:
		_translation_bridge = TranslationBridgeScript.new()
		_translation_bridge.name = "TranslationBridge"
		add_child(_translation_bridge)
	_translation_bridge.bind_engine(engine)

func _ensure_debug_info_overlay() -> void:
	if _debug_info_overlay == null:
		_debug_info_overlay = UltraDebugInfoOverlayScript.new()
		_debug_info_overlay.name = "DebugInfoOverlay"
		add_child(_debug_info_overlay)
	_debug_info_overlay.bind_engine(engine)

func _ensure_display_settings() -> void:
	if _display_settings == null:
		_display_settings = UltraDisplaySettingsScript.new()
		_display_settings.name = "DisplaySettings"
		add_child(_display_settings)
	_display_settings.crt_force_disabled = disable_crt_overlay
	_display_settings.set_crt_rect(get_node_or_null("CRTLayer/CRT") as ColorRect)
	_display_settings.bind_engine(engine)
